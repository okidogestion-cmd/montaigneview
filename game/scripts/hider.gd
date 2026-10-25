extends RefCounted
## Le sniper du joueur pendant la cachette : il marche sur son île en 3e personne,
## et peut se tenir debout, accroupi ou couché.

const STANCES := {
	"debout":   {"label": "Debout",   "speed": 6.0, "eye": 1.6,  "height": 1.75, "cam_h": 1.7, "cam_d": 4.5, "detect": 1.8},
	"accroupi": {"label": "Accroupi", "speed": 3.0, "eye": 1.1,  "height": 1.2,  "cam_h": 1.3, "cam_d": 4.0, "detect": 1.0},
	"couche":   {"label": "Couché",   "speed": 1.4, "eye": 0.35, "height": 0.45, "cam_h": 0.9, "cam_d": 3.5, "detect": 0.55},
}
const RUN := 1.8           # course (Maj), seulement debout
const AREA_RADIUS := 200.0 # on reste sur son île
const MOUSE_SENS := 0.0032

var world
var pos := Vector3.ZERO
var facing := PI           # le sniper regarde vers -z, la montagne ennemie
var stance := "debout"
var cam_yaw := 0.0
var cam_pitch := -0.25


func _init(w) -> void:
	world = w

func reset(x: float, z: float) -> void:
	pos = Vector3(x, world.height_at(x, z), z)
	facing = PI
	cam_yaw = 0.0
	cam_pitch = -0.25
	set_stance("debout")

func set_stance(s: String) -> void:
	stance = s
	world.set_stance(world.player, s)
	_apply()

func toggle(s: String) -> void:
	set_stance("debout" if stance == s else s)

func info() -> Dictionary:
	return STANCES[stance]

func look(rel: Vector2) -> void:
	cam_yaw -= rel.x * MOUSE_SENS
	cam_pitch = clampf(cam_pitch - rel.y * MOUSE_SENS, -1.2, 0.5)

func forward() -> Vector3:
	return Vector3(sin(facing), 0, cos(facing))

func move(dt: float, input: Vector2, running: bool) -> void:
	if input.length() > 1.0:
		input = input.normalized()
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var dir := fwd * input.y + right * input.x
	if dir.length() > 0.01:
		var speed: float = info().speed * (RUN if running and stance == "debout" else 1.0)
		var np := pos + dir * speed * dt
		var h: float = world.height_at(np.x, np.z)
		var on_island := Vector2(np.x, np.z - world.MZ).length() < AREA_RADIUS
		if on_island and h > world.WATER_Y + 0.4:
			pos = Vector3(np.x, h, np.z)
		facing = lerp_angle(facing, atan2(dir.x, dir.z), 1.0 - exp(-dt * 10.0))
	_apply()

func _apply() -> void:
	pos.y = world.height_at(pos.x, pos.z)
	var basis := Basis(Vector3.UP, facing)
	if stance == "couche":
		# Couché, le corps suit la pente.
		var f := forward()
		var hf: float = world.height_at(pos.x + f.x * 0.9, pos.z + f.z * 0.9)
		var hb: float = world.height_at(pos.x - f.x * 0.9, pos.z - f.z * 0.9)
		basis = basis * Basis(Vector3.RIGHT, -atan2(hf - hb, 1.8))
	world.player.transform = Transform3D(basis, pos)

func eye() -> Vector3:
	return pos + Vector3(0, info().eye, 0) + forward() * 0.3

func body_points() -> Array[Vector3]:
	# Points du corps que l'ennemi peut apercevoir.
	if stance == "couche":
		var f := forward()
		return [pos + f * 0.6 + Vector3(0, 0.32, 0), pos + Vector3(0, 0.25, 0), pos - f * 0.6 + Vector3(0, 0.18, 0)]
	var h: float = info().height
	return [pos + Vector3(0, h * 0.3, 0), pos + Vector3(0, h * 0.62, 0), pos + Vector3(0, h * 0.93, 0)]

func place_camera(cam: Camera3D) -> void:
	var target: Vector3 = pos + Vector3(0, info().cam_h, 0)
	cam.rotation = Vector3(cam_pitch, cam_yaw, 0)
	var p: Vector3 = target + cam.global_transform.basis.z * info().cam_d
	var ground: float = world.height_at(p.x, p.z) + 0.5
	if p.y < ground:
		p.y = ground
	cam.position = p

func first_person(cam: Camera3D) -> void:
	cam.position = eye()
	cam.rotation = Vector3(cam_pitch, cam_yaw, 0)
