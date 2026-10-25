extends Node3D
## La vallée : relief, zones de couleur, cachettes, décor et personnages.
## Repris du prototype web « Duel des Cimes », habillé façon Wind Waker
## (ombrage cartoon, contours, herbe qui bouge, fleurs, lac).

const ZONE_KEYS: Array[String] = ["neige", "roche", "herbe", "foret"]
const ZONES := {
	"neige": {"label": "Neige", "color": Color("#eef3f9")},
	"roche": {"label": "Roche", "color": Color("#928e86")},
	"herbe": {"label": "Herbe", "color": Color("#6fae44")},
	"foret": {"label": "Forêt", "color": Color("#3b7a3c")},
}
const MZ := 230.0          # centre des deux montagnes sur l'axe z (+ joueur, - ennemi)
const S := 1400.0          # taille de la vallée
const SEG := 320           # finesse du relief (4,4 m entre deux points)
const CELL := S / SEG
const WATER_Y := 26.0      # niveau de la mer : le fond de la vallée est sous l'eau, les montagnes sont des îles
const PEAKS := [
	[0, -MZ, 130, 190], [0, MZ, 130, 190], [-270, -340, 95, 150], [290, -360, 110, 160],
	[-300, 310, 90, 150], [310, 330, 85, 140], [0, -580, 160, 230], [0, 580, 150, 230],
	[-560, 0, 120, 200], [560, 0, 120, 200],
]
const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const WATER := preload("res://shaders/water.gdshader")
const GRASS := preload("res://shaders/grass.gdshader")
const GRASS_RADIUS := 55.0

var heights := PackedFloat32Array()
var rng := RandomNumberGenerator.new()
var enemy_spots: Array = []
var player_spots: Array = []
var player: Node3D
var enemy: Node3D
var enemy_hitbox: StaticBody3D
var flash_sprite: Sprite3D
var end_marker: Sprite3D
var _materials := {}
var _grass_mask := PackedByteArray()
var _grass_fields: Array[MultiMeshInstance3D] = []
var _outline: ShaderMaterial
var _rock_mesh: Mesh
var _bush_mesh: Mesh
var _pine_mesh: Mesh
var _round_tree_mesh: Mesh
var _log_mesh: Mesh


# ---------- Bruit et relief ----------
static func hash2(x: float, z: float) -> float:
	var n := sin(x * 127.1 + z * 311.7) * 43758.5453
	return n - floor(n)

static func vnoise(x: float, z: float) -> float:
	var xi := floorf(x)
	var zi := floorf(z)
	var xf := x - xi
	var zf := z - zi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := zf * zf * (3.0 - 2.0 * zf)
	var a := hash2(xi, zi)
	var b := hash2(xi + 1, zi)
	var c := hash2(xi, zi + 1)
	var d := hash2(xi + 1, zi + 1)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v

static var _noise: FastNoiseLite

static func fbm(x: float, z: float) -> float:
	# Bruit fractal (4 octaves) calculé par le moteur : bien plus rapide qu'en script.
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		_noise.seed = 20261025
		_noise.frequency = 1.0
		_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_noise.fractal_octaves = 4
		_noise.fractal_lacunarity = 2.03
		_noise.fractal_gain = 0.5
	return _noise.get_noise_2d(x, z) * 0.47

static func height_fn(x: float, z: float) -> float:
	var h := 0.0
	for p in PEAKS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var r: float = p[3]
		h += p[2] * exp(-1.6 * (dx * dx * 0.7 + dz * dz) / (r * r))
	h += fbm(x * 0.012, z * 0.012) * 38.0 + fbm(x * 0.05, z * 0.05) * 6.0
	# Au bord de la carte, le sol plonge : la mer s'étend jusqu'à l'horizon.
	var edge := maxf(absf(x), absf(z))
	h = lerpf(h, -60.0, smoothstep(540.0, 690.0, edge))
	return h

static func zone_at(x: float, z: float, h: float) -> String:
	var n := fbm(x * 0.025 + 11.0, z * 0.025 - 7.0)
	if h > 108.0 + n * 28.0:
		return "neige"
	if h > 74.0 + n * 30.0:
		return "roche"
	if fbm(x * 0.018 - 40.0, z * 0.018 + 90.0) > 0.06:
		return "foret"
	return "herbe"

func height_at(x: float, z: float) -> float:
	var fc := clampf((x + S / 2) / CELL, 0, SEG - 0.001)
	var fr := clampf((z + S / 2) / CELL, 0, SEG - 0.001)
	var c := int(fc)
	var r := int(fr)
	var u := fc - c
	var v := fr - r
	var w := SEG + 1
	var a := heights[r * w + c]
	var b := heights[r * w + c + 1]
	var d := heights[(r + 1) * w + c]
	var e := heights[(r + 1) * w + c + 1]
	# Même découpage en triangles que le maillage affiché.
	if u + v <= 1.0:
		return a + (b - a) * u + (d - a) * v
	return e + (d - e) * (1.0 - u) + (b - e) * (1.0 - v)


