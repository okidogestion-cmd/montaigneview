extends Node3D
## La partie : menu → cachette (on marche sur son île) → brouillard → duel → fin.
## Logique reprise du prototype web « Duel des Cimes ».

const WorldScript := preload("res://scripts/world.gd")
const HudScript := preload("res://scripts/hud.gd")
const HiderScript := preload("res://scripts/hider.gd")
const PaintScript := preload("res://scripts/paint.gd")
const LifeScript := preload("res://scripts/life.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

const LEVELS := {
	"facile":    {"first": 22.0, "interval": [9.0, 13.0], "rate_good": 0.006, "rate_bad": 0.02,  "acc": 0.6,  "camo": 0.35, "glint": 0.02,  "shot_reveal": 0.18},
	"normal":    {"first": 16.0, "interval": [7.0, 10.0], "rate_good": 0.010, "rate_bad": 0.03,  "acc": 0.75, "camo": 0.75, "glint": 0.03,  "shot_reveal": 0.25},
	"difficile": {"first": 11.0, "interval": [5.0, 8.0],  "rate_good": 0.015, "rate_bad": 0.045, "acc": 0.9,  "camo": 1.0,  "glint": 0.045, "shot_reveal": 0.32},
}
const AMMO := 5
const HIDE_TIME := 60.0
const HIDE_FOV := 62.0
const FIRE_FOV := [55.0, 14.0, 5.5]
const ZOOM_LABELS := ["x1", "x4", "x10"]
const SKY := Color("#efd9c9")   # couleur de l'horizon (lever de soleil du panorama), reprise par le brouillard
const FOG_NEAR := 200.0
const FOG_FAR := 1100.0
const ENEMY_VIEW := Vector3(0, 92, -125)   # d'où la petite lunette ennemie te regarde pendant la cachette

var world
var hud
var hider
var paint
var life
var touch
var touch_mode := false   # téléphone / tablette (ou PC lancé avec -- --tactile)
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
var player_zone := "roche"
var enemy_spot = null
var enemy_camo := "roche"
var hide_left := HIDE_TIME
var hide_exposure := 0.0      # part de ton corps visible depuis l'île d'en face (0 à 1)
var fire_exposure := 0.0
var expo_t := 0.0
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
var menu_t := 0.0
# Atelier de peinture
var brush_color := Color("#928e86")
var brush_size := 1
var brush_tool := "pinceau"
var ws_pose := "debout"
var ws_yaw := PI
var ws_pitch := 0.15
var ws_dist := 3.2
var painting := false
var orbiting := false
var _fingers := {}          # doigts posés pendant la peinture (index → position)
var _paint_finger := -1
var _pinch := -1.0
var matches_dirty := true
# Mode normal : tenues de camouflage. La peinture libre (PAINT_MODE) reviendra dans un mode à part.
const PAINT_MODE := false
var outfit := "digital_olive"
var ghillie := false
var paint_enemy
var camo_score := 0.0       # ressemblance de ta peinture avec le terrain où tu te caches


func _ready() -> void:
	randomize()
	# Écran de chargement pendant la construction de l'archipel (quelques secondes).
	var loading := CanvasLayer.new()
	var bg := ColorRect.new()
	bg.color = Color("#0e1418")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var msg := Label.new()
	msg.text = "Chargement de l'archipel…"
	msg.add_theme_font_size_override("font_size", 32)
	msg.add_theme_color_override("font_color", Color("#ecf0e8"))
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.add_child(msg)
	add_child(loading)
	await RenderingServer.frame_post_draw
	_build_environment()
	world = WorldScript.new()
	add_child(world)
	world.build()
	life = LifeScript.new()
	add_child(life)
	life.setup(world)
	hider = HiderScript.new(world)
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 3000
	camera.rotation_order = EULER_ORDER_YXZ
	add_child(camera)
	camera.make_current()
	hud = HudScript.new()
	add_child(hud)
	# Commandes tactiles : sur téléphone, ou sur PC avec « -- --tactile » (la souris fait le doigt).
	var on_phone := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")
	touch_mode = on_phone or "--tactile" in OS.get_cmdline_user_args()
	if OS.has_feature("web") and not touch_mode:
		# Version web : « ?tactile » ou « #tactile » dans l'adresse pour essayer le tactile à la souris.
		var loc = JavaScriptBridge.get_interface("location")
		if loc != null:
			touch_mode = (str(loc.search) + str(loc.hash)).contains("tactile")
	if touch_mode and not on_phone:
		Input.emulate_touch_from_mouse = true
	touch = TouchScript.new()
	hud.root.add_child(touch)
	touch.tapped.connect(_on_touch_tap)
	touch.set_mode("")
	hud.set_touch_mode(touch_mode)
	inset_cam = Camera3D.new()
	inset_cam.near = 0.3
	inset_cam.far = 3000
	hud.inset_viewport.add_child(inset_cam)
	inset_cam.current = true
	hud.orientation_changed.connect(_on_orientation)
	hud.play_pressed.connect(start_hide)
	hud.again_pressed.connect(start_hide)
	hud.menu_pressed.connect(to_menu)
	hud.level_chosen.connect(_on_level)
	paint = PaintScript.new(world.player.get_meta("camo"), world.figure_samples())
	hud.paint_color.connect(func(c): brush_color = c; _paint_state())
	hud.paint_size.connect(func(i): brush_size = i; _paint_state())
	hud.paint_tool.connect(func(t): brush_tool = t; _paint_state())
	hud.paint_pose.connect(_on_paint_pose)
	hud.paint_undo.connect(func(): paint.undo(); matches_dirty = true)
	hud.paint_clear.connect(func(): paint.clear(); matches_dirty = true)
	hud.paint_done.connect(start_fire)
	hud.paint_outfit.connect(_on_outfit)
	hud.paint_ghillie.connect(_on_ghillie)
	paint_enemy = PaintScript.new(world.enemy.get_meta("camo"), world.figure_samples())
	paint.wear(outfit)
	hud.ready_pressed.connect(_on_ready_pressed)
	hud.set_level(level)
	bang_near = _make_bang(5000.0)
	bang_far = _make_bang(900.0)
	to_menu()
	loading.queue_free()

func capture_mouse() -> void:
	# Sur PC on capture la souris pour viser ; au doigt, jamais.
	if not touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_touch_tap(name: String) -> void:
	match name:
		"pret":
			if phase == "hide":
				start_paint()
		"accroupi":
			hider.toggle("accroupi")
			update_zone_info()
		"couche":
			hider.toggle("couche")
			update_zone_info()
		"tirer":
			shoot()
		"zoom":
			cycle_zoom()

## Debout, l'angle de vue se règle sur la largeur (sinon on ne verrait qu'une tranche de l'île d'en face).
func _on_orientation(portrait: bool) -> void:
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT

func _on_level(lv: String) -> void:
	level = lv
	hud.set_level(lv)

func _on_ready_pressed() -> void:
	if phase == "hide":
		start_paint()

func _build_environment() -> void:
	env = Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("panorama", preload("res://art/ciel.jpg"))
	sky_mat.set_shader_parameter("clouds", preload("res://art/ciel_nuages.jpg"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ombres bleutées façon Wind Waker : la lumière ambiante colore le côté à l'ombre.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb4dc")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	# Couleurs plus naturelles (moins saturées), un peu plus de contraste : rendu réaliste.
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.1
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
	# Ombres seulement autour de la caméra, en deux tranches : léger pour les téléphones.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.0
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
	touch.set_mode("")
	phase = "menu"
	world.set_near_fade(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu.visible = true
	hud.paint_hud.visible = false
	hud.hide_hud.visible = false
	hud.fire_hud.visible = false
	hud.end_panel.visible = false
	hud.set_scope(false)
	hud.dot.visible = false
	hud.show_inset(false)
	world.player.visible = false
	world.enemy.visible = false
	world.end_marker.visible = false
	camera.position = Vector3(330, 110, 40)
	aim_at(camera.position, Vector3(0, 55, 0))
	base_yaw = yaw
	set_fov(55)
	set_fog(FOG_NEAR, FOG_FAR)
	hud.center_label.text = ""


# ---------- Atelier de peinture ----------
func start_paint() -> void:
	gid += 1
	touch.set_mode("")
	phase = "paint"
	world.set_near_fade(4.0)   # rien ne cache le sniper à l'atelier
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu.visible = false
	hud.end_panel.visible = false
	hud.fire_hud.visible = false
	hud.hide_hud.visible = false
	hud.paint_hud.visible = true
	hud.set_scope(false)
	hud.dot.visible = false
	hud.show_inset(false)
	hud.center_label.text = ""
	world.player.visible = true
	world.enemy.visible = false
	world.end_marker.visible = false
	# On peint sur place, dans la cachette et la posture choisies : le terrain autour sert de modèle.
	ws_pose = hider.stance
	world.set_stance(world.player, ws_pose)
	ws_yaw = hider.facing + 0.6   # de trois quarts face
	ws_pitch = 0.6 if ws_pose == "couche" else 0.15
	ws_dist = 3.2
	hud.toast("Choisis la tenue de camouflage qui ressemble au terrain de ta cachette." if not PAINT_MODE else "Peins-toi aux couleurs du terrain autour de ta cachette.", 3.5)
	set_fov(50)
	set_fog(FOG_NEAR, FOG_FAR)
	matches_dirty = true
	_paint_state()

func _paint_state() -> void:
	if PAINT_MODE:
		hud.set_paint_state(brush_color, brush_size, brush_tool, ws_pose)
	else:
		hud.set_outfit_state(outfit, ghillie, ws_pose)

func _on_outfit(o: String) -> void:
	outfit = o
	paint.wear(o)
	world.set_ghillie(world.player, ghillie, Color(PaintScript.OUTFITS[o][2]))
	matches_dirty = true
	_paint_state()

func _on_ghillie(on: bool) -> void:
	ghillie = on
	world.set_ghillie(world.player, on, Color(PaintScript.OUTFITS[outfit][2]))
	matches_dirty = true
	_paint_state()

## Ressemblance de la tenue avec un terrain (la tenue de feuillage ajoute un bonus).
func camo_match(zone: String) -> float:
	return clampf(paint.match_zone(zone) + (PaintScript.GHILLIE_BONUS if ghillie else 0.0), 0.0, 1.0)

func _on_paint_pose(p: String) -> void:
	ws_pose = p
	hider.set_stance(p)
	_paint_state()

func _place_workshop_camera() -> void:
	var center: Vector3 = hider.pos + Vector3(0, {"debout": 1.0, "accroupi": 0.7, "couche": 0.3}[ws_pose], 0)
	camera.position = center + Vector3(sin(ws_yaw) * cos(ws_pitch), sin(ws_pitch), cos(ws_yaw) * cos(ws_pitch)) * ws_dist
	camera.look_at(center)

func _paint_at(screen: Vector2, stroke: bool) -> void:
	var hit: Dictionary = world.pick_part(world.player, camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit.is_empty():
		paint.hide_cursor()
		return
	paint.set_cursor(hit.ref, brush_size)
	if stroke:
		if paint.is_full():
			hud.toast("La peinture est pleine : utilise « Remplir » ou un plus gros pinceau.")
			return
		paint.dab(hit.ref, brush_color, brush_size, brush_tool)
		matches_dirty = true

func _paint_touch(e: InputEvent) -> void:
	# Au doigt : un doigt sur le sniper peint, un doigt à côté tourne autour, deux doigts zooment.
	if e is InputEventScreenTouch:
		if e.pressed:
			if hud.over_paint_panel(e.position):
				return  # doigt sur les couleurs ou les outils
			_fingers[e.index] = e.position
			if _fingers.size() == 1 and PAINT_MODE:
				var hit: Dictionary = world.pick_part(world.player, camera.project_ray_origin(e.position), camera.project_ray_normal(e.position))
				if not hit.is_empty() and brush_tool == "remplir":
					paint.fill(brush_color)
					matches_dirty = true
				elif not hit.is_empty():
					_paint_finger = e.index
					painting = true
					paint.begin()
					_paint_at(e.position, true)
			else:
				# Deuxième doigt : on arrête de peindre, on passe au zoom.
				_paint_finger = -1
				painting = false
		else:
			_fingers.erase(e.index)
			if e.index == _paint_finger:
				_paint_finger = -1
				painting = false
				paint.hide_cursor()
		_pinch = -1.0
	elif e is InputEventScreenDrag:
		if not _fingers.has(e.index):
			return
		var before: Vector2 = _fingers[e.index]
		_fingers[e.index] = e.position
		if e.index == _paint_finger:
			_paint_at(e.position, true)
		elif _fingers.size() >= 2:
			var pts: Array = _fingers.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch > 0.0:
				ws_dist = clampf(ws_dist * _pinch / maxf(d, 1.0), 1.4, 6.0)
			_pinch = d
		else:
			var rel: Vector2 = e.position - before
			ws_yaw -= rel.x * 0.008
			ws_pitch = clampf(ws_pitch + rel.y * 0.006, -0.3, 1.2)

func _paint_input(e: InputEvent) -> void:
	if touch_mode:
		if e is InputEventScreenTouch or e is InputEventScreenDrag:
			_paint_touch(e)
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT and not PAINT_MODE:
			orbiting = e.pressed   # pas de pinceau : le clic gauche tourne autour du sniper
		elif e.button_index == MOUSE_BUTTON_LEFT:
			painting = e.pressed
			if e.pressed:
				if brush_tool == "remplir":
					paint.fill(brush_color)
					matches_dirty = true
					painting = false
				else:
					paint.begin()
					_paint_at(e.position, true)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			ws_dist = maxf(1.4, ws_dist - 0.25)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			ws_dist = minf(6.0, ws_dist + 0.25)
	elif e is InputEventMouseMotion:
		if orbiting:
			ws_yaw -= e.relative.x * 0.008
			ws_pitch = clampf(ws_pitch + e.relative.y * 0.006, -0.3, 1.2)
		if PAINT_MODE:
			_paint_at(e.position, painting)


# ---------- Phase 1 : se cacher (on marche sur son île) ----------
func update_zone_info() -> void:
	var zones: Dictionary = WorldScript.ZONES
	player_zone = world.zone_of(hider.pos.x, hider.pos.z)
	camo_score = camo_match(player_zone)
	var expo := "[color=#86d394]faible[/color]"
	if hide_exposure > 0.6:
		expo = "[color=#ef4f4f]forte[/color]"
	elif hide_exposure > 0.25:
		expo = "[color=#e9c84a]moyenne[/color]"
	var camo_col := "#86d394" if camo_score > 0.7 else ("#e9c84a" if camo_score > 0.4 else "#ef4f4f")
	var txt := "Terrain : [color=#ff7a2f][b]%s[/b][/color]   ·   Camouflage : [color=%s]%d %%[/color]   ·   %s   ·   Vu depuis l'île d'en face : %s" % [
		zones[player_zone]["label"], camo_col, roundi(camo_score * 100),
		hider.info().label, expo]
	if hide_exposure == 0.0:
		txt += "\n[color=#a3ada7]Bien caché… mais vois-tu encore l'île d'en face ? Maintiens le clic droit pour vérifier.[/color]"
	hud.zone_info.text = txt

func start_hide() -> void:
	gid += 1
	touch.set_mode("hide" if touch_mode else "")
	phase = "hide"
	world.set_near_fade(5.0)   # vue à la 3e personne : les arbres entre la caméra et le sniper s'effacent
	capture_mouse()
	hud.menu.visible = false
	hud.end_panel.visible = false
	hud.fire_hud.visible = false
	hud.hide_hud.visible = true
	hud.paint_hud.visible = false
	paint.hide_cursor()
	hud.set_scope(false)
	hud.dot.visible = false
	hud.show_inset(true)
	hud.center_label.text = ""
	world.player.visible = true
	world.enemy.visible = false
	world.end_marker.visible = false
	hider.reset(0.0, WorldScript.MZ - 105.0)
	hide_left = HIDE_TIME
	hide_exposure = 1.0
	expo_t = 0.0
	zoom_idx = 0
	set_fov(HIDE_FOV)
	set_fog(FOG_NEAR, FOG_FAR)
	hud.toast("Marche sur ton île et trouve une cachette avant la fin du temps.", 3.5)


# ---------- Visibilité ----------
func ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)  # décor seulement, pas le corps du joueur
	q.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(q)

func sees(from: Vector3, to: Vector3) -> bool:
	# Rien entre les deux (le joueur n'a pas de collision, l'ennemi est ignoré).
	var hit := ray(from, to, [world.enemy_hitbox.get_rid()])
	return hit.is_empty() or from.distance_to(hit.position) > from.distance_to(to) - 0.3

func exposure_from(viewers: Array) -> float:
	var pts: Array[Vector3] = hider.body_points()
	var seen := 0
	for v in viewers:
		for p in pts:
			if sees(v, p):
				seen += 1
	return float(seen) / (pts.size() * viewers.size())

func hide_viewers() -> Array:
	# Trois cachettes de l'île d'en face (gauche, milieu, droite).
	return [1, 7, 13].map(func(i): return world.enemy_spots[i].fig + Vector3(0, 1.05, 0))


# ---------- Phase 2 : tirer ----------
func choose_enemy_spot(eye: Vector3):
	# Une cachette d'où l'ennemi est vraiment visible depuis le joueur : pas de triche.
	var order: Array = world.enemy_spots.duplicate()
	order.shuffle()
	for s in order:
		for dy in [1.05, 0.6]:
			if sees(eye, s.fig + Vector3(0, dy, 0)):
				return s
	return order[0]

func start_fire() -> void:
	gid += 1
	touch.set_mode("fire" if touch_mode else "")
	phase = "reveal"
	# Vue de tir : les arbres et buissons proches s'effacent (rayon de 35 m), ils ne bouchent pas la lunette.
	world.set_near_fade(35.0)
	reveal_t = 0.0
	hud.hide_hud.visible = false
	hud.paint_hud.visible = false
	paint.hide_cursor()
	hud.show_inset(false)
	hud.fire_hud.visible = true
	world.player.visible = false
	player_zone = world.zone_of(hider.pos.x, hider.pos.z)
	camo_score = camo_match(player_zone)
	var eye: Vector3 = hider.eye()
	enemy_spot = choose_enemy_spot(eye)
	world.enemy.visible = true
	world.enemy.position = enemy_spot.fig
	world.enemy.rotation.y = 0
	world.set_stance(world.enemy, "accroupi", true)
	fire_exposure = exposure_from([enemy_spot.fig + Vector3(0, 1.05, 0)])
	var L := D()
	var others: Array = WorldScript.ZONE_KEYS.filter(func(k): return k != enemy_spot.zone)
	enemy_camo = enemy_spot.zone if randf() < L.camo else others.pick_random()
	var eo: String = PaintScript.ZONE_OUTFIT[enemy_camo]
	paint_enemy.wear(eo)
	world.set_ghillie(world.enemy, randf() < 0.5, Color(PaintScript.OUTFITS[eo][2]))
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
	capture_mouse()

func detect_rate() -> float:
	# Vitesse à laquelle l'ennemi te repère : tenue, posture, ce qu'il voit de toi.
	var L := D()
	var rate: float = lerpf(L.rate_good, L.rate_bad, 1.0 - camo_score)
	rate *= hider.info().detect
	rate *= lerpf(0.35, 1.0, fire_exposure)
	if hider.stance == "couche" and player_zone == "herbe":
		rate *= 0.7  # couché dans l'herbe haute
	return rate

func cycle_zoom() -> void:
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
	var hit := ray(camera.global_position, camera.global_position + dir * 3000)
	# Les arbres effacés près du tireur ne retiennent pas la balle : elle repart juste derrière.
	for i in 8:
		if hit.is_empty() or not world.is_foliage(hit.collider) or camera.global_position.distance_to(hit.position) > world.near_fade:
			break
		hit = ray(hit.position + dir * 0.05, camera.global_position + dir * 3000)
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
	var tip: Vector3 = world.muzzle(world.enemy)
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
	var px: float = hider.pos.x + cos(a) * r
	var pz: float = hider.pos.z + sin(a) * r
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
	touch.set_mode("")
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
	if camo_score < 0.5:
		tips.append("Ta tenue ne ressemblait qu'à %d %% à la %s : choisis la tenue de ce terrain (et le feuillage)." % [roundi(camo_score * 100), zones[player_zone]["label"].to_lower()])
	if hider.stance == "debout":
		tips.append("Debout, on te voyait de loin : accroupis-toi (C) ou couche-toi (X).")
	if fire_exposure > 0.6:
		tips.append("Tu étais à découvert : glisse-toi derrière un rocher, un buisson ou un arbre.")
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
	world.fall(world.enemy)
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
	if hud == null:
		return
	if phase == "paint":
		_paint_input(e)
		return
	if touch_mode and (e is InputEventMouseButton or e is InputEventMouseMotion):
		return  # au doigt, tout passe par touch_controls.gd
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var playing := phase in ["hide", "reveal", "fire"]
	if e is InputEventMouseMotion:
		if captured and phase == "hide":
			hider.look(e.relative)
		elif captured and (phase == "fire" or phase == "reveal"):
			_look(e.relative)
	elif e is InputEventMouseButton:
		if playing and not captured:
			if e.pressed:
				capture_mouse()
			return
		if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if e.pressed:
				cycle_zoom()
		elif phase == "fire" or phase == "reveal":
			if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
				shoot()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				breath_held = e.pressed
	elif e is InputEventKey and not e.echo:
		if phase == "hide" and e.pressed:
			# Touches physiques : mêmes places en AZERTY et en QWERTY.
			if e.physical_keycode == KEY_C:
				hider.toggle("accroupi")
				update_zone_info()
			elif e.physical_keycode == KEY_X or e.physical_keycode == KEY_CTRL:
				hider.toggle("couche")
				update_zone_info()
			elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
				start_paint()
				return
		if e.keycode == KEY_SHIFT and phase != "hide":
			breath_held = e.pressed
		elif not e.pressed:
			return
		elif e.keycode == KEY_SPACE:
			shoot()
		elif e.keycode == KEY_Z and phase != "hide":
			cycle_zoom()
		elif e.keycode == KEY_ESCAPE and captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			hud.toast("Clique dans le jeu pour reprendre.")


# ---------- Boucle ----------
func _process(dt: float) -> void:
	if hud == null:
		return
	dt = minf(dt, 0.05)
	var sx := 0.0
	var sy := 0.0
	if phase == "menu":
		menu_t += dt
		yaw = base_yaw + sin(menu_t / 9.0) * 0.18
	elif phase == "hide":
		_process_hide(dt)
	elif phase == "reveal":
		reveal_t += dt
		var e := clampf(reveal_t / 3.0, 0, 1)
		var s := e * e * (3 - 2 * e)
		set_fog(lerpf(0, FOG_NEAR, s), lerpf(12, FOG_FAR, s))
		hud.set_fog_amount(1 - s)
		if reveal_t >= 3:
			phase = "fire"
			hud.center_label.text = ""
			hud.dot.visible = true
			hud.toast("Trouve le sniper caché sur l'île d'en face.", 3.5)
	elif phase == "fire":
		var L := D()
		fight_time += dt
		cool = maxf(0, cool - dt)
		if touch_mode:
			breath_held = touch.held("souffle")
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
		ai_reveal = minf(1, ai_reveal + dt * detect_rate() + (dt * L.glint if glint else 0.0))
		hud.set_eye(ai_reveal)
		ai_next -= dt
		if ai_next <= 0:
			ai_shoot()
	if phase != "reveal":
		hud.set_fog_amount(0)
	if phase == "paint":
		_place_workshop_camera()
		if matches_dirty and not painting:
			matches_dirty = false
			var scores := {}
			for k in WorldScript.ZONE_KEYS:
				scores[k] = camo_match(k)
			hud.set_matches(scores)
	elif phase != "hide":
		if touch_mode and phase in ["fire", "reveal"]:
			_look(touch.consume_look())
		recoil *= exp(-dt * 7)
		camera.rotation = Vector3(pitch + sy + recoil, yaw + sx, 0)
	world.update_grass(camera.global_position)
	life.update(dt, camera.global_position)

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

func _physics_process(dt: float) -> void:
	if hud == null:
		return
	if phase != "hide":
		return
	var input := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Touches physiques W A S D = Z Q S D sur un clavier AZERTY.
		input.y = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	if touch_mode:
		input = touch.move
		running = touch.move.length() > 0.92   # joystick poussé à fond : on court
	hider.physics_step(dt, input, running)

func _process_hide(dt: float) -> void:
	hide_left -= dt
	hud.hide_timer.text = str(maxi(0, ceili(hide_left)))
	if hide_left <= 0:
		start_paint()
		return
	hider.update_visual(dt)
	# Clic droit maintenu : on regarde par la lunette depuis sa cachette.
	if touch_mode:
		hider.look(touch.consume_look() * 0.9)
	var preview: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (touch_mode and touch.held("viser"))
	world.player.visible = not preview
	hud.dot.visible = preview
	if preview:
		set_fov(FIRE_FOV[0])
		hider.first_person(camera)
	else:
		set_fov(HIDE_FOV)
		hider.place_camera(camera, dt)
	# Ce que voit l'ennemi : recalculé quatre fois par seconde.
	expo_t -= dt
	if expo_t <= 0:
		expo_t = 0.25
		hide_exposure = exposure_from(hide_viewers())
		update_zone_info()
	var target: Vector3 = hider.pos + Vector3(0, hider.info().height * 0.5, 0)
	inset_cam.position = ENEMY_VIEW
	inset_cam.look_at(target)
	inset_cam.fov = rad_to_deg(2 * atan(4.5 / ENEMY_VIEW.distance_to(target)))
	if Engine.get_process_frames() % 4 == 0:
		hud.inset_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
