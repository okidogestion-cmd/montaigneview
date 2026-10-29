extends CanvasLayer
## Toute l'interface : menu, phase cachette, phase de tir, fin.
## Construite en code pour rester proche du prototype web.

signal play_pressed
signal level_chosen(level: String)
signal camo_chosen(zone: String)
signal ready_pressed
signal menu_pressed
signal again_pressed
signal paint_color(color: Color)
signal paint_size(index: int)
signal paint_tool(tool: String)
signal paint_pose(pose: String)
signal paint_undo
signal paint_clear
signal paint_done
signal paint_outfit(outfit: String)
signal paint_ghillie(on: bool)
signal orientation_changed(portrait: bool)

const ZONES: Dictionary = preload("res://scripts/world.gd").ZONES
const INK := Color("#0e1418")
const PANEL := Color(0.047, 0.07, 0.086, 0.82)
const LINE := Color(0.925, 0.94, 0.91, 0.16)
const PAPER := Color("#ecf0e8")
const MUTED := Color("#a3ada7")
const BLAZE := Color("#ff7a2f")
const DANGER := Color("#ef4f4f")
const OK := Color("#86d394")

const SCOPE_SHADER := """
shader_type canvas_item;
uniform float glint = 0.0;
void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (UV - 0.5) * size;
	float r = min(size.x * 0.46, size.y * 0.40);
	float d = length(p);
	float outside = smoothstep(r - 3.0, r, d);
	float hair = 0.0;
	if (abs(p.y) < 0.9 && abs(p.x) > r * 0.08 && abs(p.x) < r) hair = 0.85;
	if (abs(p.x) < 0.9 && abs(p.y) > r * 0.08 && abs(p.y) < r) hair = 0.85;
	vec4 col = vec4(0.04, 0.04, 0.04, hair);
	if (d < 2.2) col = vec4(0.94, 0.31, 0.31, 1.0);
	float g = glint * smoothstep(r * 0.55, r, d) * 0.35;
	col = mix(col, vec4(1.0, 0.92, 0.67, max(col.a, g)), g);
	COLOR = mix(col, vec4(0.02, 0.027, 0.03, 1.0), outside);
}
"""

var root: Control
var fog_overlay: ColorRect
var fog_layers: Array[TextureRect] = []
var scope: ColorRect
var dot: Control
var flash: ColorRect
var hurt: ColorRect
var toast_panel: PanelContainer
var toast_label: Label
var center_label: Label

var menu: Control
var level_buttons := {}

var hide_hud: Control
var hide_timer: Label
var zone_info: RichTextLabel
var keys_hint: Label
var swatches := {}
var inset: SubViewportContainer
var inset_viewport: SubViewport
var inset_label: Label

var fire_hud: Control
var ammo_box: HBoxContainer
var eye_fill: ColorRect
var breath_bar: ProgressBar
var zoom_label: Label

var end_panel: Control
var end_title: Label
var end_text: Label
var end_tips: Label

var paint_hud: Control
var paint_colors := []
var paint_sizes := []
var paint_tools := {}
var paint_poses := {}
var outfit_buttons := {}
var ghillie_button: Button
var match_bars := {}
var match_labels := {}
var paint_info: Label
var paint_panels: Array[Control] = []
var menu_hint: Label
var ready_btn: Button
var fire_keys: Label
var paint_hint: Label
var menu_card: Control
var paint_left: Control
var paint_right: Control
## Téléphone tenu debout : l'interface passe en 720 × 1280 et se réorganise (voir _apply_orientation).
var portrait := false
var _orient_done := false

var _toast_tween: Tween


