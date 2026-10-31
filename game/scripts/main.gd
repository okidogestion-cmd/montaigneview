extends Node3D
## La partie : menu → cachette (on marche sur son île) → brouillard → duel → fin.
## Logique reprise du prototype web « Duel des Cimes ».

const WorldScript := preload("res://scripts/world.gd")
const HudScript := preload("res://scripts/hud.gd")
const HiderScript := preload("res://scripts/hider.gd")
const PaintScript := preload("res://scripts/paint.gd")
const LifeScript := preload("res://scripts/life.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const GadgetsScript := preload("res://scripts/gadgets.gd")
const CameraRigScene := preload("res://scenes/camera_rig.tscn")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const PerfOverlayScript := preload("res://scripts/perf_overlay.gd")

const LEVELS := {
	# Ordinateur ralenti le 31/10 (« il me trouve trop vite », montagnes plus grandes) : premier tir plus tard,
	# tirs plus espacés, repérage environ 45 % plus lent.
	"facile":    {"first": 32.0, "interval": [12.0, 17.0], "rate_good": 0.0035, "rate_bad": 0.011, "acc": 0.6,  "camo": 0.35, "glint": 0.02,  "shot_reveal": 0.18},
	"normal":    {"first": 26.0, "interval": [10.0, 14.0], "rate_good": 0.0055, "rate_bad": 0.017, "acc": 0.75, "camo": 0.75, "glint": 0.03,  "shot_reveal": 0.25},
	"difficile": {"first": 18.0, "interval": [7.0, 11.0],  "rate_good": 0.009,  "rate_bad": 0.027, "acc": 0.9,  "camo": 1.0,  "glint": 0.045, "shot_reveal": 0.32},
}
const AMMO := 5
const HIDE_TIME := 60.0
const HIDE_FOV := 70.0           # angle de vue de la cachette (plus large qu'avant : 62)
const RUN_FOV_KICK := 5.0        # en courant, l'angle s'élargit encore (sensation de vitesse)
const FIRE_FOV := CameraRigScript.ZOOM_FOV   # x1, x4, x10 (gérés par le CameraRig)
const ZOOM_LABELS := ["x1", "x4", "x10"]
const SKY := Color("#dcb39c")   # brume chaude de l'heure dorée (horizon du ciel Higgsfield), reprise par le brouillard
const FOG_NEAR := 200.0
const FOG_FAR := 1100.0
var enemy_view := Vector3(0, 92, -125)   # d'où la petite lunette ennemie te regarde pendant la cachette (posée sur le relief au départ)

var world
var hud
var hider
var paint
var life
var touch
var gadgets   # caisses et gadgets (gadgets.gd)
var touch_mode := false   # téléphone / tablette (ou PC lancé avec -- --tactile)
var rig            # CameraRig : propriétaire de la caméra
var camera: Camera3D   # = rig.camera (cachette : encore placée par hider.gd)
var inset_cam: Camera3D
var env: Environment
# Sons de tir : vrai Kar98k (sources/k98_pixabay.mp3, découpé par tools/sons_k98.sh) pour ton tir (avec la
# culasse) et celui de l'ennemi (étouffé, avec l'écho) ; balle qui passe tout près : tools/sons.py.
const SON_TIR := preload("res://art/son_tir.ogg")
const SON_LOIN := preload("res://art/son_loin.ogg")
const SON_IMPACT := preload("res://art/son_impact.wav")

var level := "normal"
var phase := "menu"
var gid := 0
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
var sens := {"souris": 1.0, "tactile": 2.0}   # sensibilité du regard (multiplicateurs, réglables dans le menu)
const SETTINGS_FILE := "user://reglages.cfg"
var scope_time := 0.0
const MOVE_TIME := 15.0       # durée d'un changement de cachette pendant le tir (s)
const MOVE_DETECT := 3.0      # en bougeant, l'ennemi te repère 3 fois plus vite
var move_left := 0.0
var _scope_par := Vector2.ZERO   # décalage de l'objectif dans la lunette (pixels), lissé
var _last_look := Vector2.ZERO
var glint_warned := false
var glinted := false
var ai_reveal := 0.0
var ai_next := 0.0
var fx: Array = []
# Atelier de peinture
var brush_color := Color("#928e86")
var brush_size := 1
var brush_tool := "pinceau"
var ws_pose := "debout"
var painting := false
var orbiting := false
var _fingers := {}          # doigts posés pendant la peinture (index → position)
var _paint_finger := -1
var _pinch := -1.0
var matches_dirty := true
# Mode normal : tenues de camouflage. La peinture libre (PAINT_MODE) reviendra dans un mode à part.
const PAINT_MODE := false
var outfit := "multi_alpin"
var ghillie := ""   # tenue de feuillage portée (clé de PaintScript.GHILLIES, "" : sans)
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
	rig = CameraRigScene.instantiate()
	add_child(rig)
	camera = rig.camera
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
	# Compteur de performances : « ?perf » dans l'adresse (web) ou « -- --perf » (PC). Absent : rien n'est créé.
	var perf := "--perf" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var where = JavaScriptBridge.get_interface("location")
		if where != null:
			perf = perf or (str(where.search) + str(where.hash)).contains("perf")
	if perf:
		add_child(PerfOverlayScript.new())
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
	hud.sens_changed.connect(_on_sens)
	_load_settings()
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
	gadgets = GadgetsScript.new()
	add_child(gadgets)
	gadgets.setup(self)
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
		"sauter":
			if phase == "hide" or phase == "move":
				hider.jump_req = true
		"bouger":
			start_move()
		"lunette":
			end_move()
		"g1":
			gadgets.use(0)
		"g2":
			gadgets.use(1)
		"zoom":
			cycle_zoom()
		"tirer":
			shoot()
		"zoom":
			cycle_zoom()

func _on_orientation(portrait: bool) -> void:
	rig.set_portrait(portrait)

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_FILE) == OK:
		for k in sens:
			sens[k] = clampf(float(cf.get_value("sensibilite", k, sens[k])), hud.SENS_MIN, hud.SENS_MAX)
	for k in sens:
		hud.set_sens(k, sens[k])

