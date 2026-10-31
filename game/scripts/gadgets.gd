extends Node3D
## Gadgets à ramasser dans des caisses pendant la cachette, puis à utiliser (touches 1 et 2, ou boutons au doigt) :
##   - thermique  : 6 s, la lunette montre les corps chauds (la tenue de feuillage les atténue) ; ta lunette brille 2× plus vite.
##   - echo       : 30 s, chaque tir ennemi laisse un repère approximatif (± 12 m) visible à travers le décor.
##   - leurre     : un mannequin en tenue posé là où tu es ; les 2 prochains tirs ennemis le visent.
##   - couverture : 20 s, l'ennemi te repère 2,5× moins vite (couverture de survie).
## Caisses : textures Higgsfield (art/caisse.jpg), 3 par partie sur ton île, avec un faisceau orange pour les repérer.

const INFO := {
	"thermique": {"label": "Viseur thermique", "icon": 0, "phase": "fire", "time": 6.0},
	"echo": {"label": "Écho de tir", "icon": 1, "phase": "fire", "time": 30.0},
	"leurre": {"label": "Leurre", "icon": 2, "phase": "hide", "time": 0.0},
	"couverture": {"label": "Couverture de survie", "icon": 3, "phase": "any", "time": 20.0},
}
const CRATES := 3
const CRATE_SIZE := Vector3(0.9, 0.55, 0.6)
const PICK_RADIUS := 1.8
const MAX_CARRY := 2
const THERMAL_SHADER := """
shader_type canvas_item;
// Image thermique : la luminosité de l'écran devient une palette « fer chaud » (noir, violet, orange, blanc).
uniform sampler2D screen : hint_screen_texture, filter_linear;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = clamp(dot(c, vec3(0.3, 0.55, 0.15)), 0.0, 1.0);
	vec3 p = mix(vec3(0.02, 0.0, 0.07), vec3(0.32, 0.06, 0.45), smoothstep(0.0, 0.25, l));
	p = mix(p, vec3(0.95, 0.35, 0.08), smoothstep(0.35, 0.65, l));
	p = mix(p, vec3(1.0, 0.85, 0.3), smoothstep(0.65, 0.85, l));
	p = mix(p, vec3(1.0), smoothstep(0.85, 1.0, l));
	COLOR = vec4(p, 1.0);
}
"""

var main
var world
var carry: Array[String] = []        # gadgets portés (au plus 2)
var timers := {}                     # gadget → temps restant de son effet
var decoy_shots := 0                 # tirs ennemis encore attirés par le leurre
var decoy: Node3D
var _crates: Array = []              # [{node, kind}]
var _overlay: ColorRect
var _markers: Array = []             # repères de l'écho [{sprite, t}]
var _ring_tex: ImageTexture
var _crate_mat: StandardMaterial3D
var _beam_mat: StandardMaterial3D


func setup(m) -> void:
	main = m
	world = m.world
	_crate_mat = StandardMaterial3D.new()
	_crate_mat.albedo_texture = preload("res://art/caisse.jpg")
	_crate_mat.roughness = 1.0
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.35)
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = THERMAL_SHADER
	_overlay.material = sm
	_overlay.visible = false
	main.hud.root.add_child(_overlay)
	main.hud.root.move_child(_overlay, main.hud.scope.get_index())   # sous le cache de la lunette
	_ring_tex = _make_ring()


# ---------- Caisses ----------
## Nouvelle partie : 3 caisses sur ton île, entre 25 et 110 m de ton point de départ, chacune un gadget différent.
func start_hide(start: Vector3) -> void:
	reset()
	for c in _crates:
		c.node.queue_free()
	_crates.clear()
	var kinds := INFO.keys()
	kinds.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < CRATES and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(25.0, 110.0)
		var x := start.x + sin(a) * d
		var z := start.z + cos(a) * d
		var h: float = world.height_at(x, z)
		if h < world.WATER_Y + 3.0 or Vector2(x, z - world.MZ).length() > 185.0:
			continue
		var slope := absf(world.height_at(x + 1.5, z) - world.height_at(x - 1.5, z)) / 3.0 + absf(world.height_at(x, z + 1.5) - world.height_at(x, z - 1.5)) / 3.0
		if slope > 0.8:
			continue
		var p := Vector3(x, h, z)
		if placed.any(func(q): return q.distance_to(p) < 30.0):
			continue
		placed.append(p)
		var node := _make_crate()
		node.position = p
		node.rotation.y = rng.randf() * TAU
		add_child(node)
		_crates.append({"node": node, "kind": kinds[placed.size() - 1]})

