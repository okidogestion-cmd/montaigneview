extends Node3D
## La vallée : relief, zones de couleur, cachettes, décor et personnages.
## Repris du prototype web « Duel des Cimes ».

const ZONE_KEYS: Array[String] = ["neige", "roche", "herbe", "foret"]
const ZONES := {
	"neige": {"label": "Neige", "color": Color("#e6ecf0")},
	"roche": {"label": "Roche", "color": Color("#7a7671")},
	"herbe": {"label": "Herbe", "color": Color("#6b9342")},
	"foret": {"label": "Forêt", "color": Color("#2e5130")},
}
const MZ := 230.0          # centre des deux montagnes sur l'axe z (+ joueur, - ennemi)
const S := 1400.0          # taille de la vallée
const SEG := 200           # finesse du relief
const CELL := S / SEG
const PEAKS := [
	[0, -MZ, 130, 190], [0, MZ, 130, 190], [-270, -340, 95, 150], [290, -360, 110, 160],
	[-300, 310, 90, 150], [310, 330, 85, 140], [0, -580, 160, 230], [0, 580, 150, 230],
	[-560, 0, 120, 200], [560, 0, 120, 200],
]

var heights := PackedFloat32Array()
var rng := RandomNumberGenerator.new()
var enemy_spots: Array = []
var player_spots: Array = []
var markers: Array[Sprite3D] = []
var player: Node3D
var enemy: Node3D
var enemy_hitbox: StaticBody3D
var flash_sprite: Sprite3D
var end_marker: Sprite3D
var _materials := {}
var _rock_mesh: Mesh
var _bush_mesh: Mesh
var _tree_mesh: Mesh


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

static func fbm(x: float, z: float) -> float:
	var s := 0.0
	var a := 1.0
	var f := 1.0
	for i in 4:
		s += a * (vnoise(x * f, z * f) - 0.5)
		a *= 0.5
		f *= 2.03
	return s

static func height_fn(x: float, z: float) -> float:
	var h := 0.0
	for p in PEAKS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var r: float = p[3]
		h += p[2] * exp(-1.6 * (dx * dx * 0.7 + dz * dz) / (r * r))
	h += fbm(x * 0.012, z * 0.012) * 38.0 + fbm(x * 0.05, z * 0.05) * 6.0
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
	return lerpf(lerpf(a, b, u), lerpf(d, e, u), v)


# ---------- Construction ----------
func build() -> void:
	rng.seed = 20261025
	_rock_mesh = _sphere(1.0, 6, 3)
	_bush_mesh = _sphere(1.0, 6, 3, 0.5)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.9
	cone.height = 7.0
	cone.radial_segments = 7
	cone.rings = 1
	_tree_mesh = _shift(cone, 3.5)
	_build_terrain()
	enemy_spots = _build_spots(-MZ, 1)
	player_spots = _build_spots(MZ, -1)
	_scatter()
	player = _make_figure()
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

func _sphere(radius: float, segs: int, rings: int, lift := 0.0) -> Mesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2
	m.radial_segments = segs
	m.rings = rings
	return _shift(m, lift) if lift != 0.0 else m

func _shift(m: PrimitiveMesh, dy: float) -> Mesh:
	# Décale une forme vers le haut (pour qu'elle pose sur le sol).
	var arrays := m.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].y += dy
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

func mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		m.metallic_specular = 0.0
		_materials[key] = m
	return _materials[key]

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
			normals[r * w + c] = Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
			var col: Color = ZONES[zone_at(x, z, h)]["color"]
			var k := 0.9 + hash2(x * 0.3, z * 0.3) * 0.2
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
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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


# ---------- Cachettes ----------
func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
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
			var col := Color("#dce2e7") if zone == "neige" else Color("#6a6661")
			_part(g, _rock_mesh, col, Vector3(0, 0.35, 0), Vector3(1.8, 1, 1.5))
			_box(body, Vector3(0, 0.35, 0), Vector3(3.2, 1.8, 2.7))
		"herbe":
			_part(g, _bush_mesh, Color("#5a873a"), Vector3.ZERO, Vector3(1.5, 1, 1.4))
			_part(g, _bush_mesh, Color("#4f7b33"), Vector3(1.3, 0, -0.4), Vector3(0.9, 0.8, 0.9))
			_box(body, Vector3(0.4, 0.5, 0), Vector3(3.4, 1.8, 2.6))
		_:
			_part(g, _tree_mesh, Color("#24472a"), Vector3(-1.6, 0, -0.6), Vector3(1, 1.1, 1))
			_part(g, _bush_mesh, Color("#2a4d2d"), Vector3.ZERO, Vector3(1.4, 0.95, 1.3))
			_box(body, Vector3(0, 0.5, 0), Vector3(2.6, 1.8, 2.4))
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