func _on_sens(kind: String, v: float) -> void:
	sens[kind] = v
	var cf := ConfigFile.new()
	cf.load(SETTINGS_FILE)
	cf.set_value("sensibilite", kind, v)
	cf.save(SETTINGS_FILE)   # peut échouer (navigation privée) : le réglage reste valable pour la séance

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
	# Heure dorée (ciel Higgsfield) : haut du ciel bleu profond, nuages qui dérivent teintés par le couchant.
	sky_mat.set_shader_parameter("top_color", Color("#1d3864"))
	sky_mat.set_shader_parameter("horizon_color", SKY)
	sky_mat.set_shader_parameter("cloud_color", Color("#ffd6b0"))
	sky_mat.set_shader_parameter("cloud_shade", Color("#8a7a96"))
	sky_mat.set_shader_parameter("cloud_lo", 0.22)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ombres bleutées façon Wind Waker : la lumière ambiante colore le côté à l'ombre.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#93a8d8")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	# Étalonnage de toute l'image (un seul « filtre » qui unifie les couleurs, façon film) : couleurs un peu moins
	# saturées, plus de contraste, ombres froides bleu-vert et lumières chaudes dorées (courbes par couleur, LUT 1D).
	env.adjustment_saturation = 0.86
	env.adjustment_contrast = 1.04
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	grade.colors = PackedColorArray([Color(0.0, 0.012, 0.03), Color(0.24, 0.255, 0.27), Color(0.62, 0.6, 0.565), Color(1.0, 0.96, 0.88)])
	var lut := GradientTexture1D.new()
	lut.gradient = grade
	lut.width = 256
	env.adjustment_color_correction = lut
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
	sun.light_color = Color("#ffd9a6")   # soleil bas et doré
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	# Ombres seulement autour de la caméra, en deux tranches : léger pour les téléphones.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.0
	add_child(sun)
	sun.look_at_from_position(Vector3(-0.85, 0.45, 0.25) * 100, Vector3.ZERO)   # 25° au-dessus de l'horizon : longues ombres

func D() -> Dictionary:
	return LEVELS[level]

func aim_at(from: Vector3, to: Vector3) -> void:
	rig.aim_at(from, to)

func set_fov(f: float) -> void:
	rig.set_fov(f)

func set_fog(near: float, far: float) -> void:
	env.fog_depth_begin = near
	env.fog_depth_end = far


