extends Node3D
## CameraRig : le seul propriétaire de la caméra du jeu (docs/proposition_architecture_v1.md).
## Les autres systèmes ne créent plus de caméra : ils passent par le rig.
##
## Modes déjà gérés par le rig :
##   MENU     : vue fixe sur la vallée, lent va-et-vient horizontal (pas B)
##   WORKSHOP : orbite autour du sniper dans l'atelier (pas B)
##   SCOPE    : vue de tir à l'œil (révélation, tir, fin) : zoom x1/x4/x10, balancement selon le souffle,
##              recul ; donne au tir sa position et sa direction (pas C)
## Mode EXTERNAL : la caméra est encore placée par hider.gd (cachette), comme avant ; le rig n'y touche pas.
## EXPLORE et PREVIEW arrivent aux pas suivants.
## main.gd garde l'interprétation des entrées (quel bouton, quel doigt) et appelle le rig.
## Le rig reste à l'origine : position locale = position dans le monde.

enum Mode { EXTERNAL, MENU, WORKSHOP, SCOPE }

const MENU_SWAY := 0.18          # amplitude du va-et-vient du menu (rad)
const MENU_SWAY_PERIOD := 9.0    # en secondes divisées par 2π : sin(t / 9)
const ORBIT_YAW_SENS := 0.008    # rad par pixel
const ORBIT_PITCH_SENS := 0.006
const ORBIT_PITCH_MIN := -0.3
const ORBIT_PITCH_MAX := 1.2
const ORBIT_DIST_MIN := 1.4
const ORBIT_DIST_MAX := 6.0
const ORBIT_WHEEL_STEP := 0.25
const ZOOM_FOV := [55.0, 14.0, 5.5]   # x1, x4, x10
const SCOPE_YAW_RANGE := 1.1          # le regard reste à ±1,1 rad de l'axe de départ
const SCOPE_PITCH_MIN := -0.9
const SCOPE_PITCH_MAX := 0.7
const SWAY_AMP := 0.0032              # balancement au repos (rad)
const SWAY_HOLD := 0.12               # souffle retenu : balancement × 0,12
const SWAY_GASP := 2.2                # à bout de souffle : × 2,2
const RECOIL_KICK := 0.012            # recul d'un tir (rad, vers le haut)
const RECOIL_FLINCH := -0.006         # sursaut quand une balle ennemie frappe tout près
const RECOIL_DAMP := 7.0              # le recul retombe en exp(-7 t)

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

# Vue de tir
var scope_yaw := 0.0
var scope_pitch := 0.0
var scope_base_yaw := 0.0        # axe de départ (vers l'île d'en face)
var zoom_level := 0              # 0 = x1, 1 = x4, 2 = x10
var recoil := 0.0
var sway_t := 0.0                # jamais remis à zéro, comme avant
var _sway := Vector2.ZERO        # balancement de cette image (remis à zéro après usage)


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
		Mode.SCOPE:
			recoil *= exp(-dt * RECOIL_DAMP)
			camera.rotation = Vector3(scope_pitch + _sway.y + recoil, scope_yaw + _sway.x, 0)
			_sway = Vector2.ZERO

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


# ---------- Vue de tir ----------
## Arrivée en vue de tir : à l'œil, tournée vers un point (l'île d'en face), zoom x1, sans recul.
func enter_scope(eye: Vector3, look_at_point: Vector3) -> void:
	mode = Mode.SCOPE
	camera.position = eye
	aim_at(eye, look_at_point)
	scope_base_yaw = scope_yaw
	set_zoom(0)
	recoil = 0.0

## Tourner le regard vers un point (l'axe de départ ne change pas).
func aim_at(from: Vector3, to: Vector3) -> void:
	var d := to - from
	scope_yaw = atan2(-d.x, -d.z)
	scope_pitch = atan2(d.y, Vector2(d.x, d.z).length())

## Regard à la souris ou au doigt (pixels) : plus le zoom est fort, plus le geste est fin.
func look(rel: Vector2) -> void:
	var k := deg_to_rad(camera.fov) / get_viewport().get_visible_rect().size.y
	scope_yaw = clampf(scope_yaw - rel.x * k, scope_base_yaw - SCOPE_YAW_RANGE, scope_base_yaw + SCOPE_YAW_RANGE)
	scope_pitch = clampf(scope_pitch - rel.y * k, SCOPE_PITCH_MIN, SCOPE_PITCH_MAX)

func set_zoom(level: int) -> void:
	zoom_level = level
	set_fov(ZOOM_FOV[level])

## x1 → x4 → x10 → x1 ; renvoie le nouveau niveau.
func cycle_zoom() -> int:
	set_zoom((zoom_level + 1) % ZOOM_FOV.size())
	return zoom_level

## Le niveau revient à x1 sans toucher à l'angle de vue (début de la cachette).
func reset_zoom() -> void:
	zoom_level = 0

## Balancement de cette image : à appeler chaque image pendant le tir (pas pendant la révélation ni la fin).
## holding : souffle retenu ; gasping : à bout de souffle (la jauge reste gérée par main.gd).
func sway(dt: float, holding: bool, gasping: bool) -> void:
	sway_t += dt
	var amp := SWAY_AMP
	if holding:
		amp *= SWAY_HOLD
	if gasping:
		amp *= SWAY_GASP
	_sway.x = amp * (sin(sway_t * 1.1) + 0.6 * sin(sway_t * 2.3 + 1.3))
	_sway.y = amp * (sin(sway_t * 1.7 + 0.5) + 0.5 * sin(sway_t * 3.1))

func recoil_kick() -> void:
	recoil = RECOIL_KICK

func recoil_flinch() -> void:
	recoil += RECOIL_FLINCH

func reset_recoil() -> void:
	recoil = 0.0

## D'où part la balle : exactement la caméra affichée (balancement et recul compris).
func aim_origin() -> Vector3:
	return camera.global_position

## Où va la balle : exactement l'axe de la caméra affichée.
func aim_direction() -> Vector3:
	return -camera.global_transform.basis.z


# ---------- Cadrage ----------
## Angle de vue vertical (degrés).
func set_fov(f: float) -> void:
	camera.fov = f

## Debout, l'angle de vue se règle sur la largeur (sinon on ne verrait qu'une tranche de l'île d'en face).
func set_portrait(portrait: bool) -> void:
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