# ---------- Décor (instancié, avec une clairière autour des cachettes) ----------
func _scatter() -> void:
	var all := enemy_spots + player_spots
	var trees := [[], []]
	var rocks := [[], []]
	var bushes := []
	for i in 9000:
		var x := (rng.randf() * 2 - 1) * 640
		var z := (rng.randf() * 2 - 1) * 640
		var near := false
		for s in all:
			if (s.x - x) ** 2 + (s.z - z) ** 2 < 144:
				near = true
				break
		if near:
			continue
		var h := height_at(x, z)
		var zn := zone_at(x, z, h)
		var r := rng.randf()
		var sc := 0.8 + rng.randf() * 0.6
		var rot := rng.randf() * TAU
		if zn == "foret":
			if r < 0.75:
				trees[0 if r < 0.37 else 1].append([x, h - 0.3, z, sc, rot, 1.0])
		elif zn == "herbe":
			if r < 0.06:
				bushes.append([x, h, z, sc + 0.2, rot, 0.8])
			elif r < 0.085:
				trees[1].append([x, h - 0.3, z, sc, rot, 1.0])
		elif zn == "roche":
			if r < 0.12:
				rocks[0].append([x, h + 0.2, z, 0.8 + rng.randf() * 2.2, rot, 0.7])
		elif r < 0.04:
			rocks[1].append([x, h + 0.2, z, 0.8 + rng.randf() * 2.0, rot, 0.7])
	var body := StaticBody3D.new()
	add_child(body)
	_inst(_tree_mesh, Color("#26492b"), trees[0], body, "tree")
	_inst(_tree_mesh, Color("#30593a"), trees[1], body, "tree")
	_inst(_rock_mesh, Color("#6d6964"), rocks[0], body, "rock")
	_inst(_rock_mesh, Color("#d6dde2"), rocks[1], body, "rock")
	_inst(_bush_mesh, Color("#5a873a"), bushes, body, "bush")

func _inst(mesh: Mesh, color: Color, list: Array, body: StaticBody3D, kind: String) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		var p: Array = list[i]
		var basis := Basis(Vector3.UP, p[4]).scaled(Vector3(p[3], p[3] * p[5], p[3]))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p[0], p[1], p[2])))
		# Collision : le décor arrête les balles.
		var cs := CollisionShape3D.new()
		var s: float = p[3]
		if kind == "tree":
			var cyl := CylinderShape3D.new()
			cyl.radius = 1.0 * s
			cyl.height = 7.0 * s
			cs.shape = cyl
			cs.position = Vector3(p[0], p[1] + 3.5 * s, p[2])
		else:
			var sph := SphereShape3D.new()
			sph.radius = 0.8 * s
			cs.shape = sph
			cs.position = Vector3(p[0], p[1] + (0.4 * s if kind == "bush" else 0.0), p[2])
		body.add_child(cs)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat(color)
	add_child(mmi)


# ---------- Personnages ----------
func _make_figure() -> Node3D:
	var g := Node3D.new()
	var camo := StandardMaterial3D.new()
	camo.albedo_color = Color("#7a7671")
	camo.roughness = 1.0
	camo.metallic_specular = 0.0
	var dark := mat(Color("#1b1d1e"))
	var torso := _fig_box(g, Vector3(0.62, 0.8, 0.5), camo, Vector3(0, 0.55, 0))
	torso.rotation.x = 0.25
	_fig_box(g, Vector3(0.6, 0.35, 0.7), camo, Vector3(0, 0.18, -0.15))
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.21
	hm.height = 0.42
	hm.radial_segments = 10
	hm.rings = 6
	head.mesh = hm
	head.material_override = camo
	head.position = Vector3(0, 1.08, 0.08)
	g.add_child(head)
	_fig_tube(g, 0.035, 1.5, dark, Vector3(0.12, 0.92, 0.55))
	_fig_tube(g, 0.05, 0.35, dark, Vector3(0.12, 1.02, 0.35))
	g.set_meta("camo", camo)
	return g

func _fig_box(g: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	g.add_child(mi)
	return mi

func _fig_tube(g: Node3D, radius: float, length: float, m: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 6
	mi.mesh = c
	mi.material_override = m
	mi.rotation.x = PI / 2
	mi.position = pos
	g.add_child(mi)

func set_camo(fig: Node3D, zone: String) -> void:
	(fig.get_meta("camo") as StandardMaterial3D).albedo_color = ZONES[zone]["color"]


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
	add_child(sp)
	return sp

func _build_sprites() -> void:
	var ring := _ring_texture()
	for s in player_spots:
		var sp := _sprite(ring, Color("#ff7a2f"), 9)
		sp.position = s.fig + Vector3(0, 5, 0)
		sp.layers = 2  # invisible dans la lunette ennemie
		sp.set_meta("spot", s)
		markers.append(sp)
	flash_sprite = _sprite(_glow_texture(), Color.WHITE, 6)
	flash_sprite.visible = false
	end_marker = _sprite(ring, Color("#ef4f4f"), 1.6)
	end_marker.visible = false