# ---------- Matériaux ----------
func toon(color := Color.WHITE, vertex_colors := false, outline := false, wind := 0.0, wind_height := 7.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s" % [color.to_html(), vertex_colors, outline, wind, wind_height]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("albedo", color)
		m.set_shader_parameter("use_vertex_color", vertex_colors)
		m.set_shader_parameter("wind", wind)
		m.set_shader_parameter("wind_height", wind_height)
		if outline:
			m.next_pass = _outline
		_materials[key] = m
	return _materials[key]

func mat(color: Color) -> ShaderMaterial:
	return toon(color)


# ---------- Formes (assemblées en un seul maillage coloré) ----------
func _sphere(radius: float, segs: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2
	m.radial_segments = segs
	m.rings = rings
	return m

func _cyl(top: float, bottom: float, height: float, segs: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segs
	m.rings = 1
	return m

func _merge(parts: Array, flat := false) -> ArrayMesh:
	# parts : [[forme, Transform3D, Color], ...]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in parts:
		var a: Array = (p[0] as PrimitiveMesh).get_mesh_arrays()
		var t: Transform3D = p[1]
		var nb := t.basis.inverse().transposed()
		var off := verts.size()
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in v.size():
			verts.append(t * v[i])
			norms.append((nb * n[i]).normalized())
			cols.append(p[2])
		for i in (a[Mesh.ARRAY_INDEX] as PackedInt32Array):
			idx.append(i + off)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not flat:
		return mesh
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()

func _at(pos: Vector3, scl := Vector3.ONE, rot_y := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scl), pos)

func _build_meshes() -> void:
	# Rocher : sphère bosselée à facettes.
	var rock := _sphere(1.0, 7, 4)
	var ra := rock.get_mesh_arrays()
	var rv: PackedVector3Array = ra[Mesh.ARRAY_VERTEX]
	for i in rv.size():
		var p := rv[i]
		rv[i] = p * (0.82 + hash2(p.x * 3.1 + p.y * 1.7, p.z * 2.3 - p.y) * 0.36)
	ra[Mesh.ARRAY_VERTEX] = rv
	var rmesh := ArrayMesh.new()
	rmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ra)
	var st := SurfaceTool.new()
	st.create_from(rmesh, 0)
	st.deindex()
	st.generate_normals()
	_rock_mesh = st.commit()
	# Buisson : trois boules.
	var leaf := Color("#5fae3e")
	var leaf2 := Color("#4f9a37")
	_bush_mesh = _merge([
		[_sphere(1.0, 8, 5), _at(Vector3(0, 0.6, 0)), leaf],
		[_sphere(0.7, 8, 5), _at(Vector3(0.9, 0.45, 0.2)), leaf2],
		[_sphere(0.75, 8, 5), _at(Vector3(-0.7, 0.5, -0.3)), leaf2],
	])
	# Sapin : tronc et trois étages.
	var bark := Color("#7a5233")
	_pine_mesh = _merge([
		[_cyl(0.22, 0.3, 1.8, 6), _at(Vector3(0, 0.9, 0)), bark],
		[_cyl(0.0, 1.9, 3.0, 8), _at(Vector3(0, 2.7, 0)), Color("#2f6e3b")],
		[_cyl(0.0, 1.45, 2.6, 8), _at(Vector3(0, 4.1, 0)), Color("#367a41")],
		[_cyl(0.0, 0.95, 2.1, 8), _at(Vector3(0, 5.6, 0)), Color("#3f8749")],
	])
	# Arbre rond (feuillu, comme dans Wind Waker).
	# Bois flotté : un tronc couché, avec une branche cassée.
	_log_mesh = _merge([
		[_cyl(0.16, 0.2, 2.6, 7), Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, 0.1, 0)), Color("#b9a58a")],
		[_cyl(0.05, 0.08, 0.7, 5), Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3(0.5, 0.35, 0)), Color("#a8937a")],
	])
	_round_tree_mesh = _merge([
		[_cyl(0.24, 0.34, 2.6, 6), _at(Vector3(0, 1.3, 0)), bark],
		[_sphere(1.9, 10, 6), _at(Vector3(0, 3.7, 0)), Color("#62b240")],
		[_sphere(1.3, 10, 6), _at(Vector3(1.1, 3.2, 0.4)), Color("#56a339")],
		[_sphere(1.4, 10, 6), _at(Vector3(-0.9, 3.3, -0.5)), Color("#56a339")],
		[_sphere(1.1, 10, 6), _at(Vector3(0.2, 4.9, 0.3)), Color("#6dbf48")],
	])


