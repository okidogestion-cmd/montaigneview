extends SceneTree
## Outil (à lancer une fois) : prépare le bouquetin pour le jeu, game/art/bouquetin.res (+ bouquetin.jpg).
##
##   godot --headless --path game -s ../tools/faune.gd
##
## Entrée : sources/bouquetin_higgsfield.glb — modèle Meshy créé avec Higgsfield (30/10/2026), allégé avec gltf-transform
## (soudure, simplification à ≈ 3 900 triangles, texture 512 px) : 254 Ko au lieu de 4,3 Mo.
## Le modèle n'a pas de squelette : il est remis droit (corps le long de +z, tête vers +z), à taille réelle,
## sabots à y = 0. Les pattes et le cou sont animés par le shader (shaders/animal.gdshader) ; l'outil affiche
## les repères à recopier dans world.gd (haut des pattes, base du cou).

const HEIGHT := 1.45   # m, du sabot au haut des cornes (≈ 0,9 m au garrot)

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path("res://").path_join("../sources/bouquetin_higgsfield.glb"), st)
	var sc: Node3D = doc.generate_scene(st)
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var lo := INF
	var hi := -INF
	for p in v:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	# Axe du corps : on relie les sabots arrière à la tête (le plus haut des points avant).
	var mid := lo + (hi - lo) * 0.5
	var feet := []
	var c := Vector2.ZERO
	var cc := 0
	for p in v:
		if p.y < lo + (hi - lo) * 0.08:
			feet.append(Vector2(p.x, p.z))
			c += Vector2(p.x, p.z)
			cc += 1
	c /= cc
	# Analyse en composantes principales des sabots : l'axe le plus long va de l'avant à l'arrière.
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	for f in feet:
		var d: Vector2 = f - c
		sxx += d.x * d.x
		szz += d.y * d.y
		sxz += d.x * d.y
	var ang := 0.5 * atan2(2.0 * sxz, sxx - szz)   # angle de l'axe principal depuis +x
	var axis := Vector2(cos(ang), sin(ang))
	# Sens : la tête (points hauts) est vers l'avant.
	var head := Vector2.ZERO
	var hn := 0
	for p in v:
		if p.y > mid:
			head += Vector2(p.x, p.z)
			hn += 1
	head /= hn
	if (head - c).dot(axis) < 0.0:
		axis = -axis
	# Rotation autour de y qui envoie axis sur +z.
	var yaw := atan2(axis.x, axis.y)
	var k := HEIGHT / (hi - lo)
	var xf := Transform3D(Basis(Vector3.UP, -yaw).scaled(Vector3.ONE * k), Vector3.ZERO)
	var out := PackedVector3Array()
	var on := PackedVector3Array()
	var ctr := xf * Vector3(c.x, lo, c.y)
	for i in v.size():
		out.append(xf * v[i] - ctr)
		on.append((xf.basis * nrm[i]).normalized())
	a[Mesh.ARRAY_VERTEX] = out
	a[Mesh.ARRAY_NORMAL] = on
	a[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	ResourceSaver.save(mesh, "res://art/bouquetin.res")
	var tex: Texture2D = (mi.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture
	var img := tex.get_image()
	img.decompress()
	img.save_jpg("res://art/bouquetin.jpg", 0.85)
	# Repères : tranches de hauteur (étendue avant-arrière), pour placer le haut des pattes et la base du cou.
	var y := 0.0
	while y < HEIGHT:
		var zmin := INF
		var zmax := -INF
		var xmin := INF
		var xmax := -INF
		for p in out:
			if p.y >= y and p.y < y + 0.05:
				zmin = minf(zmin, p.z); zmax = maxf(zmax, p.z); xmin = minf(xmin, p.x); xmax = maxf(xmax, p.x)
		print("y %.2f : z %.2f .. %.2f   x %.2f .. %.2f" % [y, zmin, zmax, xmin, xmax])
		y += 0.05
	print("bouquetin.res : ", out.size(), " sommets, angle corrigé ", rad_to_deg(yaw), "°")
	quit()