func _ready() -> void:
	root = _full(Control.new())
	add_child(root)
	fog_overlay = _full(_rect(Color("#dfe6ea", 0)))
	root.add_child(fog_overlay)
	# Deux nappes de brume (art/brume.jpg, créée avec Higgsfield) qui s'écartent quand le brouillard se lève.
	for i in 2:
		var f := TextureRect.new()
		f.texture = preload("res://art/brume.jpg")
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_SCALE
		f.flip_h = i == 1
		var fm := CanvasItemMaterial.new()
		fm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		f.material = fm
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.visible = false
		root.add_child(f)
		fog_layers.append(f)
	scope = _full(ColorRect.new())
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = SCOPE_SHADER
	scope.material = sm
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.visible = false
	root.add_child(scope)
	dot = _crosshair()
	root.add_child(dot)
	flash = _full(_rect(Color(1, 1, 1, 0)))
	root.add_child(flash)
	hurt = _full(_rect(Color(DANGER, 0)))
	root.add_child(hurt)
	_build_menu()
	_build_hide()
	_build_fire()
	_build_end()
	_build_paint()
	center_label = _label("", 52, PAPER)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.set_anchors_preset(Control.PRESET_CENTER)
	center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	center_label.add_theme_constant_override("shadow_outline_size", 8)
	root.add_child(center_label)
	toast_panel = _panel()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.position.y = 76
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = _label("", 19, PAPER)
	toast_panel.add_child(toast_label)
	toast_panel.modulate.a = 0
	root.add_child(toast_panel)


## Brume de 1 (écran noyé) à 0 (dégagé) : fond clair + deux nappes qui s'écartent et s'effacent.
func set_fog_amount(a: float) -> void:
	fog_overlay.color.a = clampf((a - 0.45) / 0.55, 0, 1)
	var vs := root.size
	for i in fog_layers.size():
		var f := fog_layers[i]
		f.visible = a > 0.001
		if not f.visible:
			continue
		var spread := (1.0 - a) * 0.5 * vs.x
		f.size = vs * Vector2(1.6, 1.2) * (1.0 + (1.0 - a) * 0.4)
		f.position = Vector2((vs.x - f.size.x) / 2 + (spread if i == 1 else -spread), (vs.y - f.size.y) / 2)
		f.modulate.a = clampf(a * 1.4, 0, 1)


# ---------- Petites fabriques ----------
func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _small(text: String) -> Label:
	var l := _label(text.to_upper(), 13, MUTED)
	return l

func _style(bg: Color, border := Color(0, 0, 0, 0), radius := 6, pad := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PANEL, LINE, 6, 14))
	return p

func _button(text: String, bg: Color, fg: Color, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_stylebox_override("normal", _style(bg, LINE, 4, 10))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.12), LINE, 4, 10))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.15), LINE, 4, 10))
	return b

func _vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

func _hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

func _bar(top: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(PANEL, 0.7), Color(0, 0, 0, 0), 0, 14))
	p.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if not top:
		p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _crosshair() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for v in [Rect2(-9, -1, 18, 2), Rect2(-1, -9, 2, 18)]:
		var r := _rect(Color(PAPER, 0.8))
		r.position = v.position
		r.size = v.size
		c.add_child(r)
	c.visible = false
	return c

func _center_card(width: float) -> Array:
	var holder := _full(CenterContainer.new())
	var card := _panel()
	card.add_theme_stylebox_override("panel", _style(PANEL, LINE, 6, 22))
	card.custom_minimum_size.x = width
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(card)
	var v := _vbox(16)
	card.add_child(v)
	return [holder, v]


