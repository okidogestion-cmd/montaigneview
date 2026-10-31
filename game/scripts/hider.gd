extends RefCounted
## Le sniper du joueur pendant la cachette : un vrai corps physique (CharacterBody3D)
## qui marche sur son île en 3e personne, bute contre les rochers et les arbres,
## accélère et freine en douceur, et peut se tenir debout, accroupi ou couché.

const STANCES := {
	"debout":   {"label": "Debout",   "speed": 4.2, "eye": 1.6,  "height": 1.75, "body": 1.75, "cam_h": 1.6, "cam_d": 2.2, "detect": 1.8},
	"accroupi": {"label": "Accroupi", "speed": 1.8, "eye": 1.1,  "height": 1.2,  "body": 1.2,  "cam_h": 1.2, "cam_d": 2.0, "detect": 1.0},
	"couche":   {"label": "Couché",   "speed": 1.1, "eye": 0.35, "height": 0.45, "body": 0.6,  "cam_h": 0.8,  "cam_d": 1.9, "detect": 0.55},
}
const RUN_SPEED := 7.5      # course (Maj), seulement debout
const ACCEL := 20.0
const DECEL := 26.0
const GRAVITY := 18.0
const AREA_RADIUS := 200.0  # on reste sur son île
const MOUSE_SENS := 0.0028
const RADIUS := 0.3
const JUMP_SPEED := 5.6     # vitesse de départ d'un saut (m/s) : ≈ 0,85 m de haut
const LAND_TIME := 0.42     # durée de la réception avant de reprendre la marche (s)

var world
var body: CharacterBody3D
var shape: CapsuleShape3D
var pos := Vector3.ZERO
var facing := PI            # le sniper regarde vers -z, l'île ennemie
var stance := "debout"
var cam_yaw := 0.0
var cam_pitch := -0.25
var _cam_pos := Vector3.ZERO
var _cam_dist := 2.2
var _cam_h := 1.65
var _first_frame := true
var _prev_pos := Vector3.ZERO   # position à l'image physique précédente (pour lisser l'affichage)
var _vis := Vector3.ZERO        # position affichée, lissée
var jump_req := false           # saut demandé (Espace / bouton Sauter), traité à l'image physique suivante
var air := ""                   # "" au sol, "start" impulsion, "loop" en l'air, "land" réception
var _air_t := 0.0               # temps passé en l'air
var _land_t := 0.0
var run_amt := 0.0              # 0 à l'arrêt ou en marche, 1 en pleine course : élargit l'angle de vue
var _bob_t := 0.0               # cycle de foulée (une foulée = gauche + droite)
var _bob_amp := 0.0             # intensité du balancement de la caméra embarquée (0 à l'arrêt)
# Sons (tools/sons_pas.py) : un pas à chaque appui de la foulée, herbe ou feuilles selon le terrain,
# (le frottement de l'équipement a été retiré le 31/10 : il doublait le rythme des pas).
var _steps := {}                # "herbe" / "feuilles" → lecteur (AudioStreamRandomizer : 4 variantes, hauteur au hasard)
var _step_idx := 0
var steps_played := 0           # nombre de pas joués (pour les tests)


func _init(w) -> void:
	world = w
	body = CharacterBody3D.new()
	body.collision_layer = 2       # joueurs
	body.collision_mask = 1        # décor
	body.floor_max_angle = deg_to_rad(64)   # on gravit les pentes raides des îles Higgsfield
	body.floor_snap_length = 0.6
	body.safe_margin = 0.02
	var cs := CollisionShape3D.new()
	shape = CapsuleShape3D.new()
	shape.radius = RADIUS
	cs.shape = shape
	body.add_child(cs)
	world.add_child(body)
	_fit_shape()
	for kind in ["herbe", "feuilles"]:
		var r := AudioStreamRandomizer.new()
		r.random_pitch = 1.12
		r.random_volume_offset_db = 2.5
		for i in 4:
			r.add_stream(i, load("res://art/son_pas_%s_%d.ogg" % [kind, i + 1]))
		var p := AudioStreamPlayer.new()
		p.stream = r
		p.max_polyphony = 1   # un pas à la fois : jamais deux pas qui se chevauchent
		world.add_child(p)
		_steps[kind] = p

func reset(x: float, z: float) -> void:
	body.global_position = Vector3(x, world.height_at(x, z) + 0.05, z)
	body.velocity = Vector3.ZERO
	pos = body.global_position
	facing = PI
	_prev_pos = pos
	_vis = pos
	cam_yaw = 0.0
	cam_pitch = -0.25
	_first_frame = true
	set_stance("debout")

func set_stance(s: String) -> void:
	stance = s
	world.set_stance(world.player, s)
	_fit_shape()
	_apply()

func toggle(s: String) -> void:
	set_stance("debout" if stance == s else s)

func info() -> Dictionary:
	return STANCES[stance]

