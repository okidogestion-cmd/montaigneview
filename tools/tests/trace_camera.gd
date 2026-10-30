extends SceneTree
## Trace chiffrée de la caméra (menu et atelier) : position, orientation et angle de vue image par image.
##   godot --path game --rendering-method gl_compatibility --fixed-fps 60 -s ../tools/tests/trace_camera.gd -- --out=trace.txt
## Deux versions qui doivent se comporter pareil donnent le même fichier (comparer avec diff).
## N'utilise que ce qui existe avant et après le pas B.
var main
var out := ""
var lines := PackedStringArray()

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	seed(20261030)
	_run()

func _run() -> void:
	await _wait(120)
	await _trace("menu", 240, 20)
	main.start_hide()
	await _wait(20)
	main.start_paint()
	await _trace("atelier", 5, 1)
	# Souris : clic gauche maintenu + glisser, molette dans les deux sens (jusqu'aux butées).
	_click(MOUSE_BUTTON_LEFT, true)
	for r in [Vector2(-140, 60), Vector2(30, 900), Vector2(-500, -2000), Vector2(10, 5)]:
		_motion(r)
		await _trace("souris %s" % r, 1, 1)
	_click(MOUSE_BUTTON_LEFT, false)
	_motion(Vector2(300, 0))   # bouton relâché : ne tourne plus
	await _trace("relâché", 1, 1)
	_click(MOUSE_BUTTON_RIGHT, true)
	_motion(Vector2(80, 20))
	_click(MOUSE_BUTTON_RIGHT, false)
	await _trace("clic droit", 1, 1)
	for i in 12:
		_click(MOUSE_BUTTON_WHEEL_UP, true)
	await _trace("molette avant", 1, 1)
	for i in 30:
		_click(MOUSE_BUTTON_WHEEL_DOWN, true)
	await _trace("molette arrière", 1, 1)
	# Doigts : glisser à un doigt, pincer à deux.
	var mid := Vector2(root.get_viewport().get_visible_rect().size) * Vector2(0.55, 0.5)
	_touch(0, mid, true)
	_drag(0, mid + Vector2(90, -40))
	await _trace("doigt", 1, 1)
	_touch(1, mid + Vector2(200, 0), true)
	for x in [260, 320, 150, 100]:
		_drag(1, mid + Vector2(x, 0))
		await _trace("pincer %d" % x, 1, 1)
	_touch(1, mid, false)
	_touch(0, mid, false)
	for p in ["couche", "accroupi", "debout"]:
		main._on_paint_pose(p)
		await _trace("posture " + p, 3, 1)
	main.to_menu()
	await _trace("retour menu", 60, 20)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("trace : %d lignes" % lines.size())
	quit()

func _trace(label: String, frames: int, every: int) -> void:
	for i in frames:
		await process_frame
		if i % every == 0:
			var c: Camera3D = root.get_viewport().get_camera_3d()
			var t := c.global_transform
			lines.append("%s | pos %.5v | x %.5v | y %.5v | z %.5v | fov %.4f | aspect %d" % [label, t.origin, t.basis.x, t.basis.y, t.basis.z, c.fov, c.keep_aspect])

func _click(button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	main._paint_input(e)

func _motion(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	main._paint_input(e)

func _touch(i: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = pressed
	main._paint_touch(e)

func _drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	main._paint_touch(e)

func _wait(n: int) -> void:
	for i in n:
		await process_frame