# ---------- Son (bruit blanc filtré, généré au lancement) ----------
func bang(stream: AudioStream, vol: float, delay := 0.0) -> void:
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
	hider.silence()
	gadgets.clear()
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
	rig.enter_menu(Vector3(330, 110, 40), Vector3(0, 55, 0), 55)
	set_fog(FOG_NEAR, FOG_FAR)
	hud.center_label.text = ""


# ---------- Atelier de peinture ----------
func start_paint() -> void:
	gid += 1
	hider.silence()
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
	hud.toast("Choisis la tenue de camouflage qui ressemble au terrain de ta cachette." if not PAINT_MODE else "Peins-toi aux couleurs du terrain autour de ta cachette.", 3.5)
	# Caméra de l'atelier : de trois quarts face, plus haute si couché.
	rig.enter_workshop(_workshop_center(), hider.facing + 0.6, 0.6 if ws_pose == "couche" else 0.15, 3.2, 50)
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
	matches_dirty = true
	_paint_state()

func _on_ghillie(kind: String) -> void:
	ghillie = kind
	world.set_ghillie(world.player, load(PaintScript.GHILLIES[kind][1]) if kind != "" else null)
	matches_dirty = true
	_paint_state()

## Ressemblance de la tenue avec un terrain (la tenue de feuillage ajoute un bonus selon le terrain).
func camo_match(zone: String) -> float:
	var bonus: float = PaintScript.GHILLIES[ghillie][2][zone] if ghillie != "" else 0.0
	return clampf(paint.match_zone(zone) + bonus, 0.0, 1.0)

func _on_paint_pose(p: String) -> void:
	ws_pose = p
	hider.set_stance(p)
	rig.set_orbit_center(_workshop_center())
	_paint_state()

## Le point que la caméra de l'atelier regarde : le sniper, à la hauteur de sa posture.
func _workshop_center() -> Vector3:
	return hider.pos + Vector3(0, {"debout": 1.0, "accroupi": 0.7, "couche": 0.3}[ws_pose], 0)

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
				rig.orbit_pinch(_pinch, d)
			_pinch = d
		else:
			rig.orbit(e.position - before)

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
			rig.orbit_wheel(-1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.orbit_wheel(1)
	elif e is InputEventMouseMotion:
		if orbiting:
			rig.orbit(e.relative)
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

## Premier point au sec (4 m au-dessus de l'eau) en partant de z vers le centre de l'île (dir = +1 : île du joueur).
func _shore_start(z: float, dir: float) -> float:
	while world.height_at(0.0, z) < WorldScript.WATER_Y + 4.0 and absf(z) < WorldScript.MZ:
		z += 5.0 * dir
	return z

## Départ en hauteur : premier point à 70 m au-dessus de la mer en montant vers la crête, puis un endroit dégagé
## alentour (aucun arbre ni rocher à moins de 2 m, vue libre sur 60 m vers l'île d'en face). Le joueur redescend
## ensuite chercher sa cachette.
func _high_start() -> Vector2:
	var z := WorldScript.MZ - 105.0
	while world.height_at(0.0, z) < WorldScript.WATER_Y + 70.0 and z < WorldScript.MZ + 40.0:
		z += 5.0
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 2.0
	q.shape = ball
	q.collision_mask = 1
	var best := Vector2(0.0, z)
	var found_free := false
	for i in 49:
		var x := float(i % 7 - 3) * 5.0
		var zz := z - float(i / 7) * 5.0
		var h: float = world.height_at(x, zz)
		q.transform = Transform3D(Basis(), Vector3(x, h + 3.2, zz))
		if not space.intersect_shape(q, 1).is_empty():
			continue
		if not found_free:
			best = Vector2(x, zz)
			found_free = true
		var eye := Vector3(x, h + 1.6, zz)
		var ray := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, 0, -60), 1)
		if space.intersect_ray(ray).is_empty():
			return Vector2(x, zz)
	return best