func _fit_shape() -> void:
	var h: float = info().body
	shape.height = maxf(h, RADIUS * 2)
	(body.get_child(0) as CollisionShape3D).position.y = shape.height / 2

func look(rel: Vector2) -> void:
	cam_yaw -= rel.x * MOUSE_SENS
	cam_pitch = clampf(cam_pitch - rel.y * MOUSE_SENS, -1.2, 0.5)

func forward() -> Vector3:
	return Vector3(sin(facing), 0, cos(facing))


# ---------- Physique (appelée à chaque image physique) ----------
func physics_step(dt: float, input: Vector2, running: bool) -> void:
	_prev_pos = pos
	if input.length() > 1.0:
		input = input.normalized()
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var dir := fwd * input.y + right * input.x
	var run := running and stance == "debout" and input.y > 0.1
	var speed: float = RUN_SPEED if run else info().speed
	var target := dir * speed
	var v := body.velocity
	var horiz := Vector3(v.x, 0, v.z)
	horiz = horiz.move_toward(target, (ACCEL if dir.length() > 0.01 else DECEL) * dt)
	v.x = horiz.x
	v.z = horiz.z
	v.y = 0.0 if body.is_on_floor() else v.y - GRAVITY * dt
	if jump_req and body.is_on_floor():
		if stance != "debout":
			set_stance("debout")
		v.y = JUMP_SPEED
		air = "start"
		_air_t = 0.0
	jump_req = false
	body.velocity = v
	var before := body.global_position
	body.move_and_slide()
	# On reste sur son île, hors de l'eau.
	var p := body.global_position
	if Vector2(p.x, p.z - world.MZ).length() > AREA_RADIUS or p.y < world.WATER_Y + 0.3:
		body.global_position = before
		body.velocity = Vector3.ZERO
	# Filet de sécurité : jamais sous le sol (téléportation, pente très raide…).
	var ground: float = world.height_at(body.global_position.x, body.global_position.z)
	if body.global_position.y < ground - 0.3:
		body.global_position.y = ground + 0.05
		body.velocity.y = 0.0
	pos = body.global_position
	if dir.length() > 0.01:
		facing = lerp_angle(facing, atan2(dir.x, dir.z), 1.0 - exp(-dt * 12.0))

## Vitesse au sol (m/s) : l'animation (marche, course…) s'y cale, pas de patinage.
func ground_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


# ---------- Affichage (à chaque image) ----------
func display_pos() -> Vector3:
	# Entre deux images physiques (60 par seconde), on dessine le personnage là où il
	# devrait être à cet instant : plus d'à-coups, quelle que soit la fréquence de l'écran.
	return _prev_pos.lerp(pos, Engine.get_physics_interpolation_fraction())

func _apply() -> void:
	var p := _vis if not _first_frame else pos
	var basis := Basis(Vector3.UP, facing)
	if stance == "couche":
		# Couché, le corps suit la pente dans sa longueur (tête 0,75 m devant, pieds 0,95 m derrière)
		# et sur le côté ; il ne s'enfonce pas si le sol se creuse sous le bassin.
		var f := forward()
		var r := Vector3(f.z, 0, -f.x)
		var hf: float = world.height_at(p.x + f.x * 0.75, p.z + f.z * 0.75)
		var hb: float = world.height_at(p.x - f.x * 0.95, p.z - f.z * 0.95)
		var hr: float = world.height_at(p.x + r.x * 0.3, p.z + r.z * 0.3)
		var hl: float = world.height_at(p.x - r.x * 0.3, p.z - r.z * 0.3)
		basis = basis * Basis(Vector3.RIGHT, -atan2(hf - hb, 1.7)) * Basis(Vector3.FORWARD, atan2(hr - hl, 0.6) * -1.0)
		p.y = maxf(p.y, (hf * 0.95 + hb * 0.75) / 1.7) - 0.03
	world.player.transform = Transform3D(basis, p)

func update_visual(dt: float) -> void:
	var d := display_pos()
	# Petites bosses du sol adoucies en hauteur seulement.
	_vis = Vector3(d.x, lerpf(_vis.y, d.y, 1.0 - exp(-dt * 22.0)) if not _first_frame else d.y, d.z)
	_apply()
	_update_air(dt)
	if air == "":
		world.animate_figure(world.player, stance, ground_speed())
	var spd := ground_speed()
	run_amt = move_toward(run_amt, 1.0 if spd > 5.5 else 0.0, dt * 1.5)
	_bob_amp = move_toward(_bob_amp, clampf(spd / RUN_SPEED, 0.0, 1.0), dt * 2.0)
	_bob_t += dt * lerpf(5.7, 8.8, run_amt)   # marche ≈ 1,8 pas/s, course ≈ 2,8 pas/s
	_update_sounds(dt, spd)

