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
	check("rig" in main and main.rig != null, "le CameraRig existe")
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
	var rig = main.rig
	check(rig.mode == rig.Mode.MENU, "menu : la caméra est pilotée par le CameraRig")
	check(cam().global_position.is_equal_approx(Vector3(330, 110, 40)), "menu : caméra au-dessus de la vallée")
	# Elle regarde le centre de la vallée et balaie lentement (±0,18 rad, période 2π × 9 s).
	var to_valley := (Vector3(0, 55, 0) - cam().global_position).normalized()
	var yaws := []
	for i in 6:
		await _wait(60)
		yaws.append(cam().rotation.y)
		check(-cam().global_transform.basis.z.dot(to_valley) > 0.98, "menu : regarde la vallée (%.3f)" % -cam().global_transform.basis.z.dot(to_valley))
	check(absf(yaws[5] - yaws[0]) > 0.02 and absf(yaws[5] - yaws[0]) < 0.37, "menu : balayage lent (%.3f rad en 5 s)" % (yaws[5] - yaws[0]))
	# ---------- Cachette, 3e personne ----------
	main.start_hide()
	await _wait(30)
	cam_sane("cachette")
	check(rig.mode == rig.Mode.EXTERNAL, "cachette : la caméra reste placée par hider.gd (pas encore migrée)")
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
	check(rig.mode == rig.Mode.WORKSHOP, "atelier : la caméra est pilotée par le CameraRig")
	var c0: Vector3 = main._workshop_center()
	check(absf(cam().global_position.distance_to(c0) - 3.2) < 0.001, "atelier : à 3,2 m du sniper")
	check(-cam().global_transform.basis.z.dot((c0 - cam().global_position).normalized()) > 0.9999, "atelier : regarde le sniper")
	# Souris : clic gauche maintenu pour tourner, relâché ne tourne plus.
	var yaw0: float = rig.orbit_yaw
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	_mouse_motion(Vector2(0, -2000))
	check(rig.orbit_pitch >= -0.3 - 1e-6, "atelier : orbite limitée en bas")
	_mouse_motion(Vector2(300, 4000))
	check(rig.orbit_pitch <= 1.2 + 1e-6, "atelier : orbite limitée en haut")
	check(absf(rig.orbit_yaw - (yaw0 - 300 * 0.008)) < 1e-6, "atelier : glisser à la souris tourne autour du sniper")
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	var yaw1: float = rig.orbit_yaw
	_mouse_motion(Vector2(300, 0))
	check(rig.orbit_yaw == yaw1, "atelier : bouton relâché, la caméra ne tourne plus")
	# Molette : 1,4 à 6 m.
	for i in 30:
		_mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	check(is_equal_approx(rig.orbit_dist, 1.4), "atelier : molette, au plus près 1,4 m")
	for i in 30:
		_mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true)
	check(is_equal_approx(rig.orbit_dist, 6.0), "atelier : molette, au plus loin 6 m")
	# Doigts : glisser à un doigt tourne, pincer à deux rapproche.
	var mid := Vector2(root.get_viewport().get_visible_rect().size) * Vector2(0.55, 0.5)
	_touch(0, mid, true)
	var yaw2: float = rig.orbit_yaw
	_drag(0, mid + Vector2(50, 0))
	check(absf(rig.orbit_yaw - (yaw2 - 50 * 0.008)) < 1e-6, "atelier : glisser au doigt tourne autour du sniper")
	_touch(1, mid + Vector2(200, 0), true)
	_drag(1, mid + Vector2(300, 0))
	_drag(1, mid + Vector2(600, 0))
	check(rig.orbit_dist < 6.0 and rig.orbit_dist >= 1.4, "atelier : pincer rapproche (%.2f m)" % rig.orbit_dist)
	_touch(1, mid, false)
	_touch(0, mid, false)
	await _wait(3)
	cam_sane("atelier après orbite")
	check(absf(cam().global_position.distance_to(c0) - rig.orbit_dist) < 0.001, "atelier : la caméra suit la distance de l'orbite")
	main._on_paint_pose("couche")
	await _wait(2)
	var c1: Vector3 = main._workshop_center()
	check(c1.y < c0.y and -cam().global_transform.basis.z.dot((c1 - cam().global_position).normalized()) > 0.9999, "atelier : couché, la caméra vise plus bas")
	main._on_paint_pose("debout")
	# ---------- Tir ----------
	main.start_fire()
	main.reveal_t = 3.0
	await _wait(5)
	cam_sane("tir")
	check(main.phase == "fire", "tir : la révélation mène au tir")
	check(rig.mode == rig.Mode.EXTERNAL, "tir : la caméra reste placée par main.gd (pas encore migrée)")
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
	check(rig.mode == rig.Mode.MENU and cam().global_position.is_equal_approx(Vector3(330, 110, 40)), "retour au menu : vue de la vallée")
	print("%d vérifications, %d échec(s)" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _mouse_button(button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	main._paint_input(e)

func _mouse_motion(rel: Vector2) -> void:
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
