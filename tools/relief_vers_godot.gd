extends SceneTree
## Outil : range le relief fabriqué par tools/relief.py dans game/data/ (format lu par world.gd).
##
##   python3 tools/relief.py relief.bin
##   godot --headless --path game -s ../tools/relief_vers_godot.gd -- relief.bin

const SEG := 320

func _initialize() -> void:
	var w := SEG + 1
	var bytes := FileAccess.get_file_as_bytes(OS.get_cmdline_user_args()[0])
	if bytes.size() != w * w * 5:
		push_error("Taille inattendue : %d" % bytes.size())
		quit(1)
		return
	var heights := bytes.slice(0, w * w * 4)
	var zones := bytes.slice(w * w * 4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	ResourceSaver.save(Image.create_from_data(w, w, false, Image.FORMAT_RF, heights), "res://data/relief_%d_hauteurs.res" % SEG)
	ResourceSaver.save(Image.create_from_data(w, w, false, Image.FORMAT_R8, zones), "res://data/relief_%d_zones.res" % SEG)
	print("relief rangé dans data/")
	quit()