# ---------- Menu ----------
func _build_menu() -> void:
	var parts := _center_card(440)
	# Illustration du menu (art/menu.jpg, créée avec Higgsfield) derrière la carte, poussée à droite.
	menu = _full(Control.new())
	var bg := TextureRect.new()
	bg.texture = preload("res://art/menu.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu.add_child(_full(bg))
	menu.add_child(_full(_rect(Color(INK, 0.3))))
	menu_card = parts[0]
	menu_card.anchor_left = 0.42
	menu.add_child(menu_card)
	var v: VBoxContainer = parts[1]
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_size_override("normal_font_size", 58)
	title.text = "Duel des [color=#ff7a2f]Cimes[/color]"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var pitch := _label("Deux montagnes, deux snipers. Le premier qui trouve l'autre a gagné.", 18, MUTED)
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pitch)
	var steps := [
		"Cache-toi sur ta montagne et choisis une tenue de la couleur du terrain.",
		"Le brouillard se lève sur la vallée.",
		"Fouille la montagne d'en face à la lunette et tire avant d'être repéré. Chaque tir raté trahit ta position.",
	]
	for i in steps.size():
		var row := _hbox(10)
		var n := _label(str(i + 1), 24, BLAZE)
		n.custom_minimum_size.x = 22
		row.add_child(n)
		var t := _label(steps[i], 16, PAPER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		v.add_child(row)
	v.add_child(_small("Adversaire (ordinateur)"))
	var seg := _hbox(0)
	for lv in ["facile", "normal", "difficile"]:
		var b := _button(lv.capitalize(), Color(1, 1, 1, 0.04), PAPER, 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): level_chosen.emit(lv))
		level_buttons[lv] = b
		seg.add_child(b)
	v.add_child(seg)
	var play := _button("JOUER", BLAZE, Color("#1a0d04"), 28)
	play.pressed.connect(func(): play_pressed.emit())
	v.add_child(play)
	menu_hint = _label("Souris pour viser, clic gauche ou Espace pour tirer, clic droit ou Maj pour retenir ta respiration, molette ou Z pour zoomer, Échap pour libérer la souris.", 14, MUTED)
	var hint := menu_hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	root.add_child(menu)

func set_level(level: String) -> void:
	for lv in level_buttons:
		var b: Button = level_buttons[lv]
		var on: bool = lv == level
		var bg := PAPER if on else Color(1, 1, 1, 0.04)
		var fg := INK if on else PAPER
		b.add_theme_stylebox_override("normal", _style(bg, LINE, 0, 10))
		b.add_theme_stylebox_override("hover", _style(bg.lightened(0.1), LINE, 0, 10))
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(st, fg)


# ---------- Phase cachette ----------
func _build_hide() -> void:
	hide_hud = _full(Control.new())
	var top := _bar(true)
	var th := _hbox()
	var tv := _vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_label("Cache-toi", 30, PAPER))
	var hide_sub := _small("Trouve une cachette sur ton île, puis tu choisiras ta tenue de camouflage sur place. L'ennemi regarde depuis l'île d'en face.")
	hide_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(hide_sub)
	th.add_child(tv)
	var tr := _vbox(2)
	var tl := _small("Temps")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(tl)
	hide_timer = _label("60", 30, PAPER)
	hide_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(hide_timer)
	th.add_child(tr)
	top.add_child(th)
	hide_hud.add_child(top)

	inset = SubViewportContainer.new()
	inset.stretch = true
	inset.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inset.custom_minimum_size = Vector2(200, 200)
	inset.size = Vector2(200, 200)
	inset.position = Vector2(-214, 92)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset_viewport = SubViewport.new()
	inset_viewport.size = Vector2i(200, 200)
	inset.add_child(inset_viewport)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _frame_style())
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(frame)
	hide_hud.add_child(inset)
	inset_label = _label("LUNETTE ENNEMIE", 12, PAPER)
	inset_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inset_label.position = Vector2(-170, 298)
	hide_hud.add_child(inset_label)

	var bottom := _bar(false)
	var bv := _vbox(10)
	var r1 := _hbox()
	zone_info = RichTextLabel.new()
	zone_info.bbcode_enabled = true
	zone_info.fit_content = true
	zone_info.scroll_active = false
	zone_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_info.add_theme_font_size_override("normal_font_size", 17)
	zone_info.add_theme_font_size_override("bold_font_size", 17)
	zone_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r1.add_child(zone_info)
	bv.add_child(r1)
	keys_hint = _label("ZQSD : marcher   Maj : courir   C : s'accroupir   X : se coucher   Clic droit (maintenu) : vue de tir   Entrée : prêt   Échap : souris", 13, MUTED)
	keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(keys_hint)
	var r2 := _hbox()
	var sv := _vbox(5)
	sv.visible = false  # la tenue se fait maintenant à l'atelier de peinture
	sv.add_child(_small("Tenue"))
	var sw := _hbox(8)
	for k in ["neige", "roche", "herbe", "foret"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%d %s" % [["neige", "roche", "herbe", "foret"].find(k) + 1, ZONES[k]["label"]]
		b.icon = _swatch_icon(ZONES[k]["color"])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(64, 0)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func(): camo_chosen.emit(k))
		swatches[k] = b
		sw.add_child(b)
	sv.add_child(sw)
	r2.add_child(sv)
	r2.add_child(_spacer())
	ready_btn = _button("PRÊT", BLAZE, Color("#1a0d04"), 24)
	ready_btn.text = "PRÊT (Entrée)"
	ready_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	ready_btn.pressed.connect(func(): ready_pressed.emit())
	r2.add_child(ready_btn)
	bv.add_child(r2)
	bottom.add_child(bv)
	hide_hud.add_child(bottom)
	hide_hud.visible = false
	root.add_child(hide_hud)

