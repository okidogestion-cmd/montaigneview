extends Node3D
## La partie : menu → cachette → brouillard → duel → fin.
## Logique reprise du prototype web « Duel des Cimes ».

const WorldScript := preload("res://scripts/world.gd")
const HudScript := preload("res://scripts/hud.gd")

const LEVELS := {
	"facile":    {"first": 22.0, "interval": [9.0, 13.0], "rate_good": 0.006, "rate_bad": 0.02,  "acc": 0.6,  "camo": 0.35, "glint": 0.02,  "shot_reveal": 0.18},
	"normal":    {"first": 16.0, "interval": [7.0, 10.0], "rate_good": 0.010, "rate_bad": 0.03,  "acc": 0.75, "camo": 0.75, "glint": 0.03,  "shot_reveal": 0.25},
	"difficile": {"first": 11.0, "interval": [5.0, 8.0],  "rate_good": 0.015, "rate_bad": 0.045, "acc": 0.9,  "camo": 1.0,  "glint": 0.045, "shot_reveal": 0.32},
}
const AMMO := 5
const HIDE_TIME := 45.0
const HIDE_FOV := [50.0, 17.0]
const FIRE_FOV := [55.0, 14.0, 5.5]
const ZOOM_LABELS := ["x1", "x4", "x10"]
const SKY := Color("#b3dbf2")   # couleur de l'horizon, reprise par le brouillard
const FOG_NEAR := 200.0
const FOG_FAR := 1100.0
const ENEMY_VIEW := Vector3(0, 92, -125)   # d'où l'ennemi regarde ta montagne pendant la cachette

var world
var hud
var camera: Camera3D
var inset_cam: Camera3D
var env: Environment
var bang_near: AudioStreamWAV
var bang_far: AudioStreamWAV

var level := "normal"
var phase := "menu"
var gid := 0
var yaw := 0.0
var pitch := 0.0
var base_yaw := 0.0
var zoom_idx := 0
var recoil := 0.0
var player_spot = null
var player_camo := "roche"
var enemy_spot = null
var enemy_camo := "roche"
var hide_left := HIDE_TIME
var reveal_t := 0.0
var ammo := AMMO
var cool := 0.0
var shots_fired := 0
var fight_time := 0.0
var breath := 100.0
var breath_held := false
var gasp := 0.0
var sway_t := 0.0
var scope_time := 0.0
var glint_warned := false
var glinted := false
var ai_reveal := 0.0
var ai_next := 0.0
var fx: Array = []
var drag = null
var menu_t := 0.0


func _ready() -> void:
	randomize()
	_build_environment()
	world = WorldScript.new()
	add_child(world)
	world.build()
	camera = Camera3D.new()
	camera.near = 0.3
	camera.far = 3000
	camera.rotation_order = EULER_ORDER_YXZ
	add_child(camera)
	camera.make_current()
	hud = HudScript.new()
	add_child(hud)
	inset_cam = Camera3D.new()
	inset_cam.near = 0.3
	inset_cam.far = 3000
	inset_cam.cull_mask = 1  # sans les repères orange
	hud.inset_viewport.add_child(inset_cam)
	inset_cam.current = true
	hud.play_pressed.connect(start_hide)
	hud.again_pressed.connect(start_hide)
	hud.menu_pressed.connect(to_menu)
	hud.level_chosen.connect(_on_level)
	hud.camo_chosen.connect(set_camo)
	hud.hide_zoom_pressed.connect(_toggle_hide_zoom)
	hud.ready_pressed.connect(_on_ready_pressed)
	hud.set_level(level)
	bang_near = _make_bang(5000.0)
	bang_far = _make_bang(900.0)
	to_menu()

func _on_level(lv: String) -> void:
	level = lv
	hud.set_level(lv)

func _on_ready_pressed() -> void:
	if phase == "hide":
		start_fire()

func _build_environment() -> void:
	env = Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ombres bleutées façon Wind Waker : la lumière ambiante colore le côté à l'ombre.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb4dc")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.04
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = SKY
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.fog_depth_curve = 1.0
	env.fog_depth_begin = FOG_NEAR
	env.fog_depth_end = FOG_FAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff3dc")
	sun.light_energy = 0.42
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	sun.look_at_from_position(Vector3(-0.8, 0.62, 0.15) * 100, Vector3.ZERO)

func D() -> Dictionary:
	return LEVELS[level]

