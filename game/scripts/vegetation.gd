extends RefCounted
## Végétation façon jeux PS3 : arbres et buissons faits de cartes texturées (aiguilles, feuilles)
## autour d'un tronc d'écorce. Les normales des cartes pointent hors de la couronne (« en boule »)
## pour un éclairage doux, et la couleur de sommet assombrit le cœur et le bas (occlusion).
## Chaque maillage a deux surfaces : 0 écorce, 1 feuillage (matériaux posés par world.gd).

class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	func vert(p: Vector3, nrm: Vector3, t: Vector2, shade: float) -> int:
		v.append(p)
		n.append(nrm)
		uv.append(t)
		c.append(Color(shade, shade, shade))
		return v.size() - 1

	func quad(a: int, b: int, c2: int, d: int) -> void:
		idx.append_array([a, b, c2, a, c2, d])

	func add_to(mesh: ArrayMesh) -> void:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Tronc conique, écorce répétée verticalement.
static func _trunk(s: Surf, base: Vector3, top: Vector3, r0: float, r1: float, segs: int) -> void:
	var axis := (top - base)
	var up := axis.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := up.cross(side)
	var length_m := axis.length()
	var first := s.v.size()
	for i in segs + 1:
		var a := TAU * i / segs
		var dir := side * cos(a) + fwd * sin(a)
		s.vert(base + dir * r0, dir, Vector2(float(i) / segs * 2.0, 0.0), 0.55)
		s.vert(top + dir * r1, dir, Vector2(float(i) / segs * 2.0, -length_m / 2.0), 1.0)
	for i in segs:
		var k := first + i * 2
		s.quad(k, k + 1, k + 3, k + 2)


## Épicéa (≈ 8,5 m) : un tronc et des étages de branches qui retombent, plus petits vers la pointe.
static func spruce(seed: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var H := 8.5
	var bark := Surf.new()
	var leaf := Surf.new()
	_trunk(bark, Vector3.ZERO, Vector3(0, H, 0), 0.3, 0.04, 7)
	var crown := Vector3(0, H * 0.42, 0)
	var whorls := 13
	for k in whorls:
		var t := float(k) / (whorls - 1)
		var y := 1.2 + t * (H - 1.5) + r.randf_range(-0.12, 0.12)
		var L := lerpf(2.7, 0.5, pow(t, 0.85)) * r.randf_range(0.9, 1.1)
		var count := 6 if t < 0.55 else (5 if t < 0.85 else 4)
		var phase := r.randf() * TAU
		for j in count:
			var a := phase + TAU * j / count + r.randf_range(-0.25, 0.25)
			var dir := Vector3(cos(a), 0, sin(a))
			var droop := -0.32 - t * 0.12 + r.randf_range(-0.08, 0.08)
			var root := Vector3(0, y, 0) + dir * 0.08
			var tip := root + (dir * cos(droop) + Vector3.UP * sin(droop)) * L
			var flat := Vector3(-dir.z, 0, dir.x) * L * 0.27
			# Deux cartes par branche, inclinées en V autour de l'axe : la branche a du volume vu de près.
			for tilt in [0.45, -0.45]:
				var side := flat.rotated(dir, tilt)
				var pts := [root - side * 0.35, root + side * 0.35, tip + side, tip - side]
				var uvs := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
				var ids := []
				for q in 4:
					var p: Vector3 = pts[q]
					var nrm := (p - crown).normalized().lerp(Vector3.UP, 0.35).normalized()
					var shade := lerpf(0.55, 1.0, t) * (0.72 if q < 2 else 1.0)
					ids.append(leaf.vert(p, nrm, uvs[q], shade))
				leaf.quad(ids[0], ids[1], ids[2], ids[3])
	# Pointe : deux cartes croisées verticales.
	for a in [0.0, PI / 2]:
		var dir := Vector3(cos(a), 0, sin(a)) * 0.35
		var y0 := H - 1.4
		var ids := []
		for q in 4:
			var p: Vector3 = [Vector3(0, y0, 0) - dir, Vector3(0, y0, 0) + dir, Vector3(0, H + 0.3, 0) + dir * 0.3, Vector3(0, H + 0.3, 0) - dir * 0.3][q]
			ids.append(leaf.vert(p, (p - crown).normalized(), [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)][q], 1.0))
		leaf.quad(ids[0], ids[1], ids[2], ids[3])
	var mesh := ArrayMesh.new()
	bark.add_to(mesh)
	leaf.add_to(mesh)
	return mesh