func _frame_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = BLAZE
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s

func _swatch_icon(color: Color) -> Texture2D:
	var img := Image.create(30, 22, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func set_swatch(zone: String) -> void:
	for k in swatches:
		var b: Button = swatches[k]
		var on: bool = k == zone
		var s := _style(Color(1, 1, 1, 0.06), BLAZE if on else Color(0, 0, 0, 0), 4, 5)
		s.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
		b.add_theme_stylebox_override("pressed", s)

func show_inset(on: bool) -> void:
	inset.visible = on
	inset_label.visible = on
	# Mise à jour à la demande (main.gd la rafraîchit une image sur 4) : le monde est dessiné deux fois sinon.
	inset_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if on else SubViewport.UPDATE_DISABLED


# ---------- Phase de tir ----------
func _build_fire() -> void:
	fire_hud = _full(Control.new())
	var top := _bar(true)
	var th := _hbox()
	var av := _vbox(4)
	av.add_child(_small("Balles"))
	ammo_box = _hbox(5)
	av.add_child(ammo_box)
	th.add_child(av)
	th.add_child(_spacer())
	var ev := _vbox(5)
	var el := _small("L'ennemi te repère")
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ev.add_child(el)
	var meter := _rect(Color(1, 1, 1, 0.14))
	meter.custom_minimum_size = Vector2(170, 8)
	eye_fill = _rect(DANGER)
	eye_fill.size = Vector2(0, 8)
	meter.add_child(eye_fill)
	ev.add_child(meter)
	th.add_child(ev)
	top.add_child(th)
	fire_hud.add_child(top)

	var bottom := _bar(false)
	var bh := _hbox(18)
	var bv := _vbox(4)
	bv.add_child(_small("Souffle (Maj / clic droit)"))
	breath_bar = ProgressBar.new()
	breath_bar.show_percentage = false
	breath_bar.custom_minimum_size = Vector2(170, 10)
	breath_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 4, 0))
	breath_bar.add_theme_stylebox_override("fill", _style(OK, Color(0, 0, 0, 0), 4, 0))
	breath_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(breath_bar)
	bh.add_child(bv)
	var zv := _vbox(4)
	zv.add_child(_small("Zoom (molette / Z)"))
	zoom_label = _label("x1", 26, PAPER)
	zv.add_child(zoom_label)
	bh.add_child(zv)
	bh.add_child(_spacer())
	fire_keys = _label("Clic gauche ou Espace : tirer\nÉchap : libérer la souris", 14, MUTED)
	var keys := fire_keys
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bh.add_child(keys)
	bottom.add_child(bh)
	fire_hud.add_child(bottom)
	fire_hud.visible = false
	root.add_child(fire_hud)

