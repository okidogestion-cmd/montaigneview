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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Positions comptées depuis le bas droit (x négatif) ou le bas gauche (x positif).
	_add("pret", Vector2(-110, -560), 62, "PRÊT", BLAZE, ["hide"], false)
	_add("viser", Vector2(-110, -390), 62, "Viser", PAPER, ["hide"], true)
	_add("couche", Vector2(-110, -235), 58, "Couché", PAPER, ["hide"], false)
	_add("accroupi", Vector2(-245, -150), 58, "Accroupi", PAPER, ["hide"], false)
	_add("tirer", Vector2(-140, -190), 92, "TIRER", DANGER, ["fire"], false)
	_add("zoom", Vector2(-300, -110), 58, "Zoom", PAPER, ["fire"], false)
	_add("souffle", Vector2(120, -190), 72, "Souffle", Color("#86d394"), ["fire"], true)

func _add(name: String, pos: Vector2, r: float, label: String, color: Color, modes: Array, hold: bool) -> void:
	_buttons[name] = {"pos": pos, "radius": r, "label": label, "color": color, "modes": modes, "hold": hold}

func set_mode(m: String) -> void:
	mode = m
	move = Vector2.ZERO
	_look = Vector2.ZERO
	_joy_finger = -1
	_look_fingers.clear()
	_down.clear()
	visible = m != ""
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
		var pressed := _down.has(name)
		draw_circle(c, b.radius, Color(col, 0.55 if pressed else 0.28))
		draw_arc(c, b.radius, 0, TAU, 48, Color(col, 0.9), 3.0, true)
		var size := 26 if b.radius > 80 else 20
		var w := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		draw_string(font, c + Vector2(-w / 2, size * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, size, PAPER)
	if mode == "hide" and _joy_finger != -1:
		draw_circle(_joy_center, JOY_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(_joy_center, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)
		draw_circle(_joy_pos, 38, Color(1, 1, 1, 0.45))
	elif mode == "hide":
		# Indique où poser le pouce pour marcher.
		var s := get_viewport_rect().size
		var hint := Vector2(170, s.y - 170)
		draw_arc(hint, JOY_RADIUS * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0, true)
		var t := "Marcher"
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_string(font, hint + Vector2(-w / 2, 6), t, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 1, 1, 0.6))
