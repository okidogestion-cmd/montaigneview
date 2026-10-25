extends Node3D
## Une île de l'arène, en blockout (formes simples, placeholders).
## Repère local : +Z regarde l'île adverse. L'arène pose deux fois cette île,
## la seconde tournée de 180° : les deux îles sont donc exactement équitables.
##
## Bloquent les tirs (collision, calque « decor ») : sol, rochers, ruine, tour,
## cabane, caisses, troncs. Ne bloquent pas : feuilles de palmier, buissons.

const TOON := preload("res://shaders/toon.gdshader")

## Couleur d'identification de l'île (fanion, foulard du joueur).
@export var accent_color := Color("#347BC1")
## Graine des petites variations décoratives (sans effet sur les collisions).
@export var decor_seed := 1

# Palette « Atoll peint » (CLAUDE.md §3).
const SAND := Color("#EBCB86")
const GRASS := Color("#78A957")
const LEAF_DARK := Color("#426D4D")
const WOOD := Color("#A97047")
const WOOD_DARK := Color("#7d5234")
const STONE := Color("#a59c8c")
const STONE_DARK := Color("#857c6e")
const ROCK := Color("#8f8a80")

const PLATEAU_Y := 2.6   # hauteur du plateau herbeux

var _mats := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = decor_seed
	_build_ground()
	_build_hill()
	_build_outcrop()
	_build_ruin()
	_build_watchtower()
	_build_hut()
	_build_rocks()
	_build_dock()
	_build_palms()
	_build_bushes()
	_build_flag()

## Point d'apparition : derrière la cabane, invisible depuis l'île adverse.
func spawn_transform() -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(-4, PLATEAU_Y + 0.1, -15.2))


