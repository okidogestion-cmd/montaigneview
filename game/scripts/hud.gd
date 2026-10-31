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
signal paint_ghillie(kind: String)   # "" : sans feuillage
signal orientation_changed(portrait: bool)
signal sens_changed(kind: String, value: float)   # "souris" ou "tactile", multiplicateur de sensibilité

const ZONES: Dictionary = preload("res://scripts/world.gd").ZONES
const INK := Color("#0e1418")
const PANEL := Color(0.047, 0.07, 0.086, 0.82)
const LINE := Color(0.925, 0.94, 0.91, 0.16)
const PAPER := Color("#ecf0e8")
const MUTED := Color("#a3ada7")
const BLAZE := Color("#ff7a2f")
const DANGER := Color("#ef4f4f")
const OK := Color("#86d394")

const FONT := preload("res://art/police_600.woff")       # Barlow Condensed (OFL), interface
const FONT_BOLD := preload("res://art/police_800.woff")  # titres et boutons
const SON_CLIC := preload("res://art/son_ui_clic.ogg")         # culasse du Kar98k (tools/sons_k98.sh)
const SON_CULASSE := preload("res://art/son_ui_culasse.ogg")   # la balle entre dans la chambre (bouton JOUER)
const SENS_MIN := 0.25
const SENS_MAX := 5.0
const SENS_STEP := 0.25