func render_ammo(left: int, total: int) -> void:
	for c in ammo_box.get_children():
		c.queue_free()
	for i in total:
		var r := _rect(BLAZE if i >= total - left else Color(1, 1, 1, 0.18))
		r.custom_minimum_size = Vector2(7, 20)
		ammo_box.add_child(r)

func set_eye(v: float) -> void:
	eye_fill.size = Vector2(170 * clampf(v, 0, 1), 8)
	eye_fill.color = OK.lerp(Color("#e9c84a"), clampf(v * 2, 0, 1)).lerp(DANGER, clampf(v * 2 - 1, 0, 1))

func set_scope(on: bool, glint := false) -> void:
	scope.visible = on
	(scope.material as ShaderMaterial).set_shader_parameter("glint", 1.0 if glint else 0.0)


# ---------- Fin ----------
func _build_end() -> void:
	end_panel = _full(Control.new())
	var holder := _full(MarginContainer.new())
	holder.add_theme_constant_override("margin_bottom", 16)
	var box := _vbox(0)
	box.alignment = BoxContainer.ALIGNMENT_END
	var card := _panel()
	card.add_theme_stylebox_override("panel", _style(PANEL, LINE, 6, 20))
	card.custom_minimum_size.x = 460
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := _vbox(12)
	end_title = _label("", 46, OK)
	v.add_child(end_title)
	end_text = _label("", 17, PAPER)
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_text.custom_minimum_size.x = 420
	v.add_child(end_text)
	end_tips = _label("", 15, MUTED)
	end_tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_tips.custom_minimum_size.x = 420
	v.add_child(end_tips)
	var row := _hbox(10)
	var to_menu := _button("Menu", Color(1, 1, 1, 0.08), PAPER, 18)
	to_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to_menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(to_menu)
	var again := _button("REJOUER", BLAZE, Color("#1a0d04"), 22)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): again_pressed.emit())
	row.add_child(again)
	v.add_child(row)
	card.add_child(v)
	box.add_child(card)
	holder.add_child(box)
	end_panel.add_child(holder)
	end_panel.visible = false
	root.add_child(end_panel)


# ---------- Effets ----------
func toast(msg: String, secs := 2.6) -> void:
	toast_label.text = msg
	if _toast_tween:
		_toast_tween.kill()
	toast_panel.modulate.a = 1
	_toast_tween = create_tween()
	_toast_tween.tween_interval(secs)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.25)

func hide_toast() -> void:
	if _toast_tween:
		_toast_tween.kill()
	toast_panel.modulate.a = 0

func pulse(rect: ColorRect, from: float, secs: float) -> void:
	rect.color.a = from
	create_tween().tween_property(rect, "color:a", 0.0, secs).set_ease(Tween.EASE_OUT)


# ---------- Atelier de peinture ----------
const PaintScript := preload("res://scripts/paint.gd")

func _section(title: String) -> VBoxContainer:
	var v := _vbox(6)
	v.add_child(_small(title))
	return v

