extends Control
## Commandes tactiles (téléphone, tablette) : joystick virtuel, glisser pour regarder,
## gros boutons ronds. Plusieurs doigts en même temps.
## main.gd lit l'état à chaque image : move, consume_look(), held(), et le signal tapped.

signal tapped(button: String)

const BLAZE := Color("#ff7a2f")
const DANGER := Color("#ef4f4f")
const PAPER := Color("#ecf0e8")
const JOY_RADIUS := 95.0

## "hide" (joystick + regarder + boutons), "fire" (viser + boutons), "" (rien).
var mode := ""
var move := Vector2.ZERO           # joystick : x droite, y avant (de -1 à 1)
var _look := Vector2.ZERO          # glissement accumulé depuis la dernière lecture (pixels)
var _joy_finger := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_fingers := {}            # doigt → dernière position
var _buttons := {}                 # nom → {pos (relative au coin), radius, label, color, modes, hold}
var _down := {}                    # nom → doigt qui appuie
var _last_tap := -10000            # double tape sur la vue de tir = zoom
var _last_tap_pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Positions comptées depuis le bas droit (x négatif) ou le bas gauche (x positif).
	# Icônes (art/commandes_icones.png, Higgsfield) : 0 sauter, 1 accroupi, 2 couché, 3 viser, 4 prêt, 5 tirer, 6 souffle.
	_add("pret", Vector2(-110, -560), 58, "PRÊT", BLAZE, ["hide"], false, 4)
	_add("viser", Vector2(-110, -400), 62, "VISER", PAPER, ["hide"], true, 3)
	_add("couche", Vector2(-110, -245), 54, "COUCHÉ", PAPER, ["hide"], false, 2)
	_add("accroupi", Vector2(-240, -150), 54, "ACCROUPI", PAPER, ["hide"], false, 1)
	_add("sauter", Vector2(-370, -105), 54, "SAUTER", PAPER, ["hide"], false, 0)
	_add("tirer", Vector2(-140, -190), 90, "TIRER", BLAZE, ["fire"], false, 5)
	_add("souffle", Vector2(120, -190), 66, "SOUFFLE", Color("#86d394"), ["fire"], true, 6)

const ICONS := preload("res://art/commandes_icones.png")          # 3 × 3 icônes de 128 px
const GADGET_ICONS := preload("res://art/gadgets_icones.png")    # 2 × 2 icônes de 128 px
const FONT_BOLD := preload("res://art/police_800.woff")

## icon : case de commandes_icones.png ; gadget_icon : case de gadgets_icones.png (boutons de gadgets).
func _add(name: String, pos: Vector2, r: float, label: String, color: Color, modes: Array, hold: bool, icon := -1, gadget_icon := -1) -> void:
	_buttons[name] = {"pos": pos, "radius": r, "label": label, "color": color, "modes": modes, "hold": hold, "icon": icon, "gicon": gadget_icon}

func set_mode(m: String) -> void:
	mode = m
	move = Vector2.ZERO
	_look = Vector2.ZERO
	_joy_finger = -1
	_look_fingers.clear()
	_down.clear()
	visible = m != ""
	queue_redraw()

## Un bouton par gadget porté (à gauche, au-dessus du joystick), seulement quand on en a un : [libellé, icône].
func set_gadgets(items: Array) -> void:
	for i in 2:
		var key := "g%d" % (i + 1)
		if i < items.size():
			_add(key, Vector2(100, -430 - i * 130), 50, String(items[i][0]).split(" ")[0].to_upper(), Color("#ffcf8a"), ["hide", "fire"], false, -1, items[i][1])
		else:
			_buttons.erase(key)
	queue_redraw()

func held(name: String) -> bool:
	return _down.has(name)

func consume_look() -> Vector2:
	var d := _look
	_look = Vector2.ZERO
	return d

func _center(b: Dictionary) -> Vector2:
	var s := get_viewport_rect().size
	var p: Vector2 = b.pos
	return Vector2(s.x + p.x if p.x < 0 else p.x, s.y + p.y)

