extends SceneTree
## Test des réglages de sensibilité (souris / tactile), sans écran :
##   godot --headless --path game --fixed-fps 60 -s ../tools/tests/test_reglages.gd
## Vérifie le menu, les bornes, l'effet sur le regard à la lunette et la sauvegarde.
var main
var fails := 0

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reglages.cfg"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK     " if ok else "ÉCHEC  ") + what)

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await _wait(30)
	var hud = main.hud
	check(hud.settings != null and not hud.settings.visible, "le panneau Réglages existe et est caché au départ")
	check(is_equal_approx(main.sens.souris, 1.0) and is_equal_approx(main.sens.tactile, 2.0), "valeurs par défaut : souris ×1, tactile ×2")
	# Pas + / − et bornes
	hud._step_sens("tactile", hud.SENS_STEP)
	check(is_equal_approx(main.sens.tactile, 2.25), "+ augmente la sensibilité tactile d'un pas (%.2f)" % main.sens.tactile)
	for i in 40:
		hud._step_sens("souris", hud.SENS_STEP)
	check(is_equal_approx(main.sens.souris, hud.SENS_MAX), "la sensibilité souris est bornée en haut (%.2f)" % main.sens.souris)
	for i in 60:
		hud._step_sens("souris", -hud.SENS_STEP)
	check(is_equal_approx(main.sens.souris, hud.SENS_MIN), "la sensibilité souris est bornée en bas (%.2f)" % main.sens.souris)
	hud._step_sens("souris", hud.SENS_STEP * 3)   # 1,0
	check(is_equal_approx(main.sens.souris, 1.0), "retour à ×1,00")
	check((hud._sens_labels["tactile"] as Label).text == "× 2.25", "le texte affiche la valeur (%s)" % (hud._sens_labels["tactile"] as Label).text)
	# Effet à la lunette : un même glissement tourne deux fois plus avec ×2 qu'avec ×1
	main.start_hide()
	await _wait(5)
	main.start_fire()
	await _wait(5)
	var rig = main.rig
	var y0: float = rig.scope_yaw
	main._look(Vector2(100, 0) * 1.0)
	var d1: float = absf(rig.scope_yaw - y0)
	rig.scope_yaw = y0
	main._look(Vector2(100, 0) * 2.0)
	var d2: float = absf(rig.scope_yaw - y0)
	check(d1 > 0.0 and is_equal_approx(d2, d1 * 2.0), "à la lunette, ×2 tourne deux fois plus que ×1 (%.4f → %.4f rad)" % [d1, d2])
	# Sauvegarde
	var cf := ConfigFile.new()
	check(cf.load("user://reglages.cfg") == OK and is_equal_approx(float(cf.get_value("sensibilite", "tactile", 0.0)), 2.25), "les réglages sont enregistrés")
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
