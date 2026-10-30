extends SceneTree
## Test automatique de la caméra (non-régression du CameraRig), sans écran :
##   godot --headless --path game --fixed-fps 60 -s ../tools/tests/test_camera.gd
## Joue toutes les phases (menu, cachette, visée à l'œil, atelier, tir, fin) et vérifie la caméra.
## Sortie : une ligne OK / ÉCHEC par vérification, code de retour 1 si une vérification échoue.
var main
var fails := 0
var checks := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	seed(20261030)
	_run()

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("OK     " if ok else "ÉCHEC  ") + what)

func cam() -> Camera3D:
	return main.camera

func finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

func cam_sane(where: String) -> void:
	var p := cam().global_position
	check(finite(p) and finite(cam().global_rotation), where + " : caméra sans valeur invalide")
	check(root.get_viewport().get_camera_3d() == cam(), where + " : c'est bien la caméra affichée")

func _run() -> void:
	await _wait(120)
	# ---------- Propriété de la caméra ----------
	if "rig" in main and main.rig != null:
		check(main.rig.camera == cam(), "le CameraRig possède la caméra du jeu")
		check(cam().get_parent() == main.rig, "la caméra est un enfant du CameraRig")
		check(main.rig.global_transform == Transform3D.IDENTITY, "le CameraRig est à l'origine (positions inchangées)")
		main._on_orientation(true)
		check(cam().keep_aspect == Camera3D.KEEP_WIDTH, "portrait : angle de vue réglé sur la largeur")
		main._on_orientation(false)
		check(cam().keep_aspect == Camera3D.KEEP_HEIGHT, "paysage : angle de vue réglé sur la hauteur")
	else:
		print("(pas de CameraRig : version d'avant le pas A)")
	# ---------- Menu ----------
	check(main.phase == "menu", "le jeu démarre sur le menu")
	cam_sane("menu")
	check(is_equal_approx(cam().fov, 55.0), "menu : fov 55")
	# ---------- Cachette, 3e personne ----------
	main.start_hide()
	await _wait(30)
	cam_sane("cachette")
	check(is_equal_approx(cam().fov, main.HIDE_FOV), "cachette : fov de la cachette")
	var h = main.hider
	for s in ["debout", "accroupi", "couche"]:
		h.set_stance(s)
		await _wait(40)
		var target: Vector3 = h._vis + Vector3(0, h.info().cam_h, 0)
		var d := cam().global_position.distance_to(target)
		var ground: float = main.world.height_at(cam().global_position.x, cam().global_position.z)
		check(d >= 0.55 and d <= h.info().cam_d + 0.6, "cachette %s : caméra à l'épaule (%.2f m)" % [s, d])
		check(cam().global_position.y >= ground + 0.39, "cachette %s : caméra au-dessus du sol" % s)
	h.set_stance("debout")
	# Marche orientée par la caméra : « avancer » part dans la direction horizontale de la caméra.
	h.cam_yaw = 0.7
	var start: Vector3 = h.pos
	for i in 40:
		h.physics_step(1.0 / 60.0, Vector2(0, 1), false)
	var moved: Vector3 = h.pos - start
	moved.y = 0
	var cam_fwd := Vector3(-sin(0.7), 0, -cos(0.7))
	check(moved.length() > 0.5 and moved.normalized().dot(cam_fwd) > 0.98, "cachette : avancer suit la caméra (%.3f)" % moved.normalized().dot(cam_fwd))
	await _wait(10)
	# ---------- Visée à l'œil (clic droit maintenu) ----------
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	await _wait(5)
	check(cam().global_position.distance_to(h.eye()) < 0.01, "clic droit : caméra à l'œil")
	check(is_equal_approx(cam().fov, main.FIRE_FOV[0]), "clic droit : fov x1")
	check(not main.world.player.visible, "clic droit : le corps est masqué")
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	await _wait(5)
	check(main.world.player.visible and cam().global_position.distance_to(h.eye()) > 0.5, "relâché : retour à l'épaule")
	# ---------- Atelier ----------
	main.start_paint()
	await _wait(10)
	cam_sane("atelier")
	check(is_equal_approx(cam().fov, 50.0), "atelier : fov 50")
	var center := Vector2(root.get_viewport().get_visible_rect().size) / 2
	var hit: Dictionary = main.world.pick_part(main.world.player, cam().project_ray_origin(center), cam().project_ray_normal(center))
	check(not hit.is_empty(), "atelier : le centre de l'écran touche le sniper")
	var drag := InputEventMouseMotion.new()
	main.orbiting = true
	drag.relative = Vector2(0, -2000)
	main._paint_input(drag)
	check(main.ws_pitch >= -0.3 - 1e-6, "atelier : orbite limitée en bas")
	drag.relative = Vector2(300, 4000)
	main._paint_input(drag)
	check(main.ws_pitch <= 1.2 + 1e-6, "atelier : orbite limitée en haut")
	main.orbiting = false
	await _wait(3)
	cam_sane("atelier après orbite")
	# ---------- Tir ----------
	main.start_fire()
	main.reveal_t = 3.0
	await _wait(5)
	cam_sane("tir")
	check(main.phase == "fire", "tir : la révélation mène au tir")
	check(cam().global_position.distance_to(h.eye()) < 0.01, "tir : caméra à l'œil")
	var fovs := []
	for i in 4:
		fovs.append(snappedf(cam().fov, 0.01))
		main.cycle_zoom()
	check(fovs == [55.0, 14.0, 5.5, 55.0], "tir : zoom x1 → x4 → x10 → x1 %s" % [fovs])
	main._look(Vector2(1e6, 1e6))
	check(main.yaw >= main.base_yaw - 1.1 - 1e-6 and main.pitch >= -0.9 - 1e-6, "tir : regard limité (droite / bas)")
	main._look(Vector2(-2e6, -2e6))
	check(main.yaw <= main.base_yaw + 1.1 + 1e-6 and main.pitch <= 0.7 + 1e-6, "tir : regard limité (gauche / haut)")
	main.aim_at(cam().global_position, main.world.enemy.position + Vector3(0, 0.7, 0))
	await _wait(3)
	# La direction du tir est celle de la caméra : regard + balancement + recul.
	var ammo: int = main.ammo
	main.shoot()
	check(main.ammo == ammo - 1 and is_equal_approx(main.recoil, 0.012), "tir : une balle partie, recul appliqué")
	await _wait(2)
	var r: Vector3 = cam().rotation
	check(absf(r.z) < 1e-6 and absf(r.x - main.pitch) < 0.05 and absf(r.y - main.yaw) < 0.05, "tir : caméra = regard + petits effets (balancement, recul)")
	await _wait(60)
	check(absf(main.recoil) < 0.001, "tir : le recul retombe")
	# ---------- Fin et retour au menu ----------
	main.win()
	await _wait(30)
	cam_sane("fin")
	main.to_menu()
	await _wait(5)
	cam_sane("retour au menu")
	check(main.phase == "menu", "retour au menu")
	print("%d vérifications, %d échec(s)" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _wait(n: int) -> void:
	for i in n:
		await process_frame