# ---------- Construction ----------
func build() -> void:
	rng.seed = 20261025
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE
	_build_meshes()
	_build_terrain()
	_build_water()
	enemy_spots = _build_spots(-MZ, 1)
	player_spots = _build_spots(MZ, -1)
	_scatter()
	_grass()
	player = _make_figure(["debout", "accroupi", "couche"])
	add_child(player)
	player.visible = false
	enemy = _make_figure()
	add_child(enemy)
	enemy.visible = false
	enemy_hitbox = StaticBody3D.new()
	var hs := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(1, 1.4, 1.2)
	hs.shape = hb
	enemy_hitbox.add_child(hs)
	enemy_hitbox.position.y = 0.7
	enemy.add_child(enemy_hitbox)
	_build_sprites()

func _build_terrain() -> void:
	var w := SEG + 1
	heights.resize(w * w)
	for r in w:
		for c in w:
			heights[r * w + c] = height_fn(-S / 2 + c * CELL, -S / 2 + r * CELL)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(w * w)
	normals.resize(w * w)
	colors.resize(w * w)
	var sand := Color("#e3d39a")
	_grass_mask.resize(w * w * 4)
	for r in w:
		for c in w:
			var x := -S / 2 + c * CELL
			var z := -S / 2 + r * CELL
			var h := heights[r * w + c]
			verts[r * w + c] = Vector3(x, h, z)
			var hl := heights[r * w + maxi(c - 1, 0)]
			var hr := heights[r * w + mini(c + 1, SEG)]
			var hu := heights[maxi(r - 1, 0) * w + c]
			var hd := heights[mini(r + 1, SEG) * w + c]
			var n := Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
			normals[r * w + c] = n
			var zone := zone_at(x, z, h)
			var col: Color = ZONES[zone]["color"]
			var gi := (r * w + c) * 4
			_grass_mask[gi] = {"herbe": 255, "foret": 120}.get(zone, 0)
			_grass_mask[gi + 2] = {"roche": 255, "neige": 40}.get(zone, 0)
			_grass_mask[gi + 3] = 255 if zone == "neige" else 0
			_grass_mask[gi + 1] = 255 if zone == "herbe" else 0
			if h < WATER_Y + 2.5:
				col = sand  # plage autour du lac
			var k := 0.94 + hash2(x * 0.3, z * 0.3) * 0.12
			if n.y < 0.8:
				k *= 0.86  # pentes raides un peu plus sombres : falaises
			colors[r * w + c] = Color(col.r * k, col.g * k, col.b * k)
	for r in SEG:
		for c in SEG:
			var a := r * w + c
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("patches", 0.24)
	m.set_shader_parameter("rim_strength", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var m := ShaderMaterial.new()
	m.shader = WATER
	m.set_shader_parameter("heightmap", ImageTexture.create_from_image(Image.create_from_data(SEG + 1, SEG + 1, false, Image.FORMAT_RF, heights.to_byte_array())))
	m.set_shader_parameter("cell", CELL)
	m.set_shader_parameter("grid", float(SEG + 1))
	m.set_shader_parameter("half_size", S / 2)
	m.set_shader_parameter("water_y", WATER_Y)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.position.y = WATER_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------- Cachettes ----------
func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)

func _box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)

func _make_cover(zone: String) -> Node3D:
	var g := Node3D.new()
	var body := StaticBody3D.new()
	g.add_child(body)
	match zone:
		"neige", "roche":
			var col := Color("#e3eaf2") if zone == "neige" else Color("#86837c")
			_part(g, _rock_mesh, toon(col, false, true), Vector3(0, 0.35, 0), Vector3(1.8, 1, 1.5))
			_box(body, Vector3(0, 0.35, 0), Vector3(3.2, 1.8, 2.7))
		"herbe":
			_part(g, _bush_mesh, toon(Color.WHITE, true, true, 0.05, 1.5), Vector3.ZERO, Vector3(1.4, 1, 1.3))
			_box(body, Vector3(0.2, 0.6, 0), Vector3(3.2, 1.8, 2.6))
		_:
			_part(g, _pine_mesh, toon(Color.WHITE, true, true, 0.12), Vector3(-1.6, 0, -0.6), Vector3(1, 1.1, 1))
			_part(g, _bush_mesh, toon(Color("#c8d8c0"), true, true, 0.05, 1.5), Vector3.ZERO, Vector3(1.3, 0.95, 1.2))
			_box(body, Vector3(0, 0.6, 0), Vector3(2.8, 1.8, 2.4))
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 1.0
			cyl.height = 7.7
			cs.shape = cyl
			cs.position = Vector3(-1.6, 3.85, -0.6)
			body.add_child(cs)
	g.set_meta("body", body)
	return g