## Bouquets de feuilles répartis dans un volume (couronne d'arbre ou buisson).
static func _leaf_cloud(s: Surf, r: RandomNumberGenerator, center: Vector3, radii: Vector3, count: int, size: Vector2) -> void:
	for i in count:
		var dir := Vector3(r.randfn(), r.randfn() * 0.8, r.randfn()).normalized()
		var p := center + dir * radii * r.randf_range(0.45, 1.0)
		var outward := (p - center).normalized()
		var u := outward.cross(Vector3.UP if absf(outward.y) < 0.95 else Vector3.RIGHT).normalized()
		u = u.rotated(outward, r.randf() * TAU)
		var w := outward.cross(u)
		var sz := r.randf_range(size.x, size.y) / 2.0
		var ids := []
		var corners := [-u - w, u - w, u + w, -u + w]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for q in 4:
			var cp: Vector3 = p + corners[q] * sz
			var nrm := (cp - center).normalized().lerp(Vector3.UP, 0.25).normalized()
			var depth := clampf((cp - center).length() / radii.length() * 1.6, 0.0, 1.0)
			var shade := lerpf(0.5, 1.0, depth) * lerpf(0.75, 1.0, clampf((cp.y - center.y + radii.y) / (2.0 * radii.y), 0.0, 1.0))
			ids.append(s.vert(cp, nrm, uvs[q], shade))
		s.quad(ids[0], ids[1], ids[2], ids[3])


## Feuillu (≈ 6 m) : tronc, trois grosses branches et une couronne de bouquets de feuilles.
static func broadleaf(seed: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var bark := Surf.new()
	var leaf := Surf.new()
	_trunk(bark, Vector3.ZERO, Vector3(0, 3.2, 0), 0.32, 0.2, 7)
	for i in 3:
		var a := TAU * i / 3.0 + r.randf()
		_trunk(bark, Vector3(0, 2.9, 0), Vector3(cos(a) * 1.3, 4.8, sin(a) * 1.3), 0.17, 0.06, 5)
	_leaf_cloud(leaf, r, Vector3(0, 5.0, 0), Vector3(2.5, 1.9, 2.5), 46, Vector2(1.6, 2.4))
	var mesh := ArrayMesh.new()
	bark.add_to(mesh)
	leaf.add_to(mesh)
	return mesh


## Buisson (≈ 1,6 m) : seulement des feuilles, posé au sol.
static func bush(seed: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var bark := Surf.new()
	var leaf := Surf.new()
	_trunk(bark, Vector3.ZERO, Vector3(0, 0.5, 0), 0.08, 0.05, 4)
	_leaf_cloud(leaf, r, Vector3(0, 0.75, 0), Vector3(1.35, 0.85, 1.35), 22, Vector2(1.0, 1.5))
	var mesh := ArrayMesh.new()
	bark.add_to(mesh)
	leaf.add_to(mesh)
	return mesh


## Touffe d'herbe (ou de fleurs) : trois cartes verticales croisées, la texture debout.
static func tuft(width: float, height: float) -> ArrayMesh:
	var s := Surf.new()
	for i in 3:
		var a := PI * i / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * width / 2.0
		var ids := []
		var pts := [-d, d, d + Vector3(0, height, 0), -d + Vector3(0, height, 0)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for q in 4:
			ids.append(s.vert(pts[q], Vector3.UP, uvs[q], 0.75 if q < 2 else 1.0))
		s.quad(ids[0], ids[1], ids[2], ids[3])
	var mesh := ArrayMesh.new()
	s.add_to(mesh)
	return mesh
