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
	seed(7)
	main.start_fire()
	main.reveal_t = 3.0
	await _wait(10)
	var eye: Vector3 = main.camera.position
	main.aim_at(eye, Vector3(0, 70, -main.world.MZ))
	await _wait(10)
	await _shot("vue_tir_x1")
	main.cycle_zoom()
	main.cycle_zoom()
	main.aim_at(eye, main.world.enemy.position + Vector3(0, 0.7, 0))
	await _wait(20)
	await _shot("lunette_x10")
	quit()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + name + ".png")
	print("capture ", name)