func _build_spots(cz: float, facing: int) -> Array:
	var list := []
	for a in [-52, -26, 0, 26, 52]:
		for rad in [64, 102, 140]:
			var ang := deg_to_rad(a + (rng.randf() - 0.5) * 10)
			var rr: float = rad + (rng.randf() - 0.5) * 16
			var x := sin(ang) * rr * 1.18
			var z := cz + facing * cos(ang) * rr
			var h := height_at(x, z)
			while h < WATER_Y + 4.0 and rr > 40.0:
				# Trop près de la mer : on remonte vers le sommet.
				rr -= 8.0
				x = sin(ang) * rr * 1.18
				z = cz + facing * cos(ang) * rr
				h = height_at(x, z)
			var zone := zone_at(x, z, h)
			var cover := _make_cover(zone)
			cover.position = Vector3(x, h, z)
			if facing < 0:
				cover.rotation.y = PI
			add_child(cover)
			var side := (-1.0 if rng.randf() < 0.5 else 1.0) * 0.7
			var fx := x + side
			var fz := z - facing * 1.9
			list.append({
				"x": x, "z": z, "zone": zone, "cover": cover, "body": cover.get_meta("body"),
				"facing": facing, "fig": Vector3(fx, height_at(fx, fz), fz),
			})
	return list

func _near_spot(x: float, z: float, r2: float) -> bool:
	for s in enemy_spots + player_spots:
		if (s.x - x) ** 2 + (s.z - z) ** 2 < r2:
			return true
	return false


# ---------- Décor (instancié, avec une clairière autour des cachettes) ----------
func _scatter() -> void:
	var pines := []
	var rounds := []
	var rocks := [[], []]
	var bushes := []
	var beach := [[], []]   # galets et bois flotté sur les plages
	for i in 18000:
		var x := (rng.randf() * 2 - 1) * 640
		var z := (rng.randf() * 2 - 1) * 640
		if _near_spot(x, z, 144):
			continue
		var h := height_at(x, z)
		if h < WATER_Y + 0.3:
			continue
		var r := rng.randf()
		var sc := 0.8 + rng.randf() * 0.6
		var rot := rng.randf() * TAU
		if h < WATER_Y + 2.5:
			# Plage
			if r < 0.05:
				beach[0].append([x, h + 0.05, z, 0.3 + rng.randf() * 0.7, rot, 0.6])
			elif r < 0.07:
				beach[1].append([x, h + 0.12, z, 0.8 + rng.randf() * 0.6, rot, 1.0])
			continue
		var zn := zone_at(x, z, h)
		if zn == "foret":
			if r < 0.7:
				pines.append([x, h - 0.3, z, sc, rot, 1.0])
			elif r < 0.78:
				bushes.append([x, h, z, sc, rot, 0.9])
		elif zn == "herbe":
			if r < 0.07:
				bushes.append([x, h, z, sc + 0.1, rot, 0.85])
			elif r < 0.105:
				rounds.append([x, h - 0.3, z, sc, rot, 1.0])
		elif zn == "roche":
			if r < 0.12:
				rocks[0].append([x, h + 0.2, z, 0.8 + rng.randf() * 2.2, rot, 0.7])
		elif r < 0.04:
			rocks[1].append([x, h + 0.2, z, 0.8 + rng.randf() * 2.0, rot, 0.7])
	var body := StaticBody3D.new()
	add_child(body)
	_inst(_pine_mesh, toon(Color.WHITE, true, true, 0.12), pines, body, "tree")
	_inst(_round_tree_mesh, toon(Color.WHITE, true, true, 0.1), rounds, body, "round")
	_inst(_rock_mesh, toon(Color("#86837c"), false, true), rocks[0], body, "rock")
	_inst(_rock_mesh, toon(Color("#e3eaf2"), false, true), rocks[1], body, "rock")
	_inst(_bush_mesh, toon(Color.WHITE, true, true, 0.05, 1.5), bushes, body, "bush")
	_inst(_rock_mesh, toon(Color("#b8ad98"), false, false), beach[0], body, "pebble")
	_inst(_log_mesh, toon(Color.WHITE, true, true), beach[1], body, "log")

func _multimesh(mesh: Mesh, m: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)
	return mmi

func _inst(mesh: Mesh, m: Material, list: Array, body: StaticBody3D, kind: String) -> void:
	if list.is_empty():
		return
	var xforms := []
	for p in list:
		var basis := Basis(Vector3.UP, p[4]).scaled(Vector3(p[3], p[3] * p[5], p[3]))
		xforms.append(Transform3D(basis, Vector3(p[0], p[1], p[2])))
		if kind == "pebble" or kind == "log":
			continue  # petits détails de plage : pas de collision
		# Collision : le décor arrête les balles.
		var cs := CollisionShape3D.new()
		var s: float = p[3]
		if kind == "tree" or kind == "round":
			var cyl := CylinderShape3D.new()
			cyl.radius = (1.0 if kind == "tree" else 1.7) * s
			cyl.height = (7.0 if kind == "tree" else 5.5) * s
			cs.shape = cyl
			cs.position = Vector3(p[0], p[1] + cyl.height / 2, p[2])
		else:
			var sph := SphereShape3D.new()
			sph.radius = 0.8 * s
			cs.shape = sph
			cs.position = Vector3(p[0], p[1] + (0.4 * s if kind == "bush" else 0.0), p[2])
		body.add_child(cs)
	_multimesh(mesh, m, xforms)