func _button_at(pos: Vector2) -> String:
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		if mode in b.modes and pos.distance_to(_center(b)) <= b.radius * 1.15:
			return name
	return ""

func _input(e: InputEvent) -> void:
	if mode == "":
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var name := _button_at(e.position)
			if name != "":
				_down[name] = e.index
				if not _buttons[name].hold:
					tapped.emit(name)
			elif mode == "hide" and e.position.x < get_viewport_rect().size.x * 0.4 and _joy_finger == -1:
				_joy_finger = e.index
				_joy_center = e.position
				_joy_pos = e.position
			else:
				_look_fingers[e.index] = e.position
				if mode == "fire":
					var now := Time.get_ticks_msec()
					if now - _last_tap < 320 and e.position.distance_to(_last_tap_pos) < 80:
						tapped.emit("zoom")
						_last_tap = -10000
					else:
						_last_tap = now
						_last_tap_pos = e.position
		else:
			for name in _down.keys():
				if _down[name] == e.index:
					_down.erase(name)
			if e.index == _joy_finger:
				_joy_finger = -1
				move = Vector2.ZERO
			_look_fingers.erase(e.index)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		if e.index == _joy_finger:
			var d: Vector2 = e.position - _joy_center
			if d.length() > JOY_RADIUS:
				d = d.normalized() * JOY_RADIUS
			_joy_pos = _joy_center + d
			move = Vector2(d.x, -d.y) / JOY_RADIUS
			queue_redraw()
		elif _look_fingers.has(e.index):
			_look += e.position - _look_fingers[e.index]
			_look_fingers[e.index] = e.position
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if mode == "":
		return
	var font := get_theme_default_font()
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		if not mode in b.modes:
			continue
		var c := _center(b)
		var col: Color = b.color
		var r: float = b.radius
		var pressed := _down.has(name)
		# Cercle sombre translucide, liseré fin de la couleur du bouton, icône blanche et petit libellé dessous.
		draw_circle(c, r, Color(col, 0.45) if pressed else Color(0.02, 0.03, 0.04, 0.42))
		draw_arc(c, r, 0, TAU, 64, Color(col, 1.0 if pressed else 0.8), 2.5, true)
		draw_arc(c, r - 5.0, 0, TAU, 64, Color(1, 1, 1, 0.1), 1.0, true)
		var s := r * 0.95
		var at := c - Vector2(s / 2, s * 0.62)
		if b.icon >= 0:
			draw_texture_rect_region(ICONS, Rect2(at, Vector2(s, s)), Rect2((b.icon % 3) * 128, (b.icon / 3) * 128, 128, 128), Color(1, 1, 1, 0.95))
		elif b.gicon >= 0:
			draw_texture_rect_region(GADGET_ICONS, Rect2(at, Vector2(s, s)), Rect2((b.gicon % 2) * 128, (b.gicon / 2) * 128, 128, 128), Color(1, 0.85, 0.6, 1.0))
		var size := 15 if r < 80 else 18
		var w := FONT_BOLD.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		draw_string(FONT_BOLD, c + Vector2(-w / 2, r * 0.62), b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(1, 1, 1, 0.92))
	if mode == "hide" and _joy_finger != -1:
		draw_circle(_joy_center, JOY_RADIUS, Color(0.02, 0.03, 0.04, 0.3))
		draw_arc(_joy_center, JOY_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.55), 2.0, true)
		draw_circle(_joy_pos, 36, Color(1, 1, 1, 0.5))
		draw_arc(_joy_pos, 36, 0, TAU, 48, Color(1, 1, 1, 0.9), 2.0, true)
	elif mode == "hide":
		# Indique où poser le pouce pour marcher.
		var s := get_viewport_rect().size
		var hint := Vector2(170, s.y - 170)
		draw_circle(hint, JOY_RADIUS * 0.8, Color(0.02, 0.03, 0.04, 0.25))
		draw_arc(hint, JOY_RADIUS * 0.8, 0, TAU, 64, Color(1, 1, 1, 0.3), 2.0, true)
		var t := "MARCHER"
		var w := FONT_BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
		draw_string(FONT_BOLD, hint + Vector2(-w / 2, 6), t, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 0.6))
