extends SceneTree
## Test du compteur de performances : présent avec « -- --perf », absent sinon.
##   godot --path game -s ../tools/tests/test_perf.gd            → absent attendu
##   godot --path game -s ../tools/tests/test_perf.gd -- --perf  → présent attendu
const PerfOverlayScript := preload("res://scripts/perf_overlay.gd")
var main

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()

func _run() -> void:
	for i in 120:
		await process_frame
	var found: Array = main.get_children().filter(func(c): return c.get_script() == PerfOverlayScript)
	var wanted := "--perf" in OS.get_cmdline_user_args()
	var ok: bool = found.size() == (1 if wanted else 0)
	var text := ""
	if found.size() == 1:
		main.start_hide()
		for i in 60:
			await process_frame
		text = found[0]._label.text
		ok = ok and text.contains("i/s") and text.contains("triangles")
	print(("OK     " if ok else "ÉCHEC  ") + ("compteur présent : " + text.replace("\n", " | ") if wanted else "compteur absent (%d trouvé)" % found.size()))
	quit(0 if ok else 1)