# ---------- Herbe et fleurs (seulement pour le décor, n'arrêtent pas les balles) ----------
func _tuft_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var base := Color("#3f7d2a")
	var tip := Color("#b4e35f")
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.07
		var hgt := 0.5 + 0.25 * (i % 3) / 2.0
		var top := dir * 0.22 + Vector3(0, hgt, 0)
		# Lame visible des deux côtés.
		for tri in [[-side, side, top], [side, -side, top]]:
			for v in tri:
				verts.append(v)
				cols.append(tip if v == top else base)
				norms.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _flower_mesh(color: Color) -> ArrayMesh:
	var stem := _cyl(0.015, 0.015, 0.4, 4)
	var head := _sphere(0.09, 6, 3)
	return _merge([
		[stem, _at(Vector3(0, 0.2, 0)), Color("#4f8f30")],
		[head, _at(Vector3(0, 0.42, 0), Vector3(1.3, 0.6, 1.3)), color],
	])

func _grass() -> void:
	# Deux petites textures décrivent le sol : la hauteur et où pousse l'herbe.
	var w := SEG + 1
	var hmap := ImageTexture.create_from_image(Image.create_from_data(w, w, false, Image.FORMAT_RF, heights.to_byte_array()))
	var mtex := ImageTexture.create_from_image(Image.create_from_data(w, w, false, Image.FORMAT_RGBA8, _grass_mask))
	var fields := [
		# [forme, teinte, canal du masque, densité, touffes par m², vent, garder les normales, taille min, taille max, aplatissement]
		[_tuft_mesh(), Color.WHITE, 0, 1.0, 3.2, 0.12, false, 0.7, 1.25, 1.0],
		[_flower_mesh(Color("#fffbf0")), Color.WHITE, 1, 0.6, 0.12, 0.06, false, 0.9, 1.3, 1.0],
		[_flower_mesh(Color("#ffd84a")), Color.WHITE, 1, 0.6, 0.1, 0.06, false, 0.9, 1.3, 1.0],
		[_flower_mesh(Color("#ff8fb8")), Color.WHITE, 1, 0.6, 0.08, 0.06, false, 0.9, 1.3, 1.0],
		[_rock_mesh, Color("#a8a39a"), 2, 1.0, 0.45, 0.0, true, 0.1, 0.45, 0.6],
		[_rock_mesh, Color("#f4f8fc"), 3, 1.0, 0.12, 0.0, true, 0.3, 1.0, 0.35],
	]
	for f in fields:
		var m := ShaderMaterial.new()
		m.shader = GRASS
		m.set_shader_parameter("heightmap", hmap)
		m.set_shader_parameter("mask", mtex)
		m.set_shader_parameter("cell", CELL)
		m.set_shader_parameter("grid", float(w))
		m.set_shader_parameter("half_size", S / 2)
		m.set_shader_parameter("water_y", WATER_Y)
		m.set_shader_parameter("radius", GRASS_RADIUS)
		m.set_shader_parameter("tint", f[1])
		m.set_shader_parameter("channel", f[2])
		m.set_shader_parameter("density", f[3])
		m.set_shader_parameter("wind", f[5])
		m.set_shader_parameter("keep_normals", f[6])
		# Touffes réparties au hasard dans un carré autour de la caméra.
		var count := int(4 * GRASS_RADIUS * GRASS_RADIUS * f[4])
		var xforms := []
		for i in count:
			var s: float = lerpf(f[7], f[8], rng.randf())
			var pos := Vector3((rng.randf() * 2 - 1) * GRASS_RADIUS, 0, (rng.randf() * 2 - 1) * GRASS_RADIUS)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * f[9], s)), pos))
		var mmi := _multimesh(f[0], m, xforms)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-GRASS_RADIUS, -50, -GRASS_RADIUS), Vector3(2 * GRASS_RADIUS, 400, 2 * GRASS_RADIUS))
		_grass_fields.append(mmi)

func update_grass(cam: Vector3) -> void:
	# Le champ suit la caméra par pas de 4 m (les touffes ne « glissent » pas).
	var snapped_pos := Vector3(snappedf(cam.x, 4.0), 0, snappedf(cam.z, 4.0))
	for f in _grass_fields:
		f.position = snapped_pos
		(f.material_override as ShaderMaterial).set_shader_parameter("cam_pos", cam)


