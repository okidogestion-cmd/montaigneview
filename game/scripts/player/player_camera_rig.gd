extends Node3D
## Caméra d'exploration à la 3e personne, au-dessus de l'épaule.
## Le SpringArm3D rapproche la caméra quand un décor passe derrière le joueur.

@export var config: GameConfig

@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw := 0.0
var pitch := -0.15
var _height := 1.55


func _ready() -> void:
	arm.spring_length = config.camera_distance
	arm.position = Vector3(config.camera_shoulder, 0, 0)
	camera.fov = config.camera_fov
	arm.add_excluded_object((get_parent() as CollisionObject3D).get_rid())

func set_height(h: float) -> void:
	_height = h

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := config.mouse_sensitivity
		yaw -= e.relative.x * s
		pitch -= e.relative.y * s * (-1.0 if config.invert_y else 1.0)
		pitch = clampf(pitch, -1.2, 0.9)

func _process(delta: float) -> void:
	# Hauteur lissée (accroupi / debout) et orientation indépendante du corps.
	position.y = lerpf(position.y, _height, 1.0 - exp(-14.0 * delta))
	global_rotation = Vector3(pitch, yaw, 0)
