extends CharacterBody3D
## Le joueur : déplacement relatif à la caméra, sprint, accroupi (C), saut,
## gravité, retour au point d'apparition s'il tombe à l'eau.

signal fell_in_water

@export var config: GameConfig
@export var accent_color := Color("#347BC1")

@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var model: Node3D = $Mannequin
@onready var rig: Node3D = $CameraRig

var crouching := false
var spawn := Transform3D.IDENTITY
var _facing := 0.0


func _ready() -> void:
	model.accent_color = accent_color
	model.build()
	_apply_height()

func respawn_at(t: Transform3D) -> void:
	spawn = t
	respawn()

func respawn() -> void:
	global_transform = Transform3D(Basis.IDENTITY, spawn.origin)
	velocity = Vector3.ZERO
	# Le joueur regarde vers l'île adverse (l'avant de son île) en apparaissant.
	var f := spawn.basis.z
	rig.yaw = atan2(-f.x, -f.z)
	_facing = atan2(f.x, f.z)
	model.rotation.y = _facing

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= config.gravity * delta
	if Input.is_action_just_pressed("crouch"):
		_set_crouch(not crouching)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if crouching:
			_set_crouch(false)
		else:
			velocity.y = config.jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, rig.yaw) * Vector3(input.x, 0, input.y)
	var sprinting := Input.is_action_pressed("sprint") and not crouching and input.y < 0
	var speed := config.crouch_speed if crouching else (config.sprint_speed if sprinting else config.walk_speed)
	var target := dir * speed
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var rate := config.acceleration if dir.length() > 0.01 else config.deceleration
	horiz = horiz.move_toward(target, rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()

	if dir.length() > 0.01:
		_facing = lerp_angle(_facing, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))
		model.rotation.y = _facing
	model.set_crouch(crouching)

	if global_position.y < config.water_level - config.fall_respawn_depth:
		fell_in_water.emit()
		respawn()

func _set_crouch(on: bool) -> void:
	if not on and not _room_to_stand():
		return
	crouching = on
	_apply_height()

func _room_to_stand() -> bool:
	var from := global_position + Vector3(0, config.crouch_height, 0)
	var to := global_position + Vector3(0, config.stand_height + 0.05, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _apply_height() -> void:
	var h := config.crouch_height if crouching else config.stand_height
	var capsule := shape.shape as CapsuleShape3D
	capsule.height = h
	shape.position.y = h / 2.0
	rig.set_height(config.camera_height * h / config.stand_height)