const SCOPE_SHADER := """
shader_type canvas_item;
// Lunette de sniper façon jeu de tir moderne : on regarde dans un tube. L'oculaire (grand cercle) et l'objectif
// (cercle un peu plus petit) se décalent l'un par rapport à l'autre quand l'arme bouge (parallaxe) ; entre les deux,
// l'intérieur sombre du tube. Verre assombri sur les bords, légère frange colorée, réticule fin à gros traits et mil-dots.
uniform float glint = 0.0;
uniform vec2 parallax = vec2(0.0);   // décalage de l'objectif (pixels), donné par main.gd selon le balancement et le recul
void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (UV - 0.5) * size;
	float r = min(size.x * 0.47, size.y * 0.45);          // oculaire
	float ro = r * 0.9;                                  // objectif, vu au fond du tube
	vec2 q = p - parallax;
	float d = length(p);
	float dq = length(q);
	float u = max(1.0, r / 420.0);
	// Verre : assombri vers le bord de l'objectif, frange rouge / bleue juste avant le bord.
	float vig = smoothstep(ro * 0.55, ro, dq) * 0.72;
	vec4 col = vec4(0.0, 0.0, 0.0, vig);
	float fringe = smoothstep(ro * 0.93, ro * 0.985, dq) * (1.0 - smoothstep(ro * 0.985, ro, dq));
	col = mix(col, vec4(0.25, 0.08, 0.06, 0.75), fringe * 0.3);   // frange discrète
	// Réticule (suit l'objectif).
	float ax = abs(q.x);
	float ay = abs(q.y);
	float hair = 0.0;
	float gap = r * 0.03;
	if (ay < u * 0.75 && ax > gap && ax < ro) hair = 1.0;
	if (ax < u * 0.75 && ay > gap && ay < ro) hair = 1.0;
	if (ay < u * 3.4 && ax > ro * 0.36 && ax < ro) hair = 1.0;
	if (ax < u * 3.4 && q.y > ro * 0.36 && q.y < ro) hair = 1.0;
	for (int k = 1; k <= 5; k++) {
		float o = ro * 0.06 * float(k);
		if (length(vec2(ax - o, q.y)) < u * 1.9 || length(vec2(q.x, ay - o)) < u * 1.9) hair = 1.0;
	}
	col = mix(col, vec4(0.012, 0.012, 0.012, 1.0), hair);
	if (dq < u * 1.7) col = vec4(0.94, 0.25, 0.22, 1.0);
	float g = glint * smoothstep(ro * 0.5, ro, dq) * 0.35;
	col = mix(col, vec4(1.0, 0.92, 0.67, max(col.a, g)), g);
	// Intérieur du tube (entre l'objectif et l'oculaire) : métal sombre, plus clair vers l'oculaire.
	float in_tube = smoothstep(ro - 2.0, ro + 1.0, dq);
	float t = clamp((d - ro * 0.8) / (r - ro * 0.8), 0.0, 1.0);
	vec4 tube = vec4(mix(vec3(0.03, 0.025, 0.025), vec3(0.11, 0.085, 0.08), t * t), 1.0);
	tube.rgb *= 0.8 + 0.2 * smoothstep(-r, r, -p.y);    // lumière qui vient d'en haut
	col = mix(col, tube, in_tube);
	// Bord de l'oculaire : liseré clair puis noir complet.
	float rim = smoothstep(r * 0.985, r, d) * (1.0 - smoothstep(r, r * 1.012, d));
	col = mix(col, vec4(0.2, 0.18, 0.17, 1.0), rim * 0.8);
	col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), smoothstep(r * 1.004, r * 1.02, d));
	COLOR = col;
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
var gadget_label: Label
var gadget_slots: Array = []   # deux cases [panneau, icône, touche]
var settings: Control
var _sens_labels := {}
var _sens := {"souris": 1.0, "tactile": 2.0}
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
var ghillie_buttons := {}
var match_bars := {}
var match_labels := {}
var paint_info: Label
var paint_panels: Array[Control] = []
var menu_hint: Label
var ready_btn: Button
var fire_keys: Label
var paint_hint: Label
var menu_card: Control
var menu_logo: Control
var menu_list: Control
var _level := "normal"
var paint_left: Control
var paint_right: Control
## Téléphone tenu debout : l'interface passe en 720 × 1280 et se réorganise (voir _apply_orientation).
var portrait := false
var _orient_done := false

var _toast_tween: Tween


func _ready() -> void:
	root = _full(Control.new())
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	root.theme = theme
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
	b.pressed.connect(func(): ui_sound(b.has_meta("son_fort")))
	return b

## Son d'un bouton : clic de culasse, ou cycle complet (balle chambrée) pour JOUER.
func ui_sound(strong := false) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = SON_CULASSE if strong else SON_CLIC
	p.volume_db = -4.0 if strong else -8.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## Titre en capitales étroites et grasses (police Barlow Condensed 800), avec espacement des lettres.
func _title(text: String, size: int, color: Color, spacing := 0, outline := false) -> Label:
	var l := _label(text, size, color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", maxi(4, size / 10))
	var fv := FontVariation.new()
	fv.base_font = FONT_BOLD
	fv.spacing_glyph = spacing
	l.add_theme_font_override("font", fv)
	return l

func _spacer_v(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Bouton biseauté façon jeu de tir moderne (fond incliné, liseré fin, texte en capitales grasses).
func _tac_button(text: String, bg: Color, fg: Color, size := 20, strong := false) -> Button:
	var b := _button(text, bg, fg, size)
	var fv := FontVariation.new()
	fv.base_font = FONT_BOLD
	fv.spacing_glyph = 2
	b.add_theme_font_override("font", fv)
	for st in [["normal", bg], ["hover", bg.lightened(0.12)], ["pressed", bg.darkened(0.15)]]:
		var sb := _style(st[1], LINE if not strong else Color(1, 1, 1, 0.0), 0, 12)
		sb.skew = Vector2(0.22, 0)
		b.add_theme_stylebox_override(st[0], sb)
	b.custom_minimum_size.y = maxf(48.0, size * 1.9)
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
## Écran titre DUSKLINE, inspiré des menus de Call of Duty : la photo en plein écran assombrie comme au cinéma,
## le logo (art/logo.png, créé avec Higgsfield) au centre avec des bandes orange fixes derrière (sans clignotement),
## trois choix sobres dessous, les aides en petit en bas.
func _build_menu() -> void:
	menu = _full(Control.new())
	var bg := TextureRect.new()
	bg.texture = preload("res://art/menu.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu.add_child(_full(bg))
	# Assombrissement : haut et bas sombres, bords sombres (vignette), le centre reste lisible.
	for dir in [Vector2(0, 1), Vector2(1, 0)]:
		var shade := TextureRect.new()
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.4, 0.62, 1.0]) if dir.y > 0 else PackedFloat32Array([0.0, 0.5, 1.0])
		gr.colors = PackedColorArray([Color(INK, 0.55), Color(INK, 0.05), Color(INK, 0.3), Color(INK, 0.9)]) if dir.y > 0 \
			else PackedColorArray([Color(INK, 0.6), Color(INK, 0.0), Color(INK, 0.6)])
		gt.gradient = gr
		gt.fill_to = dir
		shade.texture = gt
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(_full(shade))
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 34)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_card = center
	menu.add_child(center)
	# Logo et bandes glitch (positions en fraction de la taille du logo).
	menu_logo = Control.new()
	menu_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(menu_logo)
	var bars := [
		[-0.16, 0.30, 0.36, 0.50, Color(BLAZE, 0.85)], [0.58, 1.14, 0.58, 0.70, Color(BLAZE, 0.7)],
		[-0.06, 0.22, 0.74, 0.80, Color(0, 0, 0, 0.7)], [0.70, 1.04, 0.16, 0.24, Color(0, 0, 0, 0.6)],
		[0.40, 0.62, 0.86, 0.90, Color(BLAZE, 0.55)], [-0.10, 0.08, 0.20, 0.25, Color(PAPER, 0.18)],
	]
	for i in bars.size():
		var bdef: Array = bars[i]
		var r := ColorRect.new()
		r.color = bdef[4]
		r.anchor_left = bdef[0]
		r.anchor_right = bdef[1]
		r.anchor_top = bdef[2]
		r.anchor_bottom = bdef[3]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_logo.add_child(r)
	var logo := TextureRect.new()
	logo.texture = preload("res://art/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_logo.add_child(logo)
	_size_logo(false)
	# Choix.
	var list := _vbox(10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.custom_minimum_size.x = 400
	menu_list = list
	center.add_child(list)
	var play := _menu_item("JOUER", true)
	play.set_meta("son_fort", true)
	play.pressed.connect(func(): play_pressed.emit())
	list.add_child(play)
	var lvl := _menu_item("ADVERSAIRE : NORMAL", false)
	lvl.pressed.connect(func():
		var order := ["facile", "normal", "difficile"]
		level_chosen.emit(order[(order.find(_level) + 1) % order.size()]))
	level_buttons["cycle"] = lvl
	list.add_child(lvl)
	var cfg := _menu_item("RÉGLAGES", false)
	cfg.pressed.connect(func(): settings.visible = true)
	list.add_child(cfg)
	# Aides en petit, en bas.
	var foot := MarginContainer.new()
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["left", "right", "bottom"]:
		foot.add_theme_constant_override("margin_" + side, 28)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(foot)
	menu_hint = _title("Souris pour viser, clic gauche ou Espace pour tirer, clic droit ou Maj pour retenir ta respiration, molette ou Z pour zoomer, Échap pour libérer la souris.", 16, Color(PAPER, 0.75), 1, true)
	menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(menu_hint)
	root.add_child(menu)
	_build_settings()
	# Cases des gadgets portés : icône + touche (1 / 2), en haut à gauche sous la barre.
	for i in 2:
		var p := Panel.new()
		var sb := _style(Color(0.02, 0.03, 0.04, 0.55), Color("#ffcf8a", 0.7), 0, 0)
		sb.skew = Vector2(0.18, 0)
		p.add_theme_stylebox_override("panel", sb)
		p.position = Vector2(18 + i * 78, 96)
		p.size = Vector2(66, 66)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = preload("res://art/gadgets_icones.png")
		ic.texture = at
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.position = Vector2(9, 7)
		ic.size = Vector2(48, 48)
		ic.modulate = Color("#ffcf8a")
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
		var k := _title(str(i + 1), 15, PAPER)
		k.position = Vector2(50, 44)
		p.add_child(k)
		p.visible = false
		root.add_child(p)
		gadget_slots.append([p, at, k])
	gadget_label = _label("", 17, Color("#ffcf8a"))
	gadget_label.position = Vector2(18, 170)
	gadget_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	gadget_label.add_theme_constant_override("outline_size", 5)
	root.add_child(gadget_label)

## Réglages : sensibilité du regard à la souris et au doigt (multiplicateur, par pas de 0,25).

## Taille du logo : grand en paysage, presque toute la largeur debout.
func _size_logo(portrait: bool) -> void:
	var w := 640.0 if portrait else 720.0
	menu_logo.custom_minimum_size = Vector2(w, w * 346.0 / 1100.0)
	if menu_list != null:
		menu_list.custom_minimum_size.x = 560.0 if portrait else 400.0

## Choix du menu, façon Call of Duty : plaque biseautée, capitales grasses. Le choix principal est orange.
func _menu_item(text: String, primary: bool) -> Button:
	var bg := BLAZE if primary else Color(0.02, 0.03, 0.04, 0.55)
	var fg := Color("#160b03") if primary else PAPER
	var b := _tac_button(text, bg, fg, 40 if primary else 24, primary)
	b.custom_minimum_size.y = 76 if primary else 54
	if not primary:
		for st in ["normal", "hover", "pressed"]:
			var sb := (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.border_color = Color(PAPER, 0.22 if st == "normal" else 0.6)
			b.add_theme_stylebox_override(st, sb)
	return b

func _build_settings() -> void:
	var parts := _center_card(440)
	settings = _full(Control.new())
	settings.add_child(_full(_rect(Color(0, 0, 0, 0.55))))
	settings.add_child(parts[0])
	var v: VBoxContainer = parts[1]
	v.add_child(_label("Réglages", 34, PAPER))
	var names := {"souris": "Sensibilité souris", "tactile": "Sensibilité tactile (doigt)"}
	for kind in ["souris", "tactile"]:
		v.add_child(_small(names[kind]))
		var row := _hbox(10)
		var minus := _button("−", Color(1, 1, 1, 0.08), PAPER, 30)
		minus.custom_minimum_size = Vector2(64, 56)
		minus.pressed.connect(func(): _step_sens(kind, -SENS_STEP))
		row.add_child(minus)
		var lab := _label("", 28, BLAZE)
		lab.custom_minimum_size.x = 110
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lab)
		_sens_labels[kind] = lab
		var plus := _button("+", Color(1, 1, 1, 0.08), PAPER, 30)
		plus.custom_minimum_size = Vector2(64, 56)
		plus.pressed.connect(func(): _step_sens(kind, SENS_STEP))
		row.add_child(plus)
		v.add_child(row)
	var note := _label("Si tu dois balayer l'écran plusieurs fois pour chercher à la lunette, augmente la sensibilité tactile.", 14, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var ok := _button("OK", BLAZE, Color("#1a0d04"), 24)
	ok.pressed.connect(func(): settings.visible = false)
	v.add_child(ok)
	settings.visible = false
	root.add_child(settings)
	for kind in _sens:
		set_sens(kind, _sens[kind])

func _step_sens(kind: String, delta: float) -> void:
	var v := clampf(snappedf(_sens[kind] + delta, SENS_STEP), SENS_MIN, SENS_MAX)
	set_sens(kind, v)
	sens_changed.emit(kind, v)

## Affiche la valeur (appelé au chargement des réglages et à chaque pas).
func set_sens(kind: String, v: float) -> void:
	_sens[kind] = v
	if _sens_labels.has(kind):
		(_sens_labels[kind] as Label).text = "× %.2f" % v

## Gadgets portés et effets en cours (en haut à gauche, pendant la cachette et le tir).
## icons : case de gadgets_icones.png de chaque gadget porté ; show_keys : touches 1 / 2 (pas au doigt,
## où les boutons des gadgets portent déjà l'icône).
func set_gadgets(text: String, icons: Array = [], show_keys := true) -> void:
	if gadget_label == null:
		return
	gadget_label.text = text
	for i in gadget_slots.size():
		var slot: Array = gadget_slots[i]
		var on := show_keys and i < icons.size()
		slot[0].visible = on
		if on:
			var n: int = icons[i]
			(slot[1] as AtlasTexture).region = Rect2((n % 2) * 128, (n / 2) * 128, 128, 128)

func set_level(level: String) -> void:
	_level = level
	if level_buttons.has("cycle"):
		(level_buttons["cycle"] as Button).text = "ADVERSAIRE : " + level.to_upper()


# ---------- Phase cachette ----------
func _build_hide() -> void:
	hide_hud = _full(Control.new())
	var top := _bar(true)
	var th := _hbox()
	var tv := _vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_title("CACHE-TOI", 32, PAPER, 2))
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
	keys_hint = _label("ZQSD : marcher   Maj : courir   Espace : sauter   C : s'accroupir   X : se coucher   Clic droit (maintenu) : vue de tir   Entrée : prêt   Échap : souris", 13, MUTED)
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

## Petite lunette ennemie retirée (31/10/2026, demande de l'utilisateur) : toujours cachée, plus dessinée.
func show_inset(_on: bool) -> void:
	var on := false
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
	zv.add_child(_small("Zoom (molette / Z, double tape au doigt)"))
	zoom_label = _label("x1", 26, PAPER)
	zv.add_child(zoom_label)
	bh.add_child(zv)
	bh.add_child(_spacer())
	fire_keys = _label("Clic gauche ou Espace : tirer   1 / 2 : gadgets   R : changer de cachette\nÉchap : libérer la souris", 14, MUTED)
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

## Décalage de l'objectif dans la lunette (pixels) : effet de tube quand l'arme bouge.
func set_scope_parallax(v: Vector2) -> void:
	(scope.material as ShaderMaterial).set_shader_parameter("parallax", v)

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
	og.columns = 2   # six motifs
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
	var gg := GridContainer.new()
	gg.columns = 2
	gg.add_theme_constant_override("h_separation", 6)
	gg.add_theme_constant_override("v_separation", 6)
	var kinds := {"": "Sans"}
	for k in PaintScript.GHILLIES:
		kinds[k] = PaintScript.GHILLIES[k][0]
	for k in kinds:
		var b := _button(kinds[k], Color(1, 1, 1, 0.06), PAPER, 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): paint_ghillie.emit(k))
		ghillie_buttons[k] = b
		gg.add_child(b)
	gs.add_child(gg)
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

func set_outfit_state(outfit: String, ghillie: String, pose: String) -> void:
	_mark(outfit_buttons, outfit)
	_mark(ghillie_buttons, ghillie)
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
	menu_hint.text = "Glisse le doigt pour regarder et viser. Double tape pour zoomer. Les boutons ronds : sauter, s'accroupir, se coucher, tirer, retenir son souffle, gadgets."
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
	_size_logo(portrait)
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