func _build_paint() -> void:
	paint_hud = _full(Control.new())
	var top := _bar(true)
	var tv := _vbox(2)
	tv.add_child(_label("Camouflage", 30, PAPER))
	var paint_sub := _small("Choisis la tenue qui ressemble au terrain de ta cachette")
	paint_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(paint_sub)
	top.add_child(tv)
	paint_hud.add_child(top)

	# Panneau de gauche : couleurs, pinceau, outils, posture.
	var left := _panel()
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.grow_vertical = Control.GROW_DIRECTION_BOTH
	left.position.x = 14
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	var lv := _vbox(14)
	# Mode normal : on choisit une tenue de camouflage (la peinture libre reviendra dans un mode à part).
	var os := _section("Tenue")
	var og := GridContainer.new()
	og.columns = 2   # quatre motifs
	og.add_theme_constant_override("h_separation", 6)
	og.add_theme_constant_override("v_separation", 6)
	for k in PaintScript.OUTFITS:
		var o: Array = PaintScript.OUTFITS[k]
		var b := _button(o[0], Color(1, 1, 1, 0.06), PAPER, 15)
		var img: Image = (load(o[1]) as Texture2D).get_image()
		img.decompress()
		img.resize(34, 24)
		b.icon = ImageTexture.create_from_image(img)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): paint_outfit.emit(k))
		outfit_buttons[k] = b
		og.add_child(b)
	os.add_child(og)
	lv.add_child(os)
	var gs := _section("Feuillage")
	ghillie_button = _button("Tenue de feuillage (ghillie)", Color(1, 1, 1, 0.06), PAPER, 15)
	ghillie_button.toggle_mode = true
	ghillie_button.toggled.connect(func(on): paint_ghillie.emit(on))
	gs.add_child(ghillie_button)
	lv.add_child(gs)
	var ps := _section("Voir la posture")
	var ph := _hbox(6)
	for p in [["debout", "Debout"], ["accroupi", "Accroupi"], ["couche", "Couché"]]:
		var b := _button(p[1], Color(1, 1, 1, 0.06), PAPER, 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): paint_pose.emit(p[0]))
		paint_poses[p[0]] = b
		ph.add_child(b)
	ps.add_child(ph)
	lv.add_child(ps)
	left.add_child(lv)
	paint_hud.add_child(left)
	paint_panels.append(left)
	paint_left = left

	# Panneau de droite : ressemblance avec chaque terrain.
	var right := _panel()
	right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right.grow_vertical = Control.GROW_DIRECTION_BOTH
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position.x = -14
	right.custom_minimum_size.x = 230
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	var rv := _vbox(10)
	rv.add_child(_small("Camouflage sur chaque terrain"))
	for k in ["neige", "roche", "herbe", "foret"]:
		var row := _vbox(3)
		var lh := _hbox(6)
		var name_l := _label(ZONES[k]["label"], 16, PAPER)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(name_l)
		var pct := _label("0 %", 16, PAPER)
		lh.add_child(pct)
		match_labels[k] = pct
		row.add_child(lh)
		var bg := _rect(Color(1, 1, 1, 0.14))
		bg.custom_minimum_size = Vector2(200, 8)
		var fill := _rect(ZONES[k]["color"])
		fill.size = Vector2(0, 8)
		bg.add_child(fill)
		match_bars[k] = fill
		row.add_child(bg)
		rv.add_child(row)
	paint_info = _label("", 14, MUTED)
	paint_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paint_info.custom_minimum_size.x = 200
	rv.add_child(paint_info)
	right.add_child(rv)
	paint_hud.add_child(right)
	paint_panels.append(right)
	paint_right = right

	var bottom := _bar(false)
	var bh := _hbox()
	paint_hint = _label("Glisser : tourner autour   Molette : zoom", 14, MUTED)
	var hint := paint_hint
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bh.add_child(hint)
	var done := _button("TERMINÉ", BLAZE, Color("#1a0d04"), 24)
	done.pressed.connect(func(): paint_done.emit())
	bh.add_child(done)
	bottom.add_child(bh)
	paint_hud.add_child(bottom)
	paint_hud.visible = false
	root.add_child(paint_hud)

func _mark(buttons: Dictionary, key) -> void:
	for k in buttons:
		var b: Button = buttons[k]
		var on: bool = k == key
		b.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.22) if on else Color(1, 1, 1, 0.06), BLAZE if on else LINE, 4, 10))

func set_paint_state(color: Color, size_idx: int, tool: String, pose: String) -> void:
	for b in paint_colors:
		var c: Color = b.get_meta("color")
		b.add_theme_stylebox_override("normal", _style(c, BLAZE if c == color else Color(0, 0, 0, 0.4), 4, 0))
		var s: StyleBoxFlat = b.get_theme_stylebox("normal")
		s.set_border_width_all(3 if c == color else 1)
	var sizes := {}
	for i in paint_sizes.size():
		sizes[i] = paint_sizes[i]
	_mark(sizes, size_idx)
	_mark(paint_tools, tool)
	_mark(paint_poses, pose)

