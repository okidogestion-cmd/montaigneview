extends SceneTree
## Captures de référence de la caméra (avant/après chaque pas du CameraRig).
##   godot --path game --rendering-method gl_compatibility --fixed-fps 60 --resolution 1280x720 \
##         -s ../tools/tests/captures_camera.gd -- --out=/dossier/
## Hasard fixé et images à cadence fixe : deux versions identiques donnent les mêmes images.
## N'utilise que ce qui existe avant et après le pas A (main.camera, aim_at, set_fov, phases).
var main
var out := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	seed(20261030)   # après le randomize() de main._ready, avant la construction du monde
	_run()

func _run() -> void:
	await _wait(120)
	main.life._particles.visible = false   # pollen en particules GPU : jamais deux fois pareil
	await _shot("menu")
	# La vue 3D du menu, sans l'interface qui la recouvre, puis 5 s plus tard (balayage lent de la vallée).
	main.hud.menu.visible = false
	await _wait(2)
	await _shot("menu_vue_3d")
	await _wait(300)
	await _shot("menu_vue_3d_5s")
	main.hud.menu.visible = true
	main.start_hide()
	await _wait(40)
	await _shot("cachette_3e_personne")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	await _wait(10)
	await _shot("cachette_viser")
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	await _wait(10)
	main.start_paint()
	main._on_outfit("digital_olive")
	main._on_ghillie(true)
	await _wait(20)
	await _shot("atelier_camouflage")
	# Orbite à la souris (clic gauche maintenu), molette, puis au doigt (glisser, pincer), puis posture couchée.
	_click(MOUSE_BUTTON_LEFT, true)
	_motion(Vector2(-140, 60))
	_click(MOUSE_BUTTON_LEFT, false)
	for i in 3:
		_click(MOUSE_BUTTON_WHEEL_UP, true)
	await _wait(5)
	await _shot("atelier_orbite_souris")
	var mid := Vector2(root.get_viewport().get_visible_rect().size) * Vector2(0.55, 0.5)
	_touch(0, mid, true)
	_drag(0, mid + Vector2(90, -40))
	_touch(1, mid + Vector2(200, 0), true)
	_drag(1, mid + Vector2(260, 0))
	_drag(1, mid + Vector2(320, 0))
	_touch(1, mid, false)
	_touch(0, mid, false)
	await _wait(5)
	await _shot("atelier_orbite_doigt")
	main._on_paint_pose("couche")
	await _wait(10)
	await _shot("atelier_couche")
	seed(7)
	main.start_fire()
	main.reveal_t = 3.0
	await _wait(10)
	var eye: Vector3 = main.camera.position
	main.aim_at(eye, Vector3(0, 70, -main.world.MZ))
	await _wait(10)
	await _shot("vue_tir_x1")
	main.cycle_zoom()
	main.aim_at(eye, Vector3(-60, 80, -main.world.MZ + 40))
	await _wait(10)
	await _shot("lunette_x4")
	main.cycle_zoom()
	main.aim_at(eye, main.world.enemy.position + Vector3(0, 0.7, 0))
	await _wait(20)
	await _shot("lunette_x10")
	main.breath_held = true
	await _wait(60)
	await _shot("lunette_x10_souffle")
	main.breath_held = false
	main.ai_next = 999.0
	main.shoot()
	await _wait(3)
	await _shot("lunette_x10_recul")
	main.win()
	await _wait(60)
	await _shot("fin_ennemi")
	quit()

## Entrées de l'atelier envoyées comme le ferait le moteur (mêmes fonctions avant et après le pas B).
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

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + name + ".png")
	print("capture ", name)