# ---------- Outils de construction ----------
func _mat(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("albedo", color)
		_mats[key] = m
	return _mats[key]

func _mesh(mesh: Mesh, color: Color, xform: Transform3D, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.transform = xform
	parent.add_child(mi)
	return mi

func _solid(mi: MeshInstance3D) -> void:
	# Collision exacte de la forme affichée (calque 1 : décor qui bloque les tirs).
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape() if mi.mesh is CylinderMesh or mi.mesh is SphereMesh else mi.mesh.create_convex_shape()
	body.add_child(cs)
	mi.add_child(body)

func box(size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO, solid := true) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := _mesh(m, color, Transform3D(Basis.from_euler(rot), pos))
	if solid:
		_solid(mi)
	return mi

func cone(top_r: float, bottom_r: float, height: float, color: Color, pos: Vector3, segs := 24, solid := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = height
	m.radial_segments = segs
	m.rings = 1
	var mi := _mesh(m, color, Transform3D(Basis.IDENTITY, pos))
	if solid:
		_solid(mi)
	return mi

func rock(pos: Vector3, scale: Vector3, color := ROCK, solid := true) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 7
	m.rings = 4
	var mi := _mesh(m, color, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(scale), pos))
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = m.create_convex_shape()
		body.add_child(cs)
		mi.add_child(body)
	return mi

func ramp(from: Vector3, to: Vector3, width: float, color := WOOD) -> void:
	# Plan incliné de « from » (bas) à « to » (haut), dessus affleurant.
	var d := to - from
	var len := d.length()
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	var center := (from + to) / 2 - basis.y * 0.15
	var m := BoxMesh.new()
	m.size = Vector3(width, 0.3, len)
	var mi := _mesh(m, color, Transform3D(basis, center))
	_solid(mi)


# ---------- Relief ----------
func _build_ground() -> void:
	# Socle de sable : la plage descend dans l'eau (rivage à ~22,5 m du centre).
	cone(21.0, 27.0, 4.0, SAND, Vector3(0, -1.0, 0), 40)
	# Plateau herbeux, décalé vers l'arrière : plus de plage devant.
	cone(15.0, 19.0, 1.6, GRASS, Vector3(0, 1.8, -3), 40)

func _build_hill() -> void:
	# Hauteur n°1, à l'arrière droite : colline au fanion.
	cone(4.0, 8.0, 3.0, GRASS, Vector3(7, PLATEAU_Y + 1.5, -9), 28)

func _build_outcrop() -> void:
	# Hauteur n°2, devant à droite : éperon rocheux, plus exposé.
	cone(2.4, 5.0, 2.2, ROCK, Vector3(9, PLATEAU_Y + 1.1, 5), 9)
	rock(Vector3(10.5, PLATEAU_Y + 2.4, 6.2), Vector3(0.9, 0.7, 0.8))


# ---------- Couverts et constructions ----------
func _build_ruin() -> void:
	# Petite ruine de pierre envahie par la végétation, au centre-avant.
	var y := PLATEAU_Y
	box(Vector3(1.8, 2.2, 0.6), STONE, Vector3(1.6, y + 1.1, 2.0))
	box(Vector3(1.8, 2.2, 0.6), STONE, Vector3(4.6, y + 1.1, 2.0))
	box(Vector3(1.2, 0.6, 0.6), STONE_DARK, Vector3(3.1, y + 1.9, 2.0))      # linteau : fenêtre en dessous
	box(Vector3(0.6, 1.4, 3.6), STONE, Vector3(5.8, y + 0.7, 0.0))            # mur latéral, cassé à mi-hauteur
	box(Vector3(0.7, 2.6, 0.7), STONE_DARK, Vector3(0.4, y + 1.3, -1.2))      # pilier
	box(Vector3(1.9, 0.12, 0.65), GRASS.darkened(0.15), Vector3(1.6, y + 2.25, 2.0), Vector3.ZERO, false)  # mousse
	box(Vector3(1.9, 0.12, 0.65), GRASS.darkened(0.15), Vector3(4.6, y + 2.25, 2.0), Vector3.ZERO, false)

func _build_watchtower() -> void:
	# Tour de guet en bois, avant gauche. Garde-corps sur l'avant seulement :
	# on y voit loin, mais on y est exposé.
	var base := Vector3(-10, PLATEAU_Y, 3)
	var top := 4.2
	for sx in [-1.4, 1.4]:
		for sz in [-1.4, 1.4]:
			box(Vector3(0.3, top + 2.3, 0.3), WOOD_DARK, base + Vector3(sx, (top + 2.3) / 2, sz))
	box(Vector3(3.4, 0.25, 3.4), WOOD, base + Vector3(0, top, 0))
	box(Vector3(3.4, 0.9, 0.15), WOOD, base + Vector3(0, top + 0.55, 1.62))
	box(Vector3(3.8, 0.2, 3.8), WOOD_DARK, base + Vector3(0, top + 2.4, 0))   # petit toit, assez haut pour se tenir debout
	# Escalier (rampe) depuis l'arrière, jusqu'au bord de la plate-forme.
	ramp(base + Vector3(0, 0.02, -6.9), base + Vector3(0, top + 0.12, -1.7), 1.2)

func _build_hut() -> void:
	# Cabane, arrière gauche. Mur plein vers l'île adverse, porte à l'arrière :
	# elle abrite le point d'apparition.
	var c := Vector3(-4, PLATEAU_Y, -11)
	var h := 2.6
	box(Vector3(5.0, h, 0.2), WOOD, c + Vector3(0, h / 2, 2.0))                 # mur avant (plein)
	box(Vector3(0.2, h, 4.0), WOOD, c + Vector3(-2.4, h / 2, 0))
	box(Vector3(0.2, h, 4.0), WOOD, c + Vector3(2.4, h / 2, 0))
	box(Vector3(1.8, h, 0.2), WOOD, c + Vector3(-1.6, h / 2, -2.0))             # mur arrière, porte au milieu
	box(Vector3(1.8, h, 0.2), WOOD, c + Vector3(1.6, h / 2, -2.0))
	box(Vector3(1.4, 0.6, 0.2), WOOD, c + Vector3(0, h - 0.3, -2.0))
	box(Vector3(5.8, 0.18, 2.7), WOOD_DARK, c + Vector3(0, h + 0.45, 1.05), Vector3(-0.35, 0, 0))   # toit à deux pans
	box(Vector3(5.8, 0.18, 2.7), WOOD_DARK, c + Vector3(0, h + 0.45, -1.05), Vector3(0.35, 0, 0))

func _build_rocks() -> void:
	# Gros rochers : vrais couverts, à hauteur d'homme accroupi ou debout.
	var y := PLATEAU_Y
	rock(Vector3(-2.5, y + 0.5, 6.5), Vector3(1.6, 1.1, 1.3))
	rock(Vector3(10.5, y + 0.4, 0.5), Vector3(1.4, 0.9, 1.2))
	rock(Vector3(-12.5, y + 0.4, -3.0), Vector3(1.3, 1.0, 1.5))
	rock(Vector3(13.0, 1.2, 11.0), Vector3(1.8, 1.3, 1.5))          # sur la plage avant droite
	rock(Vector3(-14.0, 1.2, 12.0), Vector3(1.7, 1.4, 1.6))         # sur la plage avant gauche
	rock(Vector3(0.5, 0.9, 17.5), Vector3(2.2, 1.0, 1.4))           # au bord de l'eau, devant

func _build_dock() -> void:
	# Petit quai à l'arrière, caisses et tonneaux.
	box(Vector3(2.2, 0.2, 8.0), WOOD, Vector3(7, 0.8, -24))
	for z in [-21.0, -24.0, -27.0]:
		for x in [6.0, 8.0]:
			box(Vector3(0.25, 2.2, 0.25), WOOD_DARK, Vector3(x, -0.3, z))
	box(Vector3(1.0, 1.0, 1.0), WOOD_DARK, Vector3(6.6, 1.4, -22.5))
	box(Vector3(0.8, 0.8, 0.8), WOOD, Vector3(7.5, 1.3, -23.6), Vector3(0, 0.4, 0))
	box(Vector3(1.0, 1.0, 1.0), WOOD_DARK, Vector3(-8.2, PLATEAU_Y + 0.5, -13.0), Vector3(0, 0.3, 0))
	box(Vector3(1.0, 1.0, 1.0), WOOD, Vector3(-8.4, PLATEAU_Y + 0.5, -11.6), Vector3(0, -0.2, 0))


# ---------- Végétation ----------
func _palm(pos: Vector3, lean: float, turn: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = turn
	add_child(root)
	# Tronc courbé : segments empilés. Seul le tronc bloque les tirs.
	var p := Vector3.ZERO
	var tilt := 0.0
	for i in 6:
		var m := CylinderMesh.new()
		m.top_radius = 0.17 - i * 0.012
		m.bottom_radius = 0.2 - i * 0.012
		m.height = 1.1
		m.radial_segments = 8
		m.rings = 1
		tilt += lean / 6.0
		var b := Basis(Vector3.RIGHT, tilt)
		var center := p + b.y * 0.55
		var mi := _mesh(m, WOOD.lightened(0.05 * (i % 2)), Transform3D(b, center), root)
		_solid(mi)
		p += b.y * 1.1
	# Palmes : feuilles plates qui retombent (traversables).
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf() * 0.3
		var leaf := BoxMesh.new()
		leaf.size = Vector3(0.7, 0.06, 2.6)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.45)
		_mesh(leaf, GRASS.darkened(0.1) if i % 2 else LEAF_DARK, Transform3D(b, p + b.z * 1.2), root)

func _build_palms() -> void:
	_palm(Vector3(14, 1.0, -10), 0.5, 2.2)
	_palm(Vector3(-16, 0.9, -7), 0.6, -1.9)
	_palm(Vector3(16.5, 0.9, 7), 0.45, 0.6 + _rng.randf() * 0.3)
	_palm(Vector3(-17, 0.9, 9), 0.55, -0.7)
	_palm(Vector3(0, PLATEAU_Y, -15.5), 0.25, 3.0)

func _build_bushes() -> void:
	# Buissons ronds et doux : décoratifs, ils ne bloquent pas les tirs.
	for p in [Vector3(-7, PLATEAU_Y, 9), Vector3(6, PLATEAU_Y, 8), Vector3(12, PLATEAU_Y, -1), Vector3(-13, PLATEAU_Y, 0.5), Vector3(-1, PLATEAU_Y, -6)]:
		for i in 3:
			var s := 0.6 + _rng.randf() * 0.4
			var m := SphereMesh.new()
			m.radius = 1.0
			m.height = 2.0
			m.radial_segments = 10
			m.rings = 6
			var off := Vector3(_rng.randf_range(-0.8, 0.8), 0.45 * s, _rng.randf_range(-0.8, 0.8))
			_mesh(m, GRASS.darkened(0.2) if i == 0 else LEAF_DARK.lightened(0.15), Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.8, s)), p + off))

func _build_flag() -> void:
	# Fanion de couleur au sommet de la colline : identifie l'île depuis le large.
	var top := Vector3(7, PLATEAU_Y + 3.0, -9)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.06
	pole.height = 4.0
	_solid(_mesh(pole, WOOD_DARK, Transform3D(Basis.IDENTITY, top + Vector3(0, 2.0, 0))))
	box(Vector3(0.05, 0.9, 1.5), accent_color, top + Vector3(0, 3.5, 0.78), Vector3.ZERO, false)