func _make_crate() -> Node3D:
	var g := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _crate_mesh()
	mi.material_override = _crate_mat
	mi.position.y = CRATE_SIZE.y / 2 - 0.05
	g.add_child(mi)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.12
	cm.height = 16.0
	cm.radial_segments = 6
	cm.rings = 1
	beam.mesh = cm
	beam.material_override = _beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 8.0
	g.add_child(beam)
	return g

## Boîte dont chaque face lit sa partie de l'image : face avant (inscription), dessus (poignées), côtés.
func _crate_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := CRATE_SIZE / 2
	# [normale, axe u, axe v, colonne de l'image (0 face, 1 dessus, 2 côté)]
	var faces := [
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP, 0], [Vector3.BACK, Vector3.RIGHT, Vector3.UP, 0],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP, 2], [Vector3.LEFT, Vector3.BACK, Vector3.UP, 2],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, 1], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, 2],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := (n * e)
		var su := (u * e).length()
		var sv := (v * e).length()
		var col: float = f[3]
		var pts := [c - u * su - v * sv, c + u * su - v * sv, c + u * su + v * sv, c - u * su + v * sv]
		var uvs := [Vector2(col / 3.0, 1), Vector2((col + 1) / 3.0, 1), Vector2((col + 1) / 3.0, 0), Vector2(col / 3.0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(pts[i])
	return st.commit()

## Pendant la cachette : on ramasse une caisse en passant dessus.
func update_hide(pos: Vector3) -> void:
	for i in range(_crates.size() - 1, -1, -1):
		var c: Dictionary = _crates[i]
		if c.node.position.distance_to(pos) > PICK_RADIUS:
			continue
		if carry.size() >= MAX_CARRY:
			main.hud.toast("Tu portes déjà 2 gadgets.", 1.5)
			return
		carry.append(c.kind)
		c.node.queue_free()
		_crates.remove_at(i)
		main.hud.toast("Trouvé : %s ! (%s)" % [INFO[c.kind].label, _how(carry.size())], 3.0)
		_refresh()

func _how(slot: int) -> String:
	return "bouton à l'écran" if main.touch_mode else "touche %d" % slot


# ---------- Utilisation ----------
func use(slot: int) -> void:
	if slot >= carry.size():
		return
	var kind := carry[slot]
	var when: String = INFO[kind].phase
	var phase: String = main.phase
	if when == "fire" and phase != "fire":
		main.hud.toast("%s : à utiliser pendant le tir." % INFO[kind].label, 2.0)
		return
	if when == "hide" and phase != "hide":
		main.hud.toast("%s : à poser pendant la cachette." % INFO[kind].label, 2.0)
		return
	if phase != "fire" and phase != "hide":
		return
	carry.remove_at(slot)
	match kind:
		"leurre":
			_place_decoy()
			main.hud.toast("Leurre posé. Va te cacher ailleurs : l'ennemi tirera dessus.", 3.0)
		"thermique":
			timers[kind] = INFO[kind].time
			_set_thermal(true)
		"echo":
			timers[kind] = INFO[kind].time
			main.hud.toast("Écho de tir : chaque tir ennemi laisse un repère pendant 30 s.", 3.0)
		"couverture":
			timers[kind] = INFO[kind].time
			main.hud.toast("Couverture de survie : l'ennemi te repère moins vite pendant 20 s.", 3.0)
	_refresh()

func active(kind: String) -> bool:
	return timers.get(kind, 0.0) > 0.0

## Multiplicateur de la vitesse à laquelle l'ennemi te repère.
func detect_factor() -> float:
	return 0.4 if active("couverture") else 1.0

func update(dt: float) -> void:
	for k in timers.keys():
		var was: bool = timers[k] > 0.0
		timers[k] = maxf(0.0, timers[k] - dt)
		if was and timers[k] == 0.0:
			if k == "thermique":
				_set_thermal(false)
			main.hud.toast("%s : terminé." % INFO[k].label, 1.5)
	for i in range(_markers.size() - 1, -1, -1):
		var m: Dictionary = _markers[i]
		m.t -= dt
		m.sprite.modulate.a = clampf(m.t / 1.5, 0.0, 1.0)
		if m.t <= 0.0:
			m.sprite.queue_free()
			_markers.remove_at(i)
	if not carry.is_empty() or not timers.values().filter(func(t): return t > 0.0).is_empty():
		_refresh()

func _set_thermal(on: bool) -> void:
	_overlay.visible = on
	main.env.adjustment_brightness = 0.28 if on else 1.0
	var mat: ShaderMaterial = world.enemy.get_meta("camo")
	var ghillie_on: bool = world.enemy.has_meta("ghillie") and (world.enemy.get_meta("ghillie") as Node3D).visible
	mat.set_shader_parameter("heat", (0.45 if ghillie_on else 1.0) if on else 0.0)
	if on:
		main.hud.toast("Viseur thermique : 6 s.", 1.5)

## Appelé à chaque tir ennemi : l'écho laisse un repère, le leurre attire la balle. Renvoie vrai si le leurre est visé.
func on_enemy_shot(muzzle: Vector3) -> bool:
	if active("echo"):
		var s := Sprite3D.new()
		s.texture = _ring_tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.no_depth_test = true
		s.fixed_size = true
		s.pixel_size = 0.0018
		s.modulate = Color(1.0, 0.35, 0.25)
		s.render_priority = 10
		var a := randf() * TAU
		var r := randf() * 12.0
		s.position = muzzle + Vector3(cos(a) * r, 1.0, sin(a) * r)
		add_child(s)
		_markers.append({"sprite": s, "t": 4.5})
	if decoy_shots > 0 and decoy != null:
		decoy_shots -= 1
		return true
	return false

func _place_decoy() -> void:
	if decoy != null:
		decoy.queue_free()
	decoy = world.make_decoy(main.hider.pos, main.hider.facing)
	add_child(decoy)
	decoy_shots = 2

func decoy_pos() -> Vector3:
	return decoy.position if decoy != null else Vector3.ZERO


# ---------- Remise à zéro et affichage ----------
func reset() -> void:
	carry.clear()
	for k in timers.keys():
		timers[k] = 0.0
	if _overlay != null:
		_set_thermal_off_safe()
	decoy_shots = 0
	if decoy != null:
		decoy.queue_free()
		decoy = null
	for m in _markers:
		m.sprite.queue_free()
	_markers.clear()
	_refresh()

func _set_thermal_off_safe() -> void:
	_overlay.visible = false
	if main.env != null:
		main.env.adjustment_brightness = 1.0
	if world.enemy != null and world.enemy.has_meta("camo"):
		(world.enemy.get_meta("camo") as ShaderMaterial).set_shader_parameter("heat", 0.0)

## Fin de partie / retour au menu : caisses retirées, effets coupés.
func clear() -> void:
	reset()
	for c in _crates:
		c.node.queue_free()
	_crates.clear()

func _refresh() -> void:
	var parts := []
	for i in carry.size():
		parts.append(("%d : " % (i + 1) if not main.touch_mode else "") + INFO[carry[i]].label)
	for k in timers:
		if timers[k] > 0.0:
			parts.append("%s %d s" % [INFO[k].label, ceili(timers[k])])
	main.hud.set_gadgets("   ·   ".join(parts))
	if main.touch_mode:
		main.touch.set_gadgets(carry.map(func(k): return INFO[k].label))

func _make_ring() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length()
			var a := clampf(1.0 - absf(d - 24.0) / 3.5, 0.0, 1.0) + (1.0 if d < 3.0 else 0.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