# ---------- Personnages ----------
# Le sniper est fait de pièces rigides arrondies. Chaque pose (debout, accroupi, couché)
# ne fait que déplacer ces mêmes pièces. Chaque sommet garde sa position « debout »
# (CUSTOM0) : la peinture suit le corps. Les pièces à couleur fixe (fusil) ne se peignent pas.
# [nom, forme, taille, {pose: [position, rotation (euler)]}, balancement, couleur fixe]
#   capsule : taille = (rayon, hauteur totale, rayon) ; tube : (rayon, hauteur, rayon) ; sphère : (rayon, …)
const PARTS := [
	["jambe_g", "capsule", Vector3(0.1, 0.86, 0.1), {
		"debout": [Vector3(-0.11, 0.47, 0), Vector3.ZERO], "accroupi": [Vector3(-0.12, 0.2, -0.28), Vector3(1.35, 0, 0)], "couche": [Vector3(-0.12, 0.11, -0.68), Vector3(PI / 2, 0, 0)]}, "leg_l", null],
	["jambe_d", "capsule", Vector3(0.1, 0.86, 0.1), {
		"debout": [Vector3(0.11, 0.47, 0), Vector3.ZERO], "accroupi": [Vector3(0.13, 0.42, 0.18), Vector3(-0.75, 0, 0)], "couche": [Vector3(0.12, 0.11, -0.68), Vector3(PI / 2, 0, 0)]}, "leg_r", null],
	["botte_g", "box", Vector3(0.17, 0.13, 0.28), {
		"debout": [Vector3(-0.11, 0.065, 0.05), Vector3.ZERO], "accroupi": [Vector3(-0.12, 0.08, -0.62), Vector3(1.35, 0, 0)], "couche": [Vector3(-0.12, 0.1, -1.13), Vector3(PI / 2, 0, 0)]}, "leg_l", null],
	["botte_d", "box", Vector3(0.17, 0.13, 0.28), {
		"debout": [Vector3(0.11, 0.065, 0.05), Vector3.ZERO], "accroupi": [Vector3(0.13, 0.07, 0.42), Vector3.ZERO], "couche": [Vector3(0.12, 0.1, -1.13), Vector3(PI / 2, 0, 0)]}, "leg_r", null],
	["buste", "capsule", Vector3(0.21, 0.66, 0.21), {
		"debout": [Vector3(0, 1.18, 0), Vector3.ZERO], "accroupi": [Vector3(0, 0.82, 0.06), Vector3(0.3, 0, 0)], "couche": [Vector3(0, 0.2, 0.02), Vector3(PI / 2, 0, 0)]}, "", null],
	["tete", "sphere", Vector3(0.17, 0.17, 0.17), {
		"debout": [Vector3(0, 1.67, 0.02), Vector3.ZERO], "accroupi": [Vector3(0, 1.3, 0.2), Vector3(0.3, 0, 0)], "couche": [Vector3(0, 0.33, 0.52), Vector3(PI / 2 - 0.5, 0, 0)]}, "", null],
	["chapeau", "tube", Vector3(0.26, 0.035, 0.26), {
		"debout": [Vector3(0, 1.79, 0.02), Vector3.ZERO], "accroupi": [Vector3(0, 1.41, 0.25), Vector3(0.3, 0, 0)], "couche": [Vector3(0, 0.42, 0.62), Vector3(PI / 2 - 0.5, 0, 0)]}, "", null],
	["calotte", "tube", Vector3(0.15, 0.13, 0.15), {
		"debout": [Vector3(0, 1.86, 0.02), Vector3.ZERO], "accroupi": [Vector3(0, 1.47, 0.27), Vector3(0.3, 0, 0)], "couche": [Vector3(0, 0.47, 0.67), Vector3(PI / 2 - 0.5, 0, 0)]}, "", null],
	["bras_g", "capsule", Vector3(0.075, 0.62, 0.075), {
		"debout": [Vector3(-0.3, 1.16, 0), Vector3(0, 0, -0.12)], "accroupi": [Vector3(-0.2, 1.0, 0.3), Vector3(-1.25, 0, 0)], "couche": [Vector3(-0.24, 0.16, 0.6), Vector3(PI / 2, 0, 0)]}, "arm_l", null],
	["bras_d", "capsule", Vector3(0.075, 0.62, 0.075), {
		"debout": [Vector3(0.3, 1.16, 0), Vector3(0, 0, 0.12)], "accroupi": [Vector3(0.2, 1.0, 0.3), Vector3(-1.25, 0, 0)], "couche": [Vector3(0.24, 0.16, 0.6), Vector3(PI / 2, 0, 0)]}, "arm_r", null],
	["sac", "box", Vector3(0.34, 0.4, 0.17), {
		"debout": [Vector3(0, 1.2, -0.25), Vector3.ZERO], "accroupi": [Vector3(0, 0.86, -0.18), Vector3(0.3, 0, 0)], "couche": [Vector3(0, 0.38, -0.02), Vector3(PI / 2, 0, 0)]}, "", null],
	["fusil", "tube", Vector3(0.028, 1.15, 0.028), {
		"debout": [Vector3(0.04, 1.2, -0.37), Vector3(0, 0, 0.8)], "accroupi": [Vector3(0.08, 1.04, 0.62), Vector3(PI / 2, 0, 0)], "couche": [Vector3(0.1, 0.24, 1.05), Vector3(PI / 2, 0, 0)]}, "", Color("#2b2f33")],
	["lunette", "tube", Vector3(0.045, 0.3, 0.045), {
		"debout": [Vector3(-0.03, 1.3, -0.43), Vector3(0, 0, 0.8)], "accroupi": [Vector3(0.08, 1.12, 0.5), Vector3(PI / 2, 0, 0)], "couche": [Vector3(0.1, 0.32, 0.92), Vector3(PI / 2, 0, 0)]}, "", Color("#1d2023")],
	["crosse", "box", Vector3(0.07, 0.36, 0.11), {
		"debout": [Vector3(0.36, 0.86, -0.37), Vector3(0, 0, 0.8)], "accroupi": [Vector3(0.08, 1.0, 0.08), Vector3(PI / 2, 0, 0)], "couche": [Vector3(0.1, 0.2, 0.5), Vector3(PI / 2, 0, 0)]}, "", Color("#8a5a3a")],
]
const CAMO_SHADER := preload("res://shaders/camo.gdshader")
const SWING := {"leg_l": 1.0, "leg_r": -1.0, "arm_l": -0.8, "arm_r": 0.8}
# Pivots (hanche, épaule) dans le repère de la pose « debout ».
const PIVOTS := {"leg_l": Vector3(-0.11, 0.88, 0), "leg_r": Vector3(0.11, 0.88, 0), "arm_l": Vector3(-0.3, 1.43, 0), "arm_r": Vector3(0.3, 1.43, 0)}

