extends CanvasLayer
## Compteur de performances, pour mesurer sur le téléphone.
## Activé seulement avec « ?perf » ou « #perf » dans l'adresse (version web) ou « -- --perf » (PC) :
## sans ce mot, main.gd ne le crée pas du tout (aucun coût).
## Affiche, sur la dernière demi-seconde : images par seconde, durée moyenne et pire durée d'une image,
## nombre d'images trop longues (> 20 ms : saccade visible), temps des scripts, et ce que dessine la carte
## graphique (appels de dessin, triangles, temps GPU quand le navigateur le donne).

const PERIOD := 0.5        # mise à jour du texte (s)
const JANK_MS := 20.0      # au-delà, une image à 60 i/s est sautée

var _label: Label
var _last_us := 0
var _acc_us := 0
var _frames := 0
var _worst_us := 0
var _janks := 0
var _proc_ms := 0.0


func _ready() -> void:
	layer = 100
	var bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_content_margin_all(6)
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2(8, 64)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("#e8f0e0"))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "perf…"
	bg.add_child(_label)
	add_child(bg)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last_us = Time.get_ticks_usec()

func _process(_dt: float) -> void:
	# Durée réelle entre deux images (ce que voit le joueur), pas le delta lissé du moteur.
	var now := Time.get_ticks_usec()
	var frame_us := now - _last_us
	_last_us = now
	_acc_us += frame_us
	_frames += 1
	_worst_us = maxi(_worst_us, frame_us)
	if frame_us > JANK_MS * 1000.0:
		_janks += 1
	_proc_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if _acc_us < PERIOD * 1e6:
		return
	var vp := get_viewport().get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var cpu_render := RenderingServer.viewport_get_measured_render_time_cpu(vp)
	_label.text = "%d i/s   moy %.1f ms   pire %.1f ms   saccades %d\nprocess %.2f ms   rendu CPU %.2f ms   GPU %s\n%d appels   %s triangles" % [
		roundi(_frames * 1e6 / _acc_us), _acc_us / 1000.0 / _frames, _worst_us / 1000.0, _janks,
		_proc_ms / _frames, cpu_render, ("%.2f ms" % gpu) if gpu > 0.0 else "n/d",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		_thousands(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))]
	_acc_us = 0
	_frames = 0
	_worst_us = 0
	_janks = 0
	_proc_ms = 0.0

func _thousands(n: int) -> String:
	return "%d %03d" % [n / 1000, n % 1000] if n >= 1000 else str(n)