## Saut : impulsion, en l'air, réception (animations Jump_* de la bibliothèque Quaternius). Une petite descente
## en marchant (moins de 0,3 s en l'air) ne déclenche rien : pas de clignotement d'animation dans les pentes.
func _update_air(dt: float) -> void:
	var grounded := body.is_on_floor()
	if not grounded:
		_air_t += dt
		if air == "" and _air_t > 0.3:
			air = "loop"
			world.play_jump(world.player, "Jump_Loop", 0.2, 1.0)
		elif air == "start" and _air_t < dt * 1.5:
			world.play_jump(world.player, "Jump_Start", 0.08, 2.2)
		elif air == "start" and _air_t > 0.45:
			air = "loop"
			world.play_jump(world.player, "Jump_Loop", 0.25, 1.0)
		return
	if air == "start" or air == "loop":
		_play_step(4.0)   # réception : un pas plus appuyé
		air = "land"
		_land_t = 0.0
		world.play_jump(world.player, "Jump_Land", 0.08, 1.7)
	elif air == "land":
		_land_t += dt
		if _land_t > LAND_TIME or (ground_speed() > 1.0 and _land_t > LAND_TIME * 0.5):
			air = ""
	_air_t = 0.0

func _update_sounds(dt: float, spd: float) -> void:
	# Un pas à chaque appui (deux par foulée, au rythme du balancement de la caméra).
	var idx := floori(_bob_t / PI)
	if idx != _step_idx:
		_step_idx = idx
		if spd > 0.6 and air == "" and stance != "couche":
			_play_step(0.0)

func _play_step(extra_db: float) -> void:
	var kind := "feuilles" if world.zone_of(pos.x, pos.z) == "foret" else "herbe"
	var p: AudioStreamPlayer = _steps[kind]
	var spd := ground_speed()
	p.volume_db = (-5.0 if spd > 5.5 else -12.0) - (8.0 if stance == "accroupi" else 0.0) + extra_db
	p.play()
	steps_played += 1

## Fin de la cachette : plus de pas ni d'équipement.
func silence() -> void:
	for p in _steps.values():
		p.stop()

func eye() -> Vector3:
	return pos + Vector3(0, info().eye, 0) + forward() * 0.3

func body_points() -> Array[Vector3]:
	# Points du corps que l'ennemi peut apercevoir.
	if stance == "couche":
		var f := forward()
		return [pos + f * 0.6 + Vector3(0, 0.32, 0), pos + Vector3(0, 0.25, 0), pos - f * 0.6 + Vector3(0, 0.18, 0)]
	var h: float = info().height
	return [pos + Vector3(0, h * 0.3, 0), pos + Vector3(0, h * 0.62, 0), pos + Vector3(0, h * 0.93, 0)]

func place_camera(cam: Camera3D, dt: float) -> void:
	# Caméra lissée au-dessus de l'épaule ; elle se rapproche si un décor passe derrière.
	_cam_h = lerpf(_cam_h, info().cam_h, 1.0 - exp(-dt * 8.0))
	var target := _vis + Vector3(0, _cam_h, 0)
	var rot := Basis.from_euler(Vector3(cam_pitch, cam_yaw, 0))
	var back := rot.z
	var shoulder := rot.x * 0.55   # par-dessus l'épaule, caméra proche du personnage
	var want: float = info().cam_d
	var q := PhysicsRayQueryParameters3D.create(target, target + shoulder + back * want, 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = maxf(0.6, target.distance_to(hit.position) - 0.35)
	_cam_dist = lerpf(_cam_dist, want, 1.0 - exp(-dt * (25.0 if want < _cam_dist else 4.0)))
	var desired := target + (shoulder + back * _cam_dist)
	var ground: float = world.height_at(desired.x, desired.z) + 0.4
	desired.y = maxf(desired.y, ground)
	_cam_pos = desired if _first_frame else _cam_pos.lerp(desired, 1.0 - exp(-dt * 18.0))
	_first_frame = false
	cam.position = _cam_pos
	cam.basis = rot
	_apply_bob(cam, 1.0)

## Caméra embarquée : en marchant ou en courant, la caméra rebondit à chaque pas, penche et plonge un peu
## (nul à l'arrêt). k : part de l'effet (1 en 3e personne, moins à l'œil).
func _apply_bob(cam: Camera3D, k: float) -> void:
	if _bob_amp <= 0.0:
		return
	var a := _bob_amp * (1.0 + 0.5 * run_amt) * k   # doux : quelques centimètres et moins d'un demi-degré
	cam.position += cam.basis.y * cos(_bob_t * 2.0) * 0.016 * a + cam.basis.x * sin(_bob_t) * 0.012 * a
	cam.basis = cam.basis * Basis.from_euler(Vector3(cos(_bob_t * 2.0) * 0.004 * a, 0.0, sin(_bob_t) * 0.007 * a))

func first_person(cam: Camera3D) -> void:
	cam.position = eye()
	cam.rotation = Vector3(cam_pitch, cam_yaw, 0)
	_apply_bob(cam, 0.6)
