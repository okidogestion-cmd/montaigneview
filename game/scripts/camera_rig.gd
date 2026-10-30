extends Node3D
## CameraRig : le seul propriétaire de la caméra du jeu (docs/proposition_architecture_v1.md).
## Les autres systèmes ne créent plus de caméra : ils passent par le rig.
##
## Pas A (actuel) : le rig porte la caméra et règle son cadrage (angle de vue, portrait/paysage).
## main.gd et hider.gd la placent encore eux-mêmes, exactement comme avant, par `rig.camera`.
## Les modes (MENU, EXPLORE, PREVIEW, WORKSHOP, SCOPE), le SpringArm3D et les transitions
## arrivent aux pas suivants. Le rig reste à l'origine : position locale = position dans le monde.

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.rotation_order = EULER_ORDER_YXZ
	camera.make_current()

## Angle de vue vertical (degrés).
func set_fov(f: float) -> void:
	camera.fov = f

## Debout, l'angle de vue se règle sur la largeur (sinon on ne verrait qu'une tranche de l'île d'en face).
func set_portrait(portrait: bool) -> void:
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