func start_hide() -> void:
	var ez := _shore_start(-WorldScript.MZ + 105.0, -1.0) - 15.0
	enemy_view = Vector3(0, world.height_at(0.0, ez) + 3.0, ez)
	gid += 1
	touch.set_mode("hide" if touch_mode else "")
	phase = "hide"
	rig.release()
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
	var st := _high_start()
	hider.reset(st.x, st.y)
	gadgets.start_hide(hider.pos)
	world.restore_covers()
	hide_left = HIDE_TIME
	hide_exposure = 1.0
	expo_t = 0.0
	rig.reset_zoom()
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
	world.set_ghillie(world.enemy, load(PaintScript.GHILLIES[PaintScript.ZONE_GHILLIE[enemy_camo]][1]) if randf() < 0.5 else null)
	rig.enter_scope(eye, Vector3(0, 78, -150))   # à l'œil, x1, sans recul
	hud.zoom_label.text = "x1"
	ammo = AMMO
	cool = 0.0
	shots_fired = 0
	fight_time = 0.0
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
	rate *= gadgets.detect_factor()   # couverture de survie
	if hider.stance == "couche" and player_zone == "herbe":
		rate *= 0.7  # couché dans l'herbe haute
	return rate

func cycle_zoom() -> void:
	if phase != "fire":
		return
	var z: int = rig.cycle_zoom()
	hud.zoom_label.text = ZOOM_LABELS[z]
	hud.set_scope(z > 0)
	hud.dot.visible = z == 0

func puff(p: Vector3, color := Color("#cdbf9f"), size := 2.6, life := 1.1, rise := 0.8) -> void:
	# Nuage doux (texture floue tournée vers la caméra), pas une boule.
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _smoke_tex()
	mat.albedo_color = Color(color, 0.9)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = p
	m.scale = Vector3.ONE * 0.3
	m.rotation.z = randf() * TAU
	add_child(m)
	fx.append({"m": m, "mat": mat, "t": 0.0, "life": life, "size": size, "rise": rise})

var _smoke: ImageTexture
## Texture de fumée : tache ronde aux bords irréguliers, très floue.
func _smoke_tex() -> ImageTexture:
	if _smoke != null:
		return _smoke
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.6 + 0.4 * (noise.get_noise_2d(x, y) * 0.5 + 0.5))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_smoke = ImageTexture.create_from_image(img)
	return _smoke

# ---------- Impacts violents ----------
var debris: Array = []   # éclats de roche projetés : {m, v, spin, t, life}
var _debris_mat := {}

## Impact d'une balle : gros nuage de poussière de la couleur du sol, éclats de roche projetés, éclair bref, son
## (Higgsfield) qui arrive avec le retard du son. Sur une cachette en rocher : dégâts, puis le rocher vole en éclats.
func impact(p: Vector3, normal: Vector3, collider: Object, shooter: Vector3) -> void:
	var zone: String = world.zone_of(p.x, p.z)
	var leafy: bool = world.is_foliage(collider)
	var dust := Color("#cfc6b6") if zone == "roche" else (Color("#f4f7fa") if zone == "neige" else (Color("#a08a64") if not leafy else Color("#7d8a52")))
	var chip := Color("#7d7a73") if zone != "neige" else Color("#d9dee4")
	if normal == Vector3.ZERO:
		normal = Vector3.UP
	var destroyed: bool = world.damage_cover(collider)
	var n := 22 if destroyed else 9
	puff(p, Color(1.0, 0.85, 0.55), 0.9, 0.12, 0.0)                       # éclair
	for i in (8 if destroyed else 5):
		var o := Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * (1.6 if destroyed else 0.6)
		puff(p + o + normal * 0.5, dust, randf_range(4.5, 8.0) * (1.6 if destroyed else 1.0), randf_range(2.0, 3.2), 1.6)
	if not leafy:
		for i in n:
			var m := MeshInstance3D.new()
			m.mesh = world._pebble_mesh
			if not _debris_mat.has(chip):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = chip
				mat.roughness = 1.0
				_debris_mat[chip] = mat
			m.material_override = _debris_mat[chip]
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var s := randf_range(0.08, 0.28) * (2.2 if destroyed else 1.0)
			m.scale = Vector3(s, s * randf_range(0.5, 1.0), s)
			m.position = p + normal * 0.2
			add_child(m)
			var v := (normal * randf_range(3.0, 9.0) + Vector3(randf_range(-4, 4), randf_range(2, 7), randf_range(-4, 4))) * (1.5 if destroyed else 1.0)
			debris.append({"m": m, "v": v, "spin": Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)), "t": 0.0, "life": randf_range(1.4, 2.4)})
	var d := shooter.distance_to(p)
	var path := "res://art/son_impact_roche_%d.ogg" % (randi() % 3 + 1)
	if not leafy and ResourceLoader.exists(path):
		bang(load(path), clampf(1.4 - d / 600.0, 0.35, 1.0) * (1.4 if destroyed else 1.0), d / 343.0)
	if destroyed:
		hud.toast("Le rocher a volé en éclats !", 2.5)

