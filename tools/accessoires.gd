extends SceneTree
## Outil : sort les accessoires de la scène Higgsfield « Sniper Arena » (sources/arena_higgsfield.glb, faite par
## l'utilisateur avec 3D Jutsu) et les range dans game/art/accessoires/ : un maillage par accessoire, une surface par
## matière (nom de la surface = nom de la matière d'origine ; world.gd y pose les matières du jeu).
##
##   godot --headless --path game -s ../tools/accessoires.gd -- ../sources/arena_higgsfield.glb

# accessoire → débuts des noms d'objets qui le composent (on prend les exemplaires du côté est).
const GROUPS := {
	"sacs": ["COVER_EAST_sandbag"],
	"sacs_petit": ["COVER_E_sandbag", "COVER_E_sandbag_001", "COVER_E_sandbag_002", "COVER_E_sandbag_003", "COVER_E_sandbag_004", "COVER_E_sandbag_005"],
	"tour": ["POS_EAST_"],
	"caisse": ["PROP_EAST_ammo_crate", "PROP_EAST_crate_slats"],
	"fut": ["PROP_EAST_drum"],
	"rondin": ["COVER_fallen_log_00"],
}
const EXACT := ["sacs_petit", "rondin"]   # noms exacts (pas des débuts)

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(OS.get_cmdline_user_args()[0], st)
	var scene: Node3D = doc.generate_scene(st)
	root.add_child(scene)
	await process_frame
	var all := scene.find_children("*", "MeshInstance3D", true, false)
	for g in GROUPS:
		var parts: Array = []
		for n in all:
			var mi := n as MeshInstance3D
			for p in GROUPS[g]:
				if (g in EXACT and mi.name == p) or (not g in EXACT and String(mi.name).begins_with(p)):
					parts.append(mi)
					break
		# Repère de l'accessoire : centre du pied.
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for mi in parts:
			var xf: Transform3D = (mi as MeshInstance3D).global_transform
			var a := (mi as MeshInstance3D).get_aabb()
			for i in 8:
				var c := xf * a.get_endpoint(i)
				lo = lo.min(c)
				hi = hi.max(c)
		var anchor := Vector3((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2)
		var by_mat := {}
		for mi in parts:
			var m: MeshInstance3D = mi
			for s in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(s)
				var key := mat.resource_name if mat else "defaut"
				if not by_mat.has(key):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					by_mat[key] = tool
				var shifted := Transform3D(Basis.IDENTITY, -anchor) * m.global_transform
				(by_mat[key] as SurfaceTool).append_from(m.mesh, s, shifted)
		var mesh := ArrayMesh.new()
		for key in by_mat:
			var tool: SurfaceTool = by_mat[key]
			tool.generate_normals()
			tool.commit(mesh)
			mesh.surface_set_name(mesh.get_surface_count() - 1, key)
		ResourceSaver.save(mesh, "res://art/accessoires/%s.res" % g)
		print(g, " : ", parts.size(), " objets, taille ", (hi - lo).snapped(Vector3.ONE * 0.01), ", matières ", by_mat.keys())
	quit()