static func part_transform(part: Array, pose: String) -> Transform3D:
	var t: Array = part[3][pose]
	return Transform3D(Basis.from_euler(t[1]), t[0])

static func paintable(part: Array) -> bool:
	return part[5] == null

func _part_mesh(part: Array) -> ArrayMesh:
	var prim: PrimitiveMesh
	var size: Vector3 = part[2]
	match part[1]:
		"box":
			var b := BoxMesh.new()
			b.size = size
			prim = b
		"sphere":
			prim = _sphere(size.x, 16, 10)
		"capsule":
			var c := CapsuleMesh.new()
			c.radius = size.x
			c.height = size.y
			c.radial_segments = 14
			c.rings = 6
			prim = c
		_:
			prim = _cyl(size.x, size.x, size.y, 14)
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var stand := part_transform(part, "debout")
	var custom := PackedFloat32Array()
	custom.resize(verts.size() * 4)
	for i in verts.size():
		var r := stand * verts[i]
		custom[i * 4] = r.x
		custom[i * 4 + 1] = r.y
		custom[i * 4 + 2] = r.z
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh

func _make_figure(poses: Array = ["accroupi"]) -> Node3D:
	var g := Node3D.new()
	var camo := ShaderMaterial.new()
	camo.shader = CAMO_SHADER
	camo.set_shader_parameter("base_color", ZONES["roche"]["color"])
	var meshes := PARTS.map(func(p): return _part_mesh(p))
	for pose_name in poses:
		var pose := Node3D.new()
		pose.name = pose_name
		g.add_child(pose)
		for i in PARTS.size():
			var part: Array = PARTS[i]
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[i]
			mi.material_override = camo if paintable(part) else toon(part[5])
			mi.transform = part_transform(part, pose_name)
			mi.set_meta("part", i)
			mi.set_meta("base", mi.transform)
			if part[4] != "":
				# Pivot de balancement (hanche, épaule) exprimé dans la pose courante.
				var pivot_stand: Vector3 = PIVOTS[part[4]]
				var local := part_transform(part, "debout").affine_inverse() * pivot_stand
				mi.set_meta("pivot", mi.transform * local)
			pose.add_child(mi)
	g.set_meta("camo", camo)
	set_stance(g, poses[0])
	return g

func set_stance(fig: Node3D, stance: String) -> void:
	for pose in fig.get_children():
		if pose.get_class() == "Node3D":
			pose.visible = pose.name == stance

func animate_figure(fig: Node3D, stance: String, phase: float, amount: float) -> void:
	# Marche procédurale : jambes et bras se balancent autour de la hanche et de l'épaule,
	# le corps rebondit légèrement. amount = 0 (immobile) à 1 (course).
	var pose := fig.get_node_or_null(stance) as Node3D
	if pose == null:
		return
	var swing: float = {"debout": 0.65, "accroupi": 0.25, "couche": 0.12}[stance] * amount
	for mi in pose.get_children():
		var part: Array = PARTS[mi.get_meta("part")]
		if part[4] == "" or not mi.has_meta("pivot"):
			continue
		var base: Transform3D = mi.get_meta("base")
		var pivot: Vector3 = mi.get_meta("pivot")
		var a: float = sin(phase) * swing * SWING[part[4]]
		mi.transform = Transform3D(Basis(Vector3.RIGHT, a), pivot) * Transform3D(Basis.IDENTITY, -pivot) * base
	pose.position.y = absf(sin(phase)) * 0.05 * amount if stance == "debout" else 0.0