func set_outfit_state(outfit: String, ghillie: bool, pose: String) -> void:
	_mark(outfit_buttons, outfit)
	ghillie_button.set_pressed_no_signal(ghillie)
	ghillie_button.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.22) if ghillie else Color(1, 1, 1, 0.06), BLAZE if ghillie else LINE, 4, 10))
	_mark(paint_poses, pose)

func set_matches(scores: Dictionary) -> void:
	var best := ""
	for k in scores:
		var v: float = scores[k]
		match_labels[k].text = "%d %%" % roundi(v * 100)
		(match_bars[k] as ColorRect).size = Vector2(200 * v, 8)
		if best == "" or v > scores[best]:
			best = k
	paint_info.text = "Cette tenue va le mieux sur la %s. La tenue de feuillage casse encore plus ta silhouette." % ZONES[best]["label"].to_lower()


# ---------- Mode tactile ----------
func set_touch_mode(on: bool) -> void:
	# Au doigt : les aides parlent de doigts, et les boutons ronds de touch_controls.gd
	# remplacent le bouton « Prêt » et les touches du clavier.
	if not on:
		return
	menu_hint.text = "Glisse le doigt pour regarder et viser. Les gros boutons ronds servent à s'accroupir, se coucher, tirer, zoomer et retenir son souffle."
	keys_hint.text = "Pouce gauche : marcher (à fond : courir)   ·   Glisser à droite : regarder   ·   Viser (maintenu) : vue de tir"
	ready_btn.visible = false
	fire_keys.visible = false
	# La petite lunette ennemie passe en haut à gauche : la droite est aux gros boutons.
	inset.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inset.position = Vector2(14, 92)
	inset_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inset_label.position = Vector2(58, 298)
	for l in fire_hud.find_children("*", "Label", true, false):
		(l as Label).text = (l as Label).text.replace(" (MAJ / CLIC DROIT)", "").replace(" (MOLETTE / Z)", "")
	paint_hint.text = "Un doigt : tourner autour   ·   Deux doigts : zoomer"

func over_paint_panel(pos: Vector2) -> bool:
	for p in paint_panels:
		if p.is_visible_in_tree() and p.get_global_rect().has_point(pos):
			return true
	return false

func _process(_dt: float) -> void:
	# Le jeu se joue téléphone debout ou couché : on suit l'orientation de l'écran.
	var ws := get_window().size
	var p := ws.y > ws.x * 1.05
	if p != portrait or not _orient_done:
		_orient_done = true
		portrait = p
		_apply_orientation()

## Place un panneau sur un point d'ancrage (0 à 1) avec un décalage, et dans quel sens il grandit.
func _pin(c: Control, anchor: Vector2, offset: Vector2, grow_h: int, grow_v: int) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_right = offset.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v
	c.reset_size()

func _apply_orientation() -> void:
	# Base 720 × 1280 debout (au lieu de 1280 × 720) : le texte garde sa taille sur un écran étroit.
	get_window().content_scale_size = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	# Menu : la carte au centre debout ; à droite couché, pour laisser voir l'illustration.
	menu_card.anchor_left = 0.0 if portrait else 0.42
	# Lunette ennemie : un peu plus bas debout, le bandeau du haut y prend trois lignes.
	inset.position.y = 132 if portrait else 92
	inset_label.position.y = inset.position.y + 206
	# Atelier : debout, les couleurs en bas à gauche et le camouflage en haut à droite, le sniper au milieu.
	if portrait:
		_pin(paint_left, Vector2(0, 1), Vector2(14, -110), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
		_pin(paint_right, Vector2(1, 0), Vector2(-14, 120), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	else:
		_pin(paint_left, Vector2(0, 0.5), Vector2(14, 0), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH)
		_pin(paint_right, Vector2(1, 0.5), Vector2(-14, 0), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BOTH)
	orientation_changed.emit(portrait)