func aim_at(from: Vector3, to: Vector3) -> void:
	var d := to - from
	yaw = atan2(-d.x, -d.z)
	pitch = atan2(d.y, Vector2(d.x, d.z).length())

func set_fov(f: float) -> void:
	camera.fov = f

func set_fog(near: float, far: float) -> void:
	env.fog_depth_begin = near
	env.fog_depth_end = far


# ---------- Son (bruit blanc filtré, généré au lancement) ----------
func _make_bang(cutoff: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var data := PackedByteArray()
	data.resize(n * 2)
	var a := 1.0 - exp(-TAU * cutoff / rate)
	var y := 0.0
	for i in n:
		var x := (randf() * 2 - 1) * pow(1.0 - float(i) / n, 5)
		y += a * (x - y)
		data.encode_s16(i * 2, int(clampf(y * 1.6, -1, 1) * 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s

func bang(stream: AudioStreamWAV, vol: float, delay := 0.0) -> void:
	var g := gid
	if delay > 0:
		await get_tree().create_timer(delay).timeout
		if g != gid:
			return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = linear_to_db(vol)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ---------- Menu ----------
func to_menu() -> void:
	gid += 1
	phase = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu.visible = true
	hud.hide_hud.visible = false
	hud.fire_hud.visible = false
	hud.end_panel.visible = false
	hud.set_scope(false)
	hud.dot.visible = false
	hud.show_inset(false)
	world.player.visible = false
	world.enemy.visible = false
	world.end_marker.visible = false
	for m in world.markers:
		m.visible = false
	camera.position = Vector3(330, 110, 40)
	aim_at(camera.position, Vector3(0, 55, 0))
	base_yaw = yaw
	set_fov(55)
	set_fog(FOG_NEAR, FOG_FAR)
	hud.center_label.text = ""


# ---------- Phase 1 : se cacher ----------
func set_camo(k: String) -> void:
	player_camo = k
	world.set_camo(world.player, k)
	hud.set_swatch(k)
	update_zone_info()

func update_zone_info() -> void:
	if player_spot == null:
		hud.zone_info.text = "Clique sur un repère orange de ta montagne pour t'y cacher."
		return
	var z: String = WorldScript.ZONES[player_spot.zone]["label"]
	var ok: bool = player_spot.zone == player_camo
	hud.zone_info.text = "Terrain ici : [color=#ff7a2f][b]%s[/b][/color]. %s" % [z, "Ta tenue se fond dans le décor." if ok else "Ta tenue ne colle pas au terrain."]

func select_spot(s) -> void:
	player_spot = s
	world.player.visible = true
	world.player.position = s.fig
	world.player.rotation.y = PI
	for m in world.markers:
		var me: bool = is_same(m.get_meta("spot"), s)
		m.modulate = Color.WHITE if me else Color("#ff7a2f")
		m.pixel_size = (6.0 if me else 9.0) / 64.0
	hud.show_inset(true)
	update_zone_info()

func start_hide() -> void:
	gid += 1
	phase = "hide"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu.visible = false
	hud.end_panel.visible = false
	hud.fire_hud.visible = false
	hud.hide_hud.visible = true
	hud.set_scope(false)
	hud.dot.visible = false
	hud.show_inset(false)
	hud.center_label.text = ""
	player_spot = null
	world.player.visible = false
	world.enemy.visible = false
	world.end_marker.visible = false
	for s in world.player_spots:
		s.cover.visible = true
	for m in world.markers:
		m.visible = true
		m.modulate = Color("#ff7a2f")
		m.pixel_size = 9.0 / 64.0
	set_camo("roche")
	hide_left = HIDE_TIME
	zoom_idx = 0
	set_fov(HIDE_FOV[0])
	hud.hide_zoom.text = "x1"
	camera.position = Vector3(0, 96, -125)
	aim_at(camera.position, Vector3(0, 66, 150))
	base_yaw = yaw
	set_fog(FOG_NEAR, FOG_FAR)

func _toggle_hide_zoom() -> void:
	zoom_idx = 1 - zoom_idx
	set_fov(HIDE_FOV[zoom_idx])
	hud.hide_zoom.text = "x3" if zoom_idx else "x1"

func _pick_marker(pos: Vector2) -> void:
	var best = null
	var best_d := 40.0
	for m in world.markers:
		if not m.visible or camera.is_position_behind(m.global_position):
			continue
		var d := camera.unproject_position(m.global_position).distance_to(pos)
		if d < best_d:
			best_d = d
			best = m
	if best:
		select_spot(best.get_meta("spot"))


# ---------- Phase 2 : tirer ----------
func ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(q)

func eye_pos() -> Vector3:
	return player_spot.fig + Vector3(0, 1.1, player_spot.facing * 0.3)

func own_cover() -> Array[RID]:
	return [player_spot.body.get_rid(), world.enemy_hitbox.get_rid()]

func choose_enemy_spot(eye: Vector3):
	# Une cachette d'où l'ennemi est vraiment visible depuis le joueur : pas de triche.
	var order: Array = world.enemy_spots.duplicate()
	order.shuffle()
	for s in order:
		for dy in [1.05, 0.6]:
			var t: Vector3 = s.fig + Vector3(0, dy, 0)
			var hit := ray(eye, t, own_cover())
			if hit.is_empty() or eye.distance_to(hit.position) > eye.distance_to(t) - 0.8:
				return s
	return order[0]

func start_fire() -> void:
	if player_spot == null:
		select_spot(world.player_spots.pick_random())
	gid += 1
	phase = "reveal"
	reveal_t = 0.0
	hud.hide_hud.visible = false
	hud.show_inset(false)
	hud.fire_hud.visible = true
	for m in world.markers:
		m.visible = false
	world.player.visible = false
	player_spot.cover.visible = false
	var eye := eye_pos()
	enemy_spot = choose_enemy_spot(eye)
	world.enemy.visible = true
	world.enemy.position = enemy_spot.fig
	world.enemy.rotation.y = 0
	var L := D()
	var others: Array = WorldScript.ZONE_KEYS.filter(func(k): return k != enemy_spot.zone)
	enemy_camo = enemy_spot.zone if randf() < L.camo else others.pick_random()
	world.set_camo(world.enemy, enemy_camo)
	camera.position = eye
	aim_at(eye, Vector3(0, 78, -150))
	base_yaw = yaw
	zoom_idx = 0
	set_fov(FIRE_FOV[0])
	hud.zoom_label.text = "x1"
	ammo = AMMO
	cool = 0.0
	shots_fired = 0
	fight_time = 0.0
	recoil = 0.0
	breath = 100.0
	breath_held = false
	gasp = 0.0
	scope_time = 0.0
	glint_warned = false
	glinted = false
	ai_reveal = 0.0
	ai_next = L.first
	hud.render_ammo(ammo, AMMO)
	hud.breath_bar.value = breath
	hud.set_eye(0)
	hud.center_label.text = "Le brouillard se lève…"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func cycle_zoom() -> void:
	if phase == "hide":
		_toggle_hide_zoom()
		return
	if phase != "fire":
		return
	zoom_idx = (zoom_idx + 1) % 3
	set_fov(FIRE_FOV[zoom_idx])
	hud.zoom_label.text = ZOOM_LABELS[zoom_idx]
	hud.set_scope(zoom_idx > 0)
	hud.dot.visible = zoom_idx == 0

func puff(p: Vector3, color := Color("#cdbf9f"), size := 2.6) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.9)
	m.material_override = mat
	m.position = p
	m.scale = Vector3.ONE * 0.3
	add_child(m)
	fx.append({"m": m, "mat": mat, "t": 0.0, "life": 1.1, "size": size})

func shoot() -> void:
	if phase != "fire" or ammo <= 0 or cool > 0:
		return
	ammo -= 1
	shots_fired += 1
	cool = 1.3
	hud.render_ammo(ammo, AMMO)
	var dir := -camera.global_transform.basis.z
	var hit := ray(camera.global_position, camera.global_position + dir * 3000, [player_spot.body.get_rid()])
	recoil = 0.012
	hud.pulse(hud.flash, 0.35, 0.16)
	bang(bang_near, 0.9)
	ai_reveal = minf(1, ai_reveal + D().shot_reveal)
	if ammo == 0:
		ai_next = minf(ai_next, 2.5)
	var g := gid
	var travel: float = camera.global_position.distance_to(hit.position) / 900.0 if not hit.is_empty() else 0.3
	await get_tree().create_timer(travel).timeout
	if g != gid or phase != "fire":
		return
	if not hit.is_empty() and hit.collider == world.enemy_hitbox:
		win()
		return
	if not hit.is_empty():
		puff(hit.position)
	hud.toast("Plus de balles ! L'ennemi sait où tu es…" if ammo == 0 else "Raté. Ton tir a trahi ta position.")

func ai_shoot() -> void:
	var L := D()
	var p := minf(0.92, ai_reveal * L.acc)
	var tip: Vector3 = world.enemy.to_global(Vector3(0.12, 0.95, 1.4))
	world.flash_sprite.position = tip
	world.flash_sprite.visible = true
	get_tree().create_timer(0.11).timeout.connect(func(): world.flash_sprite.visible = false)
	puff(tip, Color("#e8e4dc"), 1.4)
	var dist := camera.global_position.distance_to(tip)
	bang(bang_far, 0.35, dist / 343.0)
	ai_reveal = minf(1, ai_reveal + 0.06)
	ai_next = randf_range(L.interval[0], L.interval[1]) * (0.4 if ammo == 0 else 1.0)
	var g := gid
	await get_tree().create_timer(dist / 850.0).timeout
	if g != gid or phase != "fire":
		return
	if randf() < p:
		lose()
		return
	var r := 2.5 + (1 - ai_reveal) * 22
	var a := randf() * TAU
	var px: float = player_spot.fig.x + cos(a) * r
	var pz: float = player_spot.fig.z + sin(a) * r
	puff(Vector3(px, world.height_at(px, pz) + 0.4, pz))
	hud.pulse(hud.hurt, 0.35, 0.5)
	recoil -= 0.006
	bang(bang_near, 0.25)
	hud.toast("Un tir a frappé à %d m de toi !" % roundi(r))


# ---------- Fin ----------
func show_enemy() -> void:
	zoom_idx = 2
	set_fov(FIRE_FOV[2])
	hud.set_scope(true)
	hud.dot.visible = false
	aim_at(camera.position, world.enemy.position + Vector3(0, 0.9, 0))
	recoil = 0.0
	world.end_marker.position = world.enemy.position + Vector3(0, 3.2, 0)
	world.end_marker.visible = true

func finish(won: bool) -> void:
	gid += 1
	phase = "end"
	breath_held = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.fire_hud.visible = false
	hud.end_panel.visible = true
	hud.center_label.text = ""
	hud.hide_toast()
	var zones: Dictionary = WorldScript.ZONES
	var ez: String = zones[enemy_spot.zone]["label"]
	var ec: String = zones[enemy_camo]["label"]
	hud.end_title.text = "Touché !" if won else "Il t'a eu."
	hud.end_title.add_theme_color_override("font_color", HudScript.OK if won else HudScript.DANGER)
	var start := ("Tu l'as trouvé en %d s avec %d balle%s. " % [roundi(fight_time), shots_fired, "s" if shots_fired > 1 else ""]) if won else "Le voici, dans la lunette. "
	hud.end_text.text = start + "Il était caché sur la %s, en tenue %s." % [ez.to_lower(), ec.to_lower()]
	var tips: Array[String] = []
	if player_spot.zone != player_camo:
		tips.append("Ta tenue %s se voyait sur la %s." % [zones[player_camo]["label"].to_lower(), zones[player_spot.zone]["label"].to_lower()])
	if not won and shots_fired > 1:
		tips.append("Chaque tir raté lui a montré où tu étais.")
	if glinted:
		tips.append("Ta lunette a brillé : ne reste pas trop longtemps au zoom x10.")
	if enemy_spot.zone != enemy_camo:
		tips.append("Sa tenue ne collait pas au terrain : cherche les couleurs qui détonnent.")
	if not won and tips.is_empty():
		tips.append("Repère l'éclair de son canon quand il tire, puis vise là.")
	var lines := ""
	for t in tips:
		lines += "• " + t + "\n"
	hud.end_tips.text = lines.strip_edges()
	show_enemy()

func win() -> void:
	hud.pulse(hud.flash, 0.2, 0.3)
	finish(true)

func lose() -> void:
	hud.pulse(hud.hurt, 1.0, 1.4)
	bang(bang_near, 0.6)
	finish(false)


# ---------- Commandes ----------
func _look(rel: Vector2) -> void:
	var k := deg_to_rad(camera.fov) / get_viewport().get_visible_rect().size.y
	yaw = clampf(yaw - rel.x * k, base_yaw - 1.1, base_yaw + 1.1)
	pitch = clampf(pitch - rel.y * k, -0.9, 0.7)

func _unhandled_input(e: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if e is InputEventMouseMotion:
		if phase == "fire" or phase == "reveal":
			if captured:
				_look(e.relative)
		elif phase == "hide" and drag != null:
			_look(e.relative)
	elif e is InputEventMouseButton:
		if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if e.pressed:
				cycle_zoom()
			return
		if phase == "hide" and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				drag = e.position
			elif drag != null:
				if e.position.distance_to(drag) < 10:
					_pick_marker(e.position)
				drag = null
		elif phase == "fire" or phase == "reveal":
			if not captured:
				if e.pressed:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
				shoot()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				breath_held = e.pressed
	elif e is InputEventKey and not e.echo:
		if e.keycode == KEY_SHIFT:
			breath_held = e.pressed
		elif not e.pressed:
			return
		elif e.keycode == KEY_SPACE:
			shoot()
		elif e.keycode == KEY_Z:
			cycle_zoom()
		elif e.keycode == KEY_ESCAPE and captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			hud.toast("Clique pour reprendre la visée.")


# ---------- Boucle ----------
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var sx := 0.0
	var sy := 0.0
	if phase == "menu":
		menu_t += dt
		yaw = base_yaw + sin(menu_t / 9.0) * 0.18
	elif phase == "hide":
		hide_left -= dt
		hud.hide_timer.text = str(maxi(0, ceili(hide_left)))
		if hide_left <= 0:
			start_fire()
	elif phase == "reveal":
		reveal_t += dt
		var e := clampf(reveal_t / 3.0, 0, 1)
		var s := e * e * (3 - 2 * e)
		set_fog(lerpf(0, FOG_NEAR, s), lerpf(12, FOG_FAR, s))
		hud.fog_overlay.color.a = 1 - s
		if reveal_t >= 3:
			phase = "fire"
			hud.center_label.text = ""
			hud.dot.visible = true
			hud.toast("Trouve le sniper caché sur la montagne d'en face.", 3.5)
	elif phase == "fire":
		var L := D()
		fight_time += dt
		cool = maxf(0, cool - dt)
		var holding := breath_held and breath > 0 and gasp <= 0
		if holding:
			breath = maxf(0, breath - dt * 28)
			if breath == 0:
				gasp = 2.2
				hud.toast("À bout de souffle !", 1.5)
		else:
			breath = minf(100, breath + dt * 14)
		if gasp > 0:
			gasp -= dt
		hud.breath_bar.value = breath
		sway_t += dt
		var amp := 0.0032
		if holding:
			amp *= 0.12
		if gasp > 0:
			amp *= 2.2
		sx = amp * (sin(sway_t * 1.1) + 0.6 * sin(sway_t * 2.3 + 1.3))
		sy = amp * (sin(sway_t * 1.7 + 0.5) + 0.5 * sin(sway_t * 3.1))
		scope_time = scope_time + dt if zoom_idx == 2 else 0.0
		var glint := scope_time > 5
		if glint:
			glinted = true
			if not glint_warned:
				glint_warned = true
				hud.toast("Ta lunette brille au soleil ! Change de zoom.", 3.0)
		if zoom_idx > 0:
			hud.set_scope(true, glint)
		var rate: float = L.rate_good if player_camo == player_spot.zone else L.rate_bad
		ai_reveal = minf(1, ai_reveal + dt * rate + (dt * L.glint if glint else 0.0))
		hud.set_eye(ai_reveal)
		ai_next -= dt
		if ai_next <= 0:
			ai_shoot()
	if phase != "reveal":
		hud.fog_overlay.color.a = 0
	recoil *= exp(-dt * 7)
	camera.rotation = Vector3(pitch + sy + recoil, yaw + sx, 0)
	world.update_grass(camera.global_position)

	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		f.t += dt
		var k: float = f.t / f.life
		f.m.scale = Vector3.ONE * (0.3 + f.size * sqrt(k))
		f.mat.albedo_color.a = 0.9 * (1 - k)
		f.m.position.y += dt * 0.8
		if k >= 1:
			f.m.queue_free()
			fx.remove_at(i)

	if phase == "hide" and player_spot != null:
		var target: Vector3 = player_spot.fig + Vector3(0, 0.7, 0)
		inset_cam.position = ENEMY_VIEW
		inset_cam.look_at(target)
		inset_cam.fov = rad_to_deg(2 * atan(4.5 / ENEMY_VIEW.distance_to(target)))