func pick_part(fig: Node3D, from: Vector3, dir: Vector3) -> Dictionary:
	# Rayon de la souris contre les pièces visibles (sans moteur physique).
	# Renvoie le point touché dans le repère « debout », celui de la peinture.
	var best := {}
	var best_t := INF
	for pose in fig.get_children():
		if not (pose is Node3D) or pose.get_class() != "Node3D" or not pose.visible:
			continue
		for mi in pose.get_children():
			var part: Array = PARTS[mi.get_meta("part")]
			var inv: Transform3D = mi.global_transform.affine_inverse()
			var o: Vector3 = inv * from
			var d: Vector3 = (inv.basis * dir).normalized()
			var size: Vector3 = part[2]
			var t := INF
			match part[1]:
				"sphere":
					var b := o.dot(d)
					var c := o.dot(o) - size.x * size.x
					var disc := b * b - c
					if disc >= 0:
						t = -b - sqrt(disc)
				"capsule":
					t = _ray_capsule(o, d, size.x, size.y / 2 - size.x)
				"box":
					t = _ray_box(o, d, size / 2)
				_:
					t = _ray_box(o, d, Vector3(size.x, size.y / 2, size.x))
			if t > 0 and t < best_t:
				best_t = t
				if not paintable(part):
					best = {}  # le fusil cache ce qui est derrière, mais ne se peint pas
					continue
				var local := o + d * t
				best = {"ref": part_transform(part, "debout") * local, "world": mi.global_transform * local}
	return best

static func _ray_box(o: Vector3, d: Vector3, half: Vector3) -> float:
	var tmin := -INF
	var tmax := INF
	for a in 3:
		if absf(d[a]) < 1e-6:
			if absf(o[a]) > half[a]:
				return INF
			continue
		var t1 := (-half[a] - o[a]) / d[a]
		var t2 := (half[a] - o[a]) / d[a]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	if tmin > tmax or tmax < 0:
		return INF
	return tmin if tmin > 0 else tmax

static func _ray_capsule(ro: Vector3, rd: Vector3, r: float, hh: float) -> float:
	# Intersection rayon / capsule d'axe y (segment de -hh à +hh, rayon r).
	var pa := Vector3(0, -hh, 0)
	var pb := Vector3(0, hh, 0)
	var ba := pb - pa
	var oa := ro - pa
	var baba := ba.dot(ba)
	var bard := ba.dot(rd)
	var baoa := ba.dot(oa)
	var rdoa := rd.dot(oa)
	var oaoa := oa.dot(oa)
	var a := baba - bard * bard
	var b := baba * rdoa - baoa * bard
	var c := baba * oaoa - baoa * baoa - r * r * baba
	var h := b * b - a * c
	if h >= 0.0 and absf(a) > 1e-9:
		var t := (-b - sqrt(h)) / a
		var y := baoa + t * bard
		if y > 0.0 and y < baba:
			return t
		var oc := oa if y <= 0.0 else ro - pb
		b = rd.dot(oc)
		c = oc.dot(oc) - r * r
		h = b * b - c
		if h > 0.0:
			return -b - sqrt(h)
	return INF

func set_camo(fig: Node3D, zone: String) -> void:
	# Tenue unie (l'ennemi) : la couleur du terrain, sans coups de pinceau.
	var m: ShaderMaterial = fig.get_meta("camo")
	m.set_shader_parameter("base_color", ZONES[zone]["color"])
	m.set_shader_parameter("stroke_count", 0)


# ---------- Repères, éclair du canon, marqueur de fin ----------
static func _ring_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x + 0.5 - 32, y + 0.5 - 32).length()
			var a := clampf(3.5 - absf(d - 24), 0, 1) + clampf(6.5 - d, 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	return ImageTexture.create_from_image(img)

static func _glow_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var t := clampf(Vector2(x + 0.5 - 32, y + 0.5 - 32).length() / 32.0, 0, 1)
			img.set_pixel(x, y, Color(1, 0.98 - t * 0.31, 0.86 - t * 0.63, 1 - t))
	return ImageTexture.create_from_image(img)

func _sprite(tex: Texture2D, color: Color, size: float) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.modulate = color
	sp.pixel_size = size / 64.0
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.no_depth_test = true
	sp.shaded = false
	sp.render_priority = 10
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sp)
	return sp

func _build_sprites() -> void:
	var ring := _ring_texture()
	flash_sprite = _sprite(_glow_texture(), Color.WHITE, 6)
	flash_sprite.visible = false
	end_marker = _sprite(ring, Color("#ef4f4f"), 1.6)
	end_marker.visible = false
