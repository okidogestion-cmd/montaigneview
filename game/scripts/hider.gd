extends RefCounted
## Le sniper du joueur pendant la cachette : un vrai corps physique (CharacterBody3D)
## qui marche sur son île en 3e personne, bute contre les rochers et les arbres,
## accélère et freine en douceur, et peut se tenir debout, accroupi ou couché.

const STANCES := {
	"debout":   {"label": "Debout",   "speed": 4.2, "eye": 1.6,  "height": 1.75, "body": 1.75, "cam_h": 1.65, "cam_d": 4.2, "detect": 1.8},
	"accroupi": {"label": "Accroupi", "speed": 2.2, "eye": 1.1,  "height": 1.2,  "body": 1.2,  "cam_h": 1.25, "cam_d": 3.6, "detect": 1.0},
	"couche":   {"label": "Couché",   "speed": 1.1, "eye": 0.35, "height": 0.45, "body": 0.6,  "cam_h": 0.8,  "cam_d": 3.2, "detect": 0.55},
}
const RUN_SPEED := 7.5      # course (Maj), seulement debout
const ACCEL := 20.0
const DECEL := 26.0
const GRAVITY := 18.0
const AREA_RADIUS := 200.0  # on reste sur son île
const MOUSE_SENS := 0.0028
const RADIUS := 0.3

var world
var body: CharacterBody3D
var shape: CapsuleShape3D
var pos := Vector3.ZERO
var facing := PI            # le sniper regarde vers -z, l'île ennemie
var stance := "debout"
var cam_yaw := 0.0
var cam_pitch := -0.25
var walk_phase := 0.0
var _cam_pos := Vector3.ZERO
var _cam_dist := 4.2
var _cam_h := 1.65
var _first_frame := true
var _prev_pos := Vector3.ZERO   # position à l'image physique précédente (pour lisser l'affichage)
var _vis := Vector3.ZERO        # position affichée, lissée


func _init(w) -> void:
	world = w
	body = CharacterBody3D.new()
	body.collision_layer = 2       # joueurs
	body.collision_mask = 1        # décor
	body.floor_max_angle = deg_to_rad(50)
	body.floor_snap_length = 0.6
	body.safe_margin = 0.02
	var cs := CollisionShape3D.new()
	shape = CapsuleShape3D.new()
	shape.radius = RADIUS
	cs.shape = shape
	body.add_child(cs)
	world.add_child(body)
	_fit_shape()

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
	# La foulée avance avec la distance parcourue : pas de patinage.
	var moved := Vector2(body.velocity.x, body.velocity.z).length()
	walk_phase += moved * dt * (2.4 if stance == "debout" else 3.2)

func speed_ratio() -> float:
	return clampf(Vector2(body.velocity.x, body.velocity.z).length() / RUN_SPEED * 1.6, 0.0, 1.0)


# ---------- Affichage (à chaque image) ----------
func display_pos() -> Vector3:
	# Entre deux images physiques (60 par seconde), on dessine le personnage là où il
	# devrait être à cet instant : plus d'à-coups, quelle que soit la fréquence de l'écran.
	return _prev_pos.lerp(pos, Engine.get_physics_interpolation_fraction())

func _apply() -> void:
	var p := _vis if not _first_frame else pos
	var basis := Basis(Vector3.UP, facing)
	if stance == "couche":
		# Couché, le corps suit la pente.
		var f := forward()
		var hf: float = world.height_at(pos.x + f.x * 0.9, pos.z + f.z * 0.9)
		var hb: float = world.height_at(pos.x - f.x * 0.9, pos.z - f.z * 0.9)
		basis = basis * Basis(Vector3.RIGHT, -atan2(hf - hb, 1.8))
	world.player.transform = Transform3D(basis, p)

func update_visual(dt: float) -> void:
	var d := display_pos()
	# Petites bosses du sol adoucies en hauteur seulement.
	_vis = Vector3(d.x, lerpf(_vis.y, d.y, 1.0 - exp(-dt * 22.0)) if not _first_frame else d.y, d.z)
	_apply()
	world.animate_figure(world.player, stance, walk_phase, speed_ratio())

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
	var shoulder := rot.x * 0.45
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

func first_person(cam: Camera3D) -> void:
	cam.position = eye()
	cam.rotation = Vector3(cam_pitch, cam_yaw, 0)
