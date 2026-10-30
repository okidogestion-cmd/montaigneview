extends Node3D
## CameraRig : le seul propriétaire de la caméra du jeu (docs/proposition_architecture_v1.md).
## Les autres systèmes ne créent plus de caméra : ils passent par le rig.
##
## Modes déjà gérés par le rig :
##   MENU     : vue fixe sur la vallée, lent va-et-vient horizontal (pas B)
##   WORKSHOP : orbite autour du sniper dans l'atelier (pas B)
## Mode EXTERNAL : la caméra est encore placée par main.gd (tir) et hider.gd (cachette), comme avant ;
## le rig n'y touche pas. EXPLORE, PREVIEW et SCOPE arrivent aux pas suivants.
## main.gd garde l'interprétation des entrées (quel bouton, quel doigt) et appelle le rig.
## Le rig reste à l'origine : position locale = position dans le monde.

enum Mode { EXTERNAL, MENU, WORKSHOP }

const MENU_SWAY := 0.18          # amplitude du va-et-vient du menu (rad)
const MENU_SWAY_PERIOD := 9.0    # en secondes divisées par 2π : sin(t / 9)
const ORBIT_YAW_SENS := 0.008    # rad par pixel
const ORBIT_PITCH_SENS := 0.006
const ORBIT_PITCH_MIN := -0.3
const ORBIT_PITCH_MAX := 1.2
const ORBIT_DIST_MIN := 1.4
const ORBIT_DIST_MAX := 6.0
const ORBIT_WHEEL_STEP := 0.25

@onready var camera: Camera3D = $Camera3D

var mode := Mode.EXTERNAL

# Menu
var _menu_yaw := 0.0
var _menu_pitch := 0.0
var _menu_t := 0.0               # jamais remis à zéro : le balayage reprend où il en était

# Atelier
var orbit_yaw := PI
var orbit_pitch := 0.15
var orbit_dist := 3.2
var _orbit_center := Vector3.ZERO


func _ready() -> void:
	camera.rotation_order = EULER_ORDER_YXZ
	camera.make_current()

## À chaque image (appelé par main._process, au moment où la caméra était placée avant).
func update(dt: float) -> void:
	match mode:
		Mode.MENU:
			_menu_t += dt
			camera.rotation = Vector3(_menu_pitch, _menu_yaw + sin(_menu_t / MENU_SWAY_PERIOD) * MENU_SWAY, 0)
		Mode.WORKSHOP:
			var p := orbit_pitch
			camera.position = _orbit_center + Vector3(sin(orbit_yaw) * cos(p), sin(p), cos(orbit_yaw) * cos(p)) * orbit_dist
			camera.look_at(_orbit_center)

## La caméra repart sous le contrôle de main.gd / hider.gd (cachette, tir).
func release() -> void:
	mode = Mode.EXTERNAL


# ---------- Menu ----------
func enter_menu(from: Vector3, look_at_point: Vector3, fov: float) -> void:
	mode = Mode.MENU
	camera.position = from
	var d := look_at_point - from
	_menu_yaw = atan2(-d.x, -d.z)
	_menu_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	set_fov(fov)


# ---------- Atelier ----------
func enter_workshop(center: Vector3, yaw: float, pitch: float, dist: float, fov: float) -> void:
	mode = Mode.WORKSHOP
	_orbit_center = center
	orbit_yaw = yaw
	orbit_pitch = pitch
	orbit_dist = dist
	set_fov(fov)

## Point regardé (le sniper, à la hauteur de sa posture).
func set_orbit_center(center: Vector3) -> void:
	_orbit_center = center

## Tourner autour du sniper (glisser à la souris ou au doigt, en pixels).
func orbit(rel: Vector2) -> void:
	orbit_yaw -= rel.x * ORBIT_YAW_SENS
	orbit_pitch = clampf(orbit_pitch + rel.y * ORBIT_PITCH_SENS, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)

## Molette : un cran plus près (-1) ou plus loin (+1).
func orbit_wheel(steps: int) -> void:
	orbit_dist = clampf(orbit_dist + steps * ORBIT_WHEEL_STEP, ORBIT_DIST_MIN, ORBIT_DIST_MAX)

## Pincer : la distance suit le rapport entre l'écart des doigts avant et maintenant (en pixels).
func orbit_pinch(gap_before: float, gap_now: float) -> void:
	orbit_dist = clampf(orbit_dist * gap_before / maxf(gap_now, 1.0), ORBIT_DIST_MIN, ORBIT_DIST_MAX)


# ---------- Cadrage ----------
## Angle de vue vertical (degrés).
func set_fov(f: float) -> void:
	camera.fov = f

## Debout, l'angle de vue se règle sur la largeur (sinon on ne verrait qu'une tranche de l'île d'en face).
func set_portrait(portrait: bool) -> void:
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
