extends RefCounted
## Petite végétation en cartes texturées : touffes d'herbe et de fleurs (matériaux posés par world.gd).
## Les arbres et buissons sont les modèles photo de art/arbres/ (world.gd → PACK_TREES).

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