func shoot() -> void:
	if phase != "fire" or ammo <= 0 or cool > 0:
		return
	ammo -= 1
	shots_fired += 1
	cool = 1.3
	hud.render_ammo(ammo, AMMO)
	# La balle part exactement de la caméra affichée (balancement et recul compris).
	var origin: Vector3 = rig.aim_origin()
	var dir: Vector3 = rig.aim_direction()
	var hit := ray(origin, origin + dir * 3000)
	# La balle traverse les feuillages (buissons, houppiers) : seuls les troncs, les rochers et le relief l'arrêtent.
	# (31/10/2026 : l'ennemi visible derrière son buisson n'était jamais touché, la boîte du buisson arrêtait tout.)
	for i in 12:
		if hit.is_empty() or not world.is_foliage(hit.collider) or world.hits_trunk(hit.collider, hit.position):
			break
		hit = ray(hit.position + dir * 0.05, origin + dir * 3000)
	rig.recoil_kick()
	hud.pulse(hud.flash, 0.35, 0.16)
	bang(SON_TIR, 1.0)
	ai_reveal = minf(1, ai_reveal + D().shot_reveal)
	if ammo == 0:
		ai_next = minf(ai_next, 2.5)
	var g := gid
	var travel: float = origin.distance_to(hit.position) / 900.0 if not hit.is_empty() else 0.3
	await get_tree().create_timer(travel).timeout
	if g != gid or phase != "fire":
		return
	if not hit.is_empty() and hit.collider == world.enemy_hitbox:
		win()
		return
	if not hit.is_empty():
		impact(hit.position, hit.get("normal", Vector3.UP), hit.collider, origin)
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
	bang(SON_LOIN, 0.8, dist / 343.0)
	ai_reveal = minf(1, ai_reveal + 0.06)
	ai_next = randf_range(L.interval[0], L.interval[1]) * (0.4 if ammo == 0 else 1.0)
	var at_decoy: bool = gadgets.on_enemy_shot(tip)
	var g := gid
	await get_tree().create_timer(dist / 850.0).timeout
	if g != gid or (phase != "fire" and phase != "move"):
		return
	if at_decoy:
		puff(gadgets.decoy_pos() + Vector3(0, 0.8, 0))
		hud.toast("L'ennemi a tiré sur ton leurre ! Regarde d'où vient le tir.")
		return
	if randf() < p:
		if phase == "move":
			end_move()
		lose()
		return
	var r := 2.5 + (1 - ai_reveal) * 22
	var a := randf() * TAU
	var px: float = hider.pos.x + cos(a) * r
	var pz: float = hider.pos.z + sin(a) * r
	puff(Vector3(px, world.height_at(px, pz) + 0.4, pz))
	hud.pulse(hud.hurt, 0.35, 0.5)
	rig.recoil_flinch()
	bang(SON_IMPACT, 0.8)
	hud.toast("Un tir a frappé à %d m de toi !" % roundi(r))


# ---------- Fin ----------
func show_enemy() -> void:
	rig.set_zoom(2)
	hud.set_scope(true)
	hud.dot.visible = false
	aim_at(camera.position, world.enemy.position + Vector3(0, 0.9, 0))
	rig.reset_recoil()
	world.end_marker.position = world.enemy.position + Vector3(0, 3.2, 0)
	world.end_marker.visible = true

func finish(won: bool) -> void:
	gid += 1
	gadgets.clear()
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
	bang(SON_IMPACT, 1.0)
	finish(false)


