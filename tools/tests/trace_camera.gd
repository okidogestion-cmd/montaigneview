extends SceneTree
## Trace chiffrée de la caméra (menu, atelier, tir) : position, orientation et angle de vue image par image.
##   godot --path game --rendering-method gl_compatibility --fixed-fps 60 -s ../tools/tests/trace_camera.gd -- --out=trace.txt
## Deux versions qui doivent se comporter pareil donnent le même fichier (comparer avec diff).
## N'utilise que ce qui existe avant et après les pas B et C (fonctions de main.gd, pas ses variables de caméra).
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
	# ---------- Tir ----------
	seed(7)
	main.start_fire()
	main.ai_next = 999.0
	await _trace("révélation", 200, 20)
	main.ai_next = 999.0
	await _trace("tir", 30, 5)
	var eye: Vector3 = main.camera.global_position
	main.aim_at(eye, Vector3(0, 70, -main.world.MZ))
	await _trace("visée montagne", 10, 3)
	for r in [Vector2(40, -25), Vector2(5000, 0), Vector2(-12000, 0), Vector2(0, 9000), Vector2(0, -9000), Vector2(300, 200)]:
		main._look(r)
		await _trace("regard %s" % r, 2, 1)
	for i in 3:
		main.cycle_zoom()
		await _trace("zoom %d" % i, 20, 5)
	# x10 longtemps : le reflet de la lunette apparaît après 5 s.
	main.cycle_zoom()
	main.cycle_zoom()
	main.aim_at(main.camera.global_position, main.world.enemy.position + Vector3(0, 0.7, 0))
	main.ai_next = 999.0
	await _trace("x10", 400, 25)
	# Souffle retenu jusqu'à l'essoufflement, puis relâché.
	main.breath_held = true
	await _trace("souffle retenu", 300, 15)
	main.breath_held = false
	await _trace("souffle relâché", 120, 15)
	main.ai_next = 999.0
	# Un tir à côté (recul), puis un tir ennemi qui manque (sursaut).
	main.aim_at(main.camera.global_position, Vector3(0, 70, -main.world.MZ))
	main.shoot()
	await _trace("après le tir", 40, 2)
	main.ai_reveal = 0.0
	main.ai_shoot()
	await _trace("tir ennemi", 60, 3)
	main.win()
	await _trace("fin", 90, 10)
	main.to_menu()
	await _trace("retour menu", 60, 20)
	RenderingServer.render_loop_enabled = true
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("trace : %d lignes" % lines.size())
	quit()

## Les longues séquences tournent sans dessiner l'image (rendu logiciel lent) : la caméra est calculée pareil.
func _trace(label: String, frames: int, every: int) -> void:
	RenderingServer.render_loop_enabled = frames < 30
	for i in frames:
		await process_frame
		if i % every == 0:
			var c: Camera3D = root.get_viewport().get_camera_3d()
			var t := c.global_transform
			var extra := ""
			if main.phase in ["reveal", "fire", "end"]:
				extra = " | phase %s | reflet %s %.3f | lunette %s | souffle %.2f" % [main.phase, main.glinted, main.scope_time, main.hud.scope.visible if "scope" in main.hud else "?", main.breath]
			lines.append("%s | pos %.5v | x %.5v | y %.5v | z %.5v | fov %.4f | aspect %d%s" % [label, t.origin, t.basis.x, t.basis.y, t.basis.z, c.fov, c.keep_aspect, extra])

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