# ---------- Commandes ----------
func _look(rel: Vector2) -> void:
	rig.look(rel)

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
		if captured and (phase == "hide" or phase == "move"):
			hider.look(e.relative * sens.souris)
		elif captured and (phase == "fire" or phase == "reveal"):
			_look(e.relative * sens.souris)
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
		if (phase == "hide" or phase == "move") and e.pressed:
			# Touches physiques : mêmes places en AZERTY et en QWERTY.
			if e.physical_keycode == KEY_C:
				hider.toggle("accroupi")
				update_zone_info()
			elif e.physical_keycode == KEY_X or e.physical_keycode == KEY_CTRL:
				hider.toggle("couche")
				update_zone_info()
			elif (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER) and phase == "hide":
				start_paint()
				return
			elif e.physical_keycode == KEY_R and phase == "move":
				end_move()
				return
		if e.keycode == KEY_SHIFT and phase != "hide":
			breath_held = e.pressed
		elif not e.pressed:
			return
		elif e.physical_keycode == KEY_R and phase == "fire":
			start_move()
		elif (e.physical_keycode == KEY_1 or e.physical_keycode == KEY_2) and phase in ["hide", "fire", "move"]:
			gadgets.use(0 if e.physical_keycode == KEY_1 else 1)
		elif e.keycode == KEY_SPACE and (phase == "hide" or phase == "move"):
			hider.jump_req = true
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
	if phase == "hide":
		_process_hide(dt)
	elif phase == "move":
		_process_move(dt)
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
		rig.sway(dt, holding, gasp > 0)
		# Au thermique, la lunette brille deux fois plus vite.
		scope_time = scope_time + dt * (2.0 if gadgets.active("thermique") else 1.0) if rig.zoom_level == 2 else 0.0
		var glint := scope_time > 5
		if glint:
			glinted = true
			if not glint_warned:
				glint_warned = true
				hud.toast("Ta lunette brille au soleil ! Change de zoom.", 3.0)
		if rig.zoom_level > 0:
			hud.set_scope(true, glint)
			# Effet de tube : l'objectif se décale avec le balancement, le recul et les mouvements du regard,
			# puis revient au centre (comme une lunette qu'on déplace devant l'œil).
			var look := Vector2(rig.scope_yaw, rig.scope_pitch)
			var turn := (look - _last_look) / maxf(dt, 0.001)
			_last_look = look
			var target := Vector2((camera.rotation.y - rig.scope_yaw) * 3000.0 + turn.x * 40.0, -(camera.rotation.x - rig.scope_pitch) * 3000.0 - turn.y * 40.0)
			_scope_par = _scope_par.lerp(target.limit_length(60.0), 1.0 - exp(-dt * 10.0))
			hud.set_scope_parallax(_scope_par)
		ai_reveal = minf(1, ai_reveal + dt * detect_rate() + (dt * L.glint if glint else 0.0))
		hud.set_eye(ai_reveal)
		ai_next -= dt
		if ai_next <= 0:
			ai_shoot()
	if phase != "reveal":
		hud.set_fog_amount(0)
	if phase == "hide" or phase == "fire" or phase == "move":
		gadgets.update(dt)
	if phase == "paint":
		rig.update(dt)
		if matches_dirty and not painting:
			matches_dirty = false
			var scores := {}
			for k in WorldScript.ZONE_KEYS:
				scores[k] = camo_match(k)
			hud.set_matches(scores)
	elif phase == "menu":
		rig.update(dt)
	elif phase != "hide":
		if touch_mode and phase in ["fire", "reveal"]:
			_look(touch.consume_look() * sens.tactile)
		rig.update(dt)
	world.update_grass(camera.global_position)
	life.update(dt, camera.global_position)

	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		f.t += dt
		var k: float = f.t / f.life
		f.m.scale = Vector3.ONE * (0.3 + f.size * pow(k, 0.35))   # gonfle tout de suite, puis s'étale
		f.mat.albedo_color.a = (1.0 - k) * (1.0 - k * 0.3)
		f.m.position.y += dt * f.get("rise", 0.8)
		if k >= 1:
			f.m.queue_free()
			fx.remove_at(i)
	for i in range(debris.size() - 1, -1, -1):
		var dbr: Dictionary = debris[i]
		dbr.t += dt
		dbr.v.y -= 9.8 * dt
		dbr.m.position += dbr.v * dt
		dbr.m.rotation += dbr.spin * dt
		var ground: float = world.height_at(dbr.m.position.x, dbr.m.position.z)
		if dbr.m.position.y < ground:
			dbr.m.position.y = ground
			dbr.v = Vector3(dbr.v.x * 0.4, absf(dbr.v.y) * 0.25, dbr.v.z * 0.4)
			dbr.spin *= 0.5
		if dbr.t > dbr.life:
			dbr.m.queue_free()
			debris.remove_at(i)

func _physics_process(dt: float) -> void:
	if hud == null:
		return
	if phase != "hide" and phase != "move":
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

# ---------- Changer de cachette pendant le tir (à tes risques et périls) ----------
## On quitte la lunette 15 s : on marche, court, saute comme pendant la cachette. L'ennemi continue de tirer et te
## repère 3 fois plus vite. R (ou le bouton LUNETTE) pour reprendre la lunette là où l'on est.
func start_move() -> void:
	if phase != "fire":
		return
	phase = "move"
	move_left = MOVE_TIME
	rig.release()
	hud.set_scope(false)
	hud.dot.visible = false
	world.player.visible = true
	world.set_near_fade(5.0)
	hider._first_frame = true
	touch.set_mode("move" if touch_mode else "")
	expo_t = 0.0
	hud.toast("Déplacement : %d s. L'ennemi te repère 3 fois plus vite. %s pour reprendre la lunette." % [MOVE_TIME, "LUNETTE" if touch_mode else "R"], 3.5)

func end_move() -> void:
	if phase != "move":
		return
	phase = "fire"
	hider.silence()
	world.player.visible = false
	world.set_near_fade(35.0)
	touch.set_mode("fire" if touch_mode else "")
	player_zone = world.zone_of(hider.pos.x, hider.pos.z)
	camo_score = camo_match(player_zone)
	rig.enter_scope(hider.eye(), Vector3(0, 70, -WorldScript.MZ))
	hud.zoom_label.text = "x1"
	hud.dot.visible = true
	hud.center_label.text = ""
	if enemy_spot != null:
		fire_exposure = exposure_from([enemy_spot.fig + Vector3(0, 1.05, 0)])

func _process_move(dt: float) -> void:
	move_left -= dt
	fight_time += dt
	cool = maxf(0, cool - dt)
	hider.update_visual(dt)
	gadgets.update_hide(hider.pos)
	if touch_mode:
		hider.look(touch.consume_look() * 0.9 * sens.tactile)
	set_fov(HIDE_FOV + RUN_FOV_KICK * hider.run_amt)
	hider.place_camera(camera, dt)
	hud.center_label.text = "DÉPLACEMENT  %d" % ceili(move_left)
	# Ce que voit l'ennemi pendant que tu bouges : recalculé quatre fois par seconde.
	expo_t -= dt
	if expo_t <= 0:
		expo_t = 0.25
		player_zone = world.zone_of(hider.pos.x, hider.pos.z)
		camo_score = camo_match(player_zone)
		if enemy_spot != null:
			fire_exposure = exposure_from([enemy_spot.fig + Vector3(0, 1.05, 0)])
	ai_reveal = minf(1, ai_reveal + dt * detect_rate() * MOVE_DETECT)
	hud.set_eye(ai_reveal)
	ai_next -= dt
	if ai_next <= 0:
		ai_shoot()
	if move_left <= 0:
		end_move()

func _process_hide(dt: float) -> void:
	hide_left -= dt
	hud.hide_timer.text = str(maxi(0, ceili(hide_left)))
	if hide_left <= 0:
		start_paint()
		return
	hider.update_visual(dt)
	gadgets.update_hide(hider.pos)
	# Clic droit maintenu : on regarde par la lunette depuis sa cachette.
	if touch_mode:
		hider.look(touch.consume_look() * 0.9 * sens.tactile)
	var preview: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (touch_mode and touch.held("viser"))
	world.player.visible = not preview
	hud.dot.visible = preview
	if preview:
		set_fov(FIRE_FOV[0])
		hider.first_person(camera)
	else:
		set_fov(HIDE_FOV + RUN_FOV_KICK * hider.run_amt)
		hider.place_camera(camera, dt)
	# Ce que voit l'ennemi : recalculé quatre fois par seconde.
	expo_t -= dt
	if expo_t <= 0:
		expo_t = 0.25
		hide_exposure = exposure_from(hide_viewers())
		update_zone_info()
