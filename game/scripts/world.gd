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
const TERRAIN_CHUNKS := 8  # affichage du terrain en 8 × 8 morceaux de 40 mailles (175 m)
const CELL := S / SEG
const WATER_Y := 26.0      # niveau de la mer : le fond de la vallée est sous l'eau, les montagnes sont des îles
const TOON := preload("res://shaders/toon.gdshader")
const TERRAIN := preload("res://shaders/terrain.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const WATER := preload("res://shaders/water.gdshader")
const GRASS := preload("res://shaders/grass.gdshader")
const FOLIAGE := preload("res://shaders/foliage.gdshader")
const VEG := preload("res://scripts/vegetation.gd")
const GRASS_RADIUS := 40.0

var heights := PackedFloat32Array()
var zones := PackedByteArray()          # zone de chaque point de grille (index dans ZONE_KEYS)
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
var _pebble_mesh: Mesh   # même forme que _rock_mesh, moins de facettes : les milliers de cailloux du champ d'herbe
var _rock_variants: Array[Mesh] = []   # rochers du décor : bloc arrondi, bloc anguleux à facettes, bloc doux
var _log_mesh: Mesh
var _foliage_mats: Array[ShaderMaterial] = []   # feuillage et écorce : effacés près de la caméra
var near_fade := 0.0                            # rayon actuel de cet effacement (m)


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
## detail : nom d'une texture de sol (« roche », « neige »…) projetée sur l'objet, ou "" pour une couleur unie.
func toon(color := Color.WHITE, vertex_colors := false, outline := false, wind := 0.0, wind_height := 7.0, detail := "") -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s|%s" % [color.to_html(), vertex_colors, outline, wind, wind_height, detail]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("albedo", color)
		m.set_shader_parameter("use_vertex_color", vertex_colors)
		m.set_shader_parameter("wind", wind)
		m.set_shader_parameter("wind_height", wind_height)
		if detail != "":
			m.set_shader_parameter("use_detail", true)
			m.set_shader_parameter("detail_tex", load("res://art/sol_%s.jpg" % detail))
			if detail == "roche":
				m.set_shader_parameter("use_relief", true)
				m.set_shader_parameter("detail_nrm", load("res://art/relief_roche.jpg"))
		if outline:
			pass  # contours désactivés : ils dessinaient chaque arbre deux fois (trop lourd sur téléphone)
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

## Rocher : la sphère donnée, déformée par le bruit du rocher (dessous aplati), normales douces.
## seed décale le bruit (autre forme) ; facets : faces planes (granit taillé) au lieu de normales douces.
func _rock_shape(sphere: SphereMesh, seed := Vector2.ZERO, facets := false) -> Mesh:
	var ra := sphere.get_mesh_arrays()
	var rv: PackedVector3Array = ra[Mesh.ARRAY_VERTEX]
	for i in rv.size():
		var p := rv[i]
		var k := 0.78 + vnoise(p.x * 1.7 + p.y * 0.6 + seed.x, p.z * 1.7 - p.y + seed.y) * 0.3 + vnoise(p.x * 4.1 - p.y + seed.y, p.z * 4.1 + p.y * 2.0 + seed.x) * 0.12
		var q := p * k
		q.y = maxf(q.y, -0.35) * (0.8 if q.y > 0 else 1.0)   # dessous aplati : il repose sur le sol
		rv[i] = q
	ra[Mesh.ARRAY_VERTEX] = rv
	var rmesh := ArrayMesh.new()
	rmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ra)
	var st := SurfaceTool.new()
	st.create_from(rmesh, 0)
	if facets:
		st.deindex()
	st.generate_normals()
	return st.commit()

func _build_meshes() -> void:
	# Rocher : sphère déformée par un bruit à plusieurs échelles (bloc arrondi, arêtes et méplats),
	# normales douces : la texture de roche fait le détail.
	_rock_mesh = _rock_shape(_sphere(1.0, 14, 9))   # 280 triangles
	# Cailloux et mottes de neige du champ d'herbe (≈ 2 700, vus jusqu'à 2 m à l'atelier) : même bruit, même forme,
	# sphère de départ plus grossière : 160 triangles au lieu de 280, le contour reste rond.
	_pebble_mesh = _rock_shape(_sphere(1.0, 10, 7))
	# Rochers du décor (avec beaucoup de petits cailloux d'éboulis) : formes légères, 120 à 160 triangles.
	_rock_variants = [_pebble_mesh, _rock_shape(_sphere(1.0, 9, 6), Vector2(13.7, -4.1), true), _rock_shape(_sphere(1.0, 10, 6), Vector2(-8.3, 21.9))]
	# Arbres et buissons photo (art/arbres/) : plusieurs modèles par sorte, mélangés dans le décor.
	for kind in PACK_TREES:
		var meshes: Array[Mesh] = []
		for t in PACK_TREES[kind]:
			meshes.append(_pack_tree(t[0], t[1], t[2], t[3]))
		_tree_meshes[kind] = meshes
	var bark := Color("#7a5233")
	# Bois flotté : un tronc couché, avec une branche cassée.
	_log_mesh = _merge([
		[_cyl(0.16, 0.2, 2.6, 7), Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, 0.1, 0)), Color("#b9a58a")],
		[_cyl(0.05, 0.08, 0.7, 5), Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3(0.5, 0.35, 0)), Color("#a8937a")],
	])

## Arbres du « tree pack 1.1 » : un tronc et quatre cartes croisées avec la photo de l'arbre
## (128 px d'origine, agrandie à 256 px aux contours adoucis).
## [modèle, hauteur (m), vent, lumière qui traverse les feuilles]
## Les premiers de chaque sorte (tree07, bush02, bush06) servent aussi aux cachettes : ne pas les déplacer.
const PACK_TREES := {
	"tree": [
		["tree07", 9.5, 0.12, 0.25], ["tree12", 11.0, 0.12, 0.25], ["tree05", 11.5, 0.12, 0.25],   # épicéas sombres
		["tree01", 11.0, 0.13, 0.3], ["tree11", 10.0, 0.13, 0.3], ["tree04", 10.0, 0.13, 0.3],     # pins et mélèzes, plus clairs
		["tree09", 10.5, 0.12, 0.25], ["tree10", 10.5, 0.12, 0.25],                                # sapins
		["tree06", 8.5, 0.1, 0.2],                                                                  # givré, vers la limite des arbres
	],
	"round": [["tree19", 7.5, 0.1, 0.4], ["tree24", 7.5, 0.1, 0.4], ["tree22", 7.0, 0.1, 0.4]],
	"bush": [["bush02", 1.8, 0.05, 0.35], ["bush06", 1.7, 0.05, 0.35], ["bush04", 1.7, 0.05, 0.35], ["bush08", 1.6, 0.05, 0.3]],
}
const STANDS := [[0, 1, 2], [3, 4, 5], [6, 7]]   # peuplements : épicéas, pins/mélèzes, sapins (indices dans « tree »)
const FROSTED := 8
const TREE_REF := {"tree": 9.5, "round": 7.5}       # hauteur de référence des collisions (cylindres)
var _tree_meshes := {}   # sorte → modèles

## Un arbre du pack, mis à la hauteur voulue. Le feuillage reçoit des normales « en boule » (éclairage doux,
## comme une vraie couronne) et s'assombrit vers le bas ; il s'efface près de la caméra comme le reste.
func _pack_tree(name: String, height: float, wind: float, translucency: float) -> ArrayMesh:
	var scene: Node = load("res://art/arbres/%s.fbx" % name).instantiate()
	var src: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var a: Array = src.mesh.surface_get_arrays(0)
	scene.free()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bush := name.begins_with("bush")
	var top := 0.0
	var low := INF
	for i in v.size():
		top = maxf(top, v[i].y)
		if bush or uv[i].x > 0.25:   # le tronc est à gauche de l'image, le feuillage à droite
			low = minf(low, v[i].y)
	var k := height / top
	var center := Vector3(0, (low + top) * 0.5 * k, 0)
	var col := PackedColorArray()
	col.resize(v.size())
	for i in v.size():
		v[i] *= k
		if bush or uv[i].x > 0.25:
			nrm[i] = (v[i] - center).normalized().lerp(Vector3.UP, 0.35).normalized()
			col[i] = Color.WHITE * lerpf(0.65, 1.0, clampf((v[i].y - low * k) / ((top - low) * k), 0.0, 1.0))
		else:
			col[i] = Color.WHITE * 0.8
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nrm
	a[Mesh.ARRAY_COLOR] = col
	a[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("albedo_tex", load("res://art/arbres/%s.png" % name))
	m.set_shader_parameter("alpha_cut", 0.5)
	m.set_shader_parameter("translucency", translucency)
	m.set_shader_parameter("wind", wind)
	m.set_shader_parameter("wind_height", height)
	m.set_shader_parameter("near_fade", near_fade)
	mesh.surface_set_material(0, m)
	_foliage_mats.append(m)
	return mesh

## Accessoires de la scène Higgsfield « Sniper Arena » de l'utilisateur (art/accessoires/, sortis par
## tools/accessoires.gd) : une surface par matière d'origine, à qui on donne une matière du jeu.
const PROP_MATS := {
	"MAT_worn_sandbags": ["#7a7052", "foret"], "MAT_weathered_timber": ["#7a6548", "foret"],
	"MAT_dark_timber": ["#4a4034", "foret"], "CAMO_DIGITAL_OLIVE": ["#5d6b45", "herbe"],
	"MAT_military_crate_olive": ["#5f6a4a", "roche"], "MAT_old_military_metal": ["#454c40", "foret"],
	"MAT_dark_trunk": ["#6a573f", "foret"],
}
var _props := {}

func prop(name: String) -> Mesh:
	if not _props.has(name):
		var src: ArrayMesh = load("res://art/accessoires/%s.res" % name)
		var mesh := ArrayMesh.new()
		for i in src.get_surface_count():
			var st := SurfaceTool.new()
			# Le « rondin » de la scène d'origine est debout : on le couche.
			var xf := Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.36, 2.0)) if name == "rondin" else Transform3D.IDENTITY
			st.append_from(src, i, xf)
			st.commit(mesh)
			var key := src.surface_get_name(i)
			var pm: Array = PROP_MATS.get(key, ["#7d7a70", "roche"])
			mesh.surface_set_material(i, toon(Color(pm[0]), false, false, 0.0, 7.0, pm[1]))
		_props[name] = mesh
	return _props[name]

## Rayon (m) autour de la caméra où arbres et buissons s'effacent : ils ne bouchent jamais la vue.
func set_near_fade(r: float) -> void:
	near_fade = r
	for m in _foliage_mats:
		m.set_shader_parameter("near_fade", r)

## Le décor touché est-il un arbre ou un buisson (traversé par les balles quand il est effacé) ?
func is_foliage(collider: Object) -> bool:
	return collider != null and collider.has_meta("foliage")


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
	player = _make_figure()
	add_child(player)
	player.visible = false
	set_stance(player, "debout")
	enemy = _make_figure()
	add_child(enemy)
	enemy.visible = false
	set_stance(enemy, "accroupi", true)
	enemy_hitbox = StaticBody3D.new()
	var hs := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(1, 1.4, 1.2)
	hs.shape = hb
	enemy_hitbox.add_child(hs)
	enemy_hitbox.position.y = 0.7
	enemy.add_child(enemy_hitbox)
	_build_sprites()

func _load_or_compute_relief() -> void:
	# Le relief (hauteurs et zones) est fabriqué une fois pour toutes par tools/relief.py (montagnes, crêtes,
	# érosion), puis rangé dans data/ par tools/relief_vers_godot.gd : le jeu n'a plus qu'à le lire.
	var w := SEG + 1
	heights = (load("res://data/relief_%d_hauteurs.res" % SEG) as Image).get_data().to_float32_array()
	zones = (load("res://data/relief_%d_zones.res" % SEG) as Image).get_data()
	if heights.size() != w * w or zones.size() != w * w:
		push_error("Relief de data/ incomplet : relancer tools/relief.py et tools/relief_vers_godot.gd")

func zone_of(x: float, z: float) -> String:
	# Zone du point de grille le plus proche (la même que celle dessinée sur le terrain).
	var w := SEG + 1
	var c := clampi(roundi((x + S / 2) / CELL), 0, SEG)
	var r := clampi(roundi((z + S / 2) / CELL), 0, SEG)
	return ZONE_KEYS[zones[r * w + c]]

func _build_terrain() -> void:
	var w := SEG + 1
	_load_or_compute_relief()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	# Poids des textures de sol (terrain.gdshader) : UV = neige, roche ; UV2 = herbe, forêt ; aucun = sable.
	var uv1 := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(w * w)
	normals.resize(w * w)
	colors.resize(w * w)
	uv1.resize(w * w)
	uv2.resize(w * w)
	var sand := Color("#e3d39a")
	var zone_colors: Array[Color] = []
	for k in ZONE_KEYS:
		zone_colors.append(ZONES[k]["color"])
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
			var zi := zones[r * w + c]
			var col: Color = zone_colors[zi]
			var gi := (r * w + c) * 4
			# Masque de l'herbe : herbe, fleurs, cailloux, bosses de neige (ordre neige, roche, herbe, forêt).
			_grass_mask[gi] = [0, 0, 255, 120][zi]
			_grass_mask[gi + 1] = [0, 0, 255, 0][zi]
			_grass_mask[gi + 2] = [40, 255, 0, 0][zi]
			_grass_mask[gi + 3] = [255, 0, 0, 0][zi]
			if h < WATER_Y + 2.5:
				col = sand  # plage autour du lac
			else:
				uv1[r * w + c] = Vector2(1 if zi == 0 else 0, 1 if zi == 1 else 0)
				uv2[r * w + c] = Vector2(1 if zi == 2 else 0, 1 if zi == 3 else 0)
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
	arrays[Mesh.ARRAY_TEX_UV] = uv1
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := ShaderMaterial.new()
	m.shader = TERRAIN
	for k in ["neige", "roche", "herbe", "foret", "sable"]:
		m.set_shader_parameter("tex_" + k, load("res://art/sol_%s.jpg" % k))
	m.set_shader_parameter("nrm_roche", load("res://art/relief_roche.jpg"))
	m.set_shader_parameter("nrm_herbe", load("res://art/relief_herbe.jpg"))
	m.set_shader_parameter("patches", 0.12)
	# Affichage : le terrain est découpé en 8 × 8 morceaux (mêmes sommets, mêmes triangles, même matériau).
	# La carte graphique ignore les morceaux hors de la vue, et seuls les morceaux proches (zone des ombres,
	# 90 m) sont redessinés dans les ombres, au lieu du terrain entier deux fois.
	var step := SEG / TERRAIN_CHUNKS
	for br in TERRAIN_CHUNKS:
		for bc in TERRAIN_CHUNKS:
			var mi := MeshInstance3D.new()
			mi.mesh = _terrain_chunk(arrays, br * step, bc * step, step)
			mi.material_override = m
			add_child(mi)
	# Collision : le terrain entier, d'un seul bloc, comme avant.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

## Un morceau carré du terrain (step × step mailles à partir de la ligne r0, colonne c0) : les sommets sont recopiés
## tels quels (position, normale, couleur, poids des textures) et les triangles gardent le même découpage.
func _terrain_chunk(arrays: Array, r0: int, c0: int, step: int) -> ArrayMesh:
	var w := SEG + 1
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var cw := step + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv1 := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for r in range(r0, r0 + cw):
		for c in range(c0, c0 + cw):
			var g := r * w + c
			verts.append(src_v[g])
			normals.append(src_n[g])
			colors.append(src_c[g])
			uv1.append(src_uv[g])
			uv2.append(src_uv2[g])
	var idx := PackedInt32Array()
	for r in step:
		for c in step:
			var a := r * cw + c
			idx.append_array([a, a + 1, a + cw, a + 1, a + cw + 1, a + cw])
	var chunk := []
	chunk.resize(Mesh.ARRAY_MAX)
	chunk[Mesh.ARRAY_VERTEX] = verts
	chunk[Mesh.ARRAY_NORMAL] = normals
	chunk[Mesh.ARRAY_COLOR] = colors
	chunk[Mesh.ARRAY_TEX_UV] = uv1
	chunk[Mesh.ARRAY_TEX_UV2] = uv2
	chunk[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chunk)
	return mesh

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
		"sacs":
			# Nid de tireur : muret de sacs de sable sur deux hauteurs, retours sur les côtés, caisse et fût.
			_part(g, prop("sacs"), null, Vector3(0, -0.08, 0), Vector3.ONE)
			_part(g, prop("sacs"), null, Vector3(0.14, 0.46, 0), Vector3(0.95, 1, 1))
			for side in [-1.0, 1.0]:
				var w := MeshInstance3D.new()
				w.mesh = prop("sacs_petit")
				w.position = Vector3(side * 1.75, -0.08, -0.55)
				w.rotation.y = PI / 2
				g.add_child(w)
			_part(g, prop("caisse"), null, Vector3(1.0, -0.05, -1.5), Vector3.ONE)
			_part(g, prop("fut"), null, Vector3(-1.2, -0.05, -1.7), Vector3.ONE)
			_box(body, Vector3(0, 0.5, 0), Vector3(3.1, 1.1, 0.5))
			_box(body, Vector3(-1.75, 0.3, -0.55), Vector3(0.5, 0.6, 1.5))
			_box(body, Vector3(1.75, 0.3, -0.55), Vector3(0.5, 0.6, 1.5))
		"neige", "roche":
			var col := Color("#e3eaf2") if zone == "neige" else Color("#86837c")
			_part(g, _rock_mesh, toon(col, false, true, 0.0, 7.0, zone), Vector3(0, 0.35, 0), Vector3(1.8, 1, 1.5))
			_box(body, Vector3(0, 0.35, 0), Vector3(3.2, 1.8, 2.7))
		"herbe":
			_part(g, _tree_meshes["bush"][0], null, Vector3.ZERO, Vector3(1.8, 1.0, 1.7))
			body.set_meta("foliage", true)
			_box(body, Vector3(0.2, 0.6, 0), Vector3(3.2, 1.8, 2.6))
		_:
			_part(g, _tree_meshes["tree"][0], null, Vector3(-1.6, 0, -0.6), Vector3(0.9, 0.85, 0.9))
			_part(g, _tree_meshes["bush"][1], null, Vector3.ZERO, Vector3(1.7, 0.95, 1.6))
			body.set_meta("foliage", true)
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
			var zone := zone_of(x, z)
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
	# Composition forestière (et non plus des points semés au hasard sur toute la carte) :
	#  - une carte de densité (bruit à grande échelle) fait des forêts, des bosquets, des clairières et des lisières ;
	#  - la forêt suit le terrain : dense en bas et dans la zone forêt, rare sur les pentes raides, absente au-dessus
	#    de la limite des arbres ; les arbres rapetissent avec l'altitude, puis quelques pins rabougris ;
	#  - trois peuplements (épicéas, pins et mélèzes, sapins) en grandes taches, chacun avec ses modèles ;
	#  - un espacement minimal entre les arbres (pas de paquets ni d'alignements) ;
	#  - chaque arbre a sa nuance de couleur, sa taille, sa silhouette (étirement) ;
	#  - les rochers en amas (gros blocs rares, petits nombreux), une forme de roche par versant (trois formes) ;
	#  - la petite végétation (buissons bas) est décorative : ni collision, ni effet sur ce que voit l'ennemi.
	# Grands arbres, buissons hauts et rochers gardent leur collision (couvert, balles) ; les cachettes restent dégagées.
	var trees := []     # [x, y, z, échelle, rotation, étirement, modèle, couleur]
	var rounds := []
	var bushes := []    # buissons hauts (≥ 1,2 m) : couvert
	var shrubs := []    # buissons bas : décor
	var rocks := []     # [x, y, z, échelle, rotation, aplatissement, forme, couleur]
	var scree := []     # petits cailloux d'éboulis : décor
	var snow_rocks := []
	var beach := [[], []]
	var taken := {}     # grille de 4 m : arbres déjà posés (espacement)
	var step := 4.6
	var n := int(1280.0 / step)
	for gi in n:
		for gj in n:
			var x := -640.0 + (gi + rng.randf()) * step
			var z := -640.0 + (gj + rng.randf()) * step
			var h := height_at(x, z)
			if h < WATER_Y + 0.3:
				continue
			var play_d := minf(Vector2(x, z - MZ).length(), Vector2(x, z + MZ).length())
			if play_d < 180.0 and _near_spot(x, z, 144):   # cachettes : toutes à moins de 165 m du centre de leur île
				continue
			var r := rng.randf()
			var rot := rng.randf() * TAU
			if h < WATER_Y + 2.5:
				# Plage : galets et bois flotté (même densité qu'avant).
				if r < 0.012:
					beach[0].append([x, h + 0.05, z, 0.3 + rng.randf() * 0.7, rot, 0.6])
				elif r < 0.016:
					beach[1].append([x, h + 0.12, z, 0.8 + rng.randf() * 0.6, rot, 1.0])
				continue
			var zn := zone_of(x, z)
			if zn == "neige":
				if r < 0.009:
					snow_rocks.append([x, h + 0.2, z, 0.8 + rng.randf() * 2.0, rot, 0.7])
				continue
			var slope := (absf(height_at(x + 2.0, z) - height_at(x - 2.0, z)) + absf(height_at(x, z + 2.0) - height_at(x, z - 2.0))) / 4.0
			var treeline := 140.0 + fbm(x * 0.02, z * 0.02) * 30.0   # îles Higgsfield : plus hautes, la forêt monte plus haut
			var alt := clampf((h - WATER_Y) / (treeline - WATER_Y), 0.0, 1.3)
			# Densité de forêt : grandes taches + bords irréguliers, selon la zone, la pente et l'altitude.
			var dens := (fbm(x * 0.011 + 3.1, z * 0.011 - 7.3) + 0.47) * 0.8 + (fbm(x * 0.045 - 11.0, z * 0.045 + 5.0) + 0.47) * 0.25
			dens += 0.42 if zn == "foret" else (-0.1 if zn == "herbe" else -0.5)
			dens -= maxf(0.0, slope - 0.9) * 1.4
			dens -= maxf(0.0, alt - 0.8) * 2.5
			var canopy := smoothstep(0.42, 0.72, dens)
			# Zone de jeu (où l'on se cache et d'où l'on tire) : autant de couvert qu'avant, pour ne pas changer la
			# difficulté ; au-delà (bas des îles, montagnes du fond), la forêt est pleine.
			var play := play_d < PLAY_RADIUS
			# Grands arbres
			if canopy > 0.0 and r < canopy * (PLAY_FILL if play else FOREST_FILL):
				# Grands arbres en bas (jusqu'à 18 m), de plus en plus petits en montant.
				var sc := lerpf(1.6 if not play else PLAY_MAX_SCALE, 0.6, pow(minf(alt, 1.0), 1.3)) * (0.8 + rng.randf() * 0.35)
				if _free(taken, x, z, 2.2 + 1.7 * sc):
					var model := _stand_model(x, z, alt)
					trees.append([x, h - 0.3, z, sc, rot, 0.9 + rng.randf() * 0.25, model, _tree_tint(x, z, alt)])
					_take(taken, x, z, 2.2 + 1.7 * sc)
					continue
			var r2 := rng.randf()
			# Lisières : jeunes arbres et buissons hauts là où la forêt s'éclaircit.
			if canopy > 0.02 and canopy < 0.7 and r2 < 0.05:
				if r2 < 0.012 and alt < 0.4 and _free(taken, x, z, 4.0):
					rounds.append([x, h - 0.3, z, 0.7 + rng.randf() * 0.4, rot, 0.95 + rng.randf() * 0.15, rng.randi() % 3, _tree_tint(x, z, alt)])
					_take(taken, x, z, 4.0)
				elif r2 < 0.026 and _free(taken, x, z, 2.5):
					trees.append([x, h - 0.2, z, 0.38 + rng.randf() * 0.2, rot, 0.95 + rng.randf() * 0.2, _stand_model(x, z, alt), _tree_tint(x, z, alt)])
					_take(taken, x, z, 2.5)
				elif _free(taken, x, z, 1.8):
					bushes.append([x, h, z, 0.85 + rng.randf() * 0.45, rot, 0.85, rng.randi() % 3, _tree_tint(x, z, alt)])
					_take(taken, x, z, 1.8)
				continue
			# Sous-bois : buissons bas (décor).
			if canopy > 0.3 and r2 < 0.09:
				shrubs.append([x, h - 0.05, z, 0.35 + rng.randf() * 0.25, rot, 0.8, SHRUB_MODELS[rng.randi() % 2], _tree_tint(x, z, alt)])
				continue
			# Prés : quelques arbres isolés (feuillus en bas, conifères plus haut) et touffes de buissons.
			if zn == "herbe" and canopy < 0.02 and slope < 0.7:
				if r2 < 0.007 and _free(taken, x, z, 6.0):
					if alt < 0.5 and rng.randf() < 0.6:
						rounds.append([x, h - 0.3, z, 0.85 + rng.randf() * 0.35, rot, 0.95 + rng.randf() * 0.15, rng.randi() % 3, _tree_tint(x, z, alt)])
					else:
						trees.append([x, h - 0.3, z, lerpf(1.15, 0.7, alt) * (0.85 + rng.randf() * 0.3), rot, 1.0, _stand_model(x, z, alt), _tree_tint(x, z, alt)])
					_take(taken, x, z, 6.0)
					continue
				if r2 < 0.012:
					shrubs.append([x, h - 0.05, z, 0.3 + rng.randf() * 0.3, rot, 0.75, SHRUB_MODELS[rng.randi() % 2], _tree_tint(x, z, alt)])
					continue
			# Limite des arbres : pins rabougris en petits groupes, avec des buissons bas.
			if alt > 0.82 and alt < 1.12 and slope < 0.85 and zn != "foret":
				if r2 < 0.012 and _free(taken, x, z, 2.2):
					trees.append([x, h - 0.15, z, 0.3 + rng.randf() * 0.16, rot, 0.85 + rng.randf() * 0.2, FROSTED if rng.randf() < 0.4 else _stand_model(x, z, alt), _tree_tint(x, z, alt)])
					_take(taken, x, z, 2.2)
					continue
				if r2 < 0.03:
					shrubs.append([x, h - 0.05, z, 0.28 + rng.randf() * 0.2, rot, 0.7, SHRUB_MODELS[rng.randi() % 2], _tree_tint(x, z, alt)])
					continue
			# Rochers : amas dans la roche, quelques blocs en forêt ; éboulis sur les pentes raides.
			var rock_seed := 0.008 if zn == "roche" else (0.0015 if zn != "neige" else 0.0)
			if r2 < rock_seed:
				_rock_cluster(rocks, scree, x, z, 3 + rng.randi() % 5, 3.0 + rng.randf() * 7.0)
				continue
			if zn == "roche" and slope > 0.75 and r2 < 0.025:
				scree.append([x, h + 0.05, z, 0.25 + rng.randf() * 0.45, rot, 0.55, _rock_region(x, z), _rock_tint(x, z)])
				continue
	var body := StaticBody3D.new()
	add_child(body)
	var leafy := StaticBody3D.new()   # arbres et buissons : traversés par les balles quand ils sont effacés
	leafy.set_meta("foliage", true)
	add_child(leafy)
	_inst_models("tree", trees, leafy)
	_inst_models("round", rounds, leafy)
	# Buissons hauts (collision) et bas (décor) d'un même modèle dessinés ensemble.
	_inst_models("bush", bushes, leafy, shrubs)
	# Rochers et cailloux d'éboulis d'une même forme dessinés ensemble ; collision pour les rochers seulement.
	for i in _rock_variants.size():
		var big := rocks.filter(func(p): return p[6] == i)
		var small := scree.filter(func(p): return p[6] == i)
		_collide(big, body, "rock")
		_inst(_rock_variants[i], toon(Color.WHITE, true, true, 0.0, 7.0, "roche"), big + small, null, "rock")
	_inst(_rock_mesh, toon(Color("#e3eaf2"), false, true, 0.0, 7.0, "neige"), snow_rocks, body, "rock")
	_inst(_rock_mesh, toon(Color("#b8ad98"), false, false, 0.0, 7.0, "roche"), beach[0], body, "pebble")
	_inst(_log_mesh, toon(Color.WHITE, true, true), beach[1], body, "log")
	print("décor : %d arbres, %d feuillus, %d buissons hauts, %d buissons bas, %d rochers, %d cailloux d'éboulis, plage %d + %d" % [
		trees.size(), rounds.size(), bushes.size(), shrubs.size(), rocks.size(), scree.size(), beach[0].size(), beach[1].size()])

const FOREST_FILL := 0.8
const SHRUB_MODELS := [0, 1]   # buissons bas : les modèles des buissons hauts (dessinés avec eux)
const PLAY_RADIUS := 210.0     # zone de jeu autour du centre de chaque île
const PLAY_FILL := 0.42        # forêt de la zone de jeu (réglée pour garder le couvert d'avant)
const PLAY_MAX_SCALE := 1.3   # part des emplacements libres de la forêt dense qui portent un grand arbre

## Un amas de rochers autour de (cx, cz) : beaucoup de petits, quelques gros, formes et nuances mêlées.
func _rock_cluster(rocks: Array, scree: Array, cx: float, cz: float, count: int, spread: float) -> void:
	var tint := _rock_tint(cx, cz)
	var shape := _rock_region(cx, cz)
	for k in count:
		var a := rng.randf() * TAU
		var d := spread * sqrt(rng.randf())
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		if _near_spot(x, z, 144):
			continue
		var h := height_at(x, z)
		if h < WATER_Y + 2.5:
			continue
		var sc := 0.35 + 2.4 * pow(rng.randf(), 2.2)
		var flat := 0.45 + rng.randf() * 0.4
		var form := shape
		var c := tint * (0.9 + rng.randf() * 0.18)
		c.a = 1.0
		var p := [x, h + 0.15 * sc, z, sc, rng.randf() * TAU, flat, form, c]
		if sc < 0.7:
			scree.append(p)
		else:
			rocks.append(p)

## Nuance d'un arbre : variation propre (clarté, chaleur), celle de son peuplement, un peu plus sombre en altitude.
func _tree_tint(x: float, z: float, alt: float) -> Color:
	var v := 0.86 + hash2(x * 1.31, z * 0.77) * 0.22
	var warm := (hash2(z * 0.53, x * 1.07) - 0.5) * 0.12 + fbm(x * 0.008 + 40.0, z * 0.008) * 0.25
	var high := clampf(alt - 0.5, 0.0, 0.5) * 0.18
	return Color(v * (1.0 + warm - high * 0.6), v * (1.0 + warm * 0.4 - high * 0.3), v * (1.0 - warm * 0.6 + high * 0.2))

## Forme des rochers d'une région (grandes taches) : un versant garde la même roche, d'un versant à l'autre elle change.
func _rock_region(x: float, z: float) -> int:
	return clampi(int((fbm(x * 0.004 + 77.0, z * 0.004 - 31.0) + 0.47) * 3.2), 0, 2)

func _rock_tint(x: float, z: float) -> Color:
	var g := 0.48 + (fbm(x * 0.02 - 9.0, z * 0.02 + 4.0) + 0.47) * 0.16
	var warm := fbm(x * 0.03 + 2.0, z * 0.03 - 3.0) * 0.08
	return Color(g + warm, g + warm * 0.4, g - warm * 0.3)

## Modèle d'arbre : son peuplement (grandes taches de bruit), un modèle du peuplement selon la position ;
## près de la limite des arbres, parfois le sapin givré.
func _stand_model(x: float, z: float, alt: float) -> int:
	if alt > 0.86 and hash2(x * 0.61, z * 0.29) < 0.3:
		return FROSTED
	var sv := fbm(x * 0.0042 + 50.0, z * 0.0042 - 20.0) + 0.47
	var stand: Array = STANDS[0] if sv < 0.42 else (STANDS[1] if sv > 0.56 else STANDS[2])
	if alt > 0.6 and sv > 0.5:
		stand = STANDS[1]   # en altitude, plutôt pins et mélèzes
	return stand[mini(int(hash2(x * 0.37, z * 0.37) * stand.size()), stand.size() - 1)]

func _free(taken: Dictionary, x: float, z: float, r: float) -> bool:
	var cx := floori(x / 4.0)
	var cz := floori(z / 4.0)
	var k := ceili(r / 4.0) + 1
	for i in range(cx - k, cx + k + 1):
		for j in range(cz - k, cz + k + 1):
			for t in taken.get(Vector2i(i, j), []):
				if (t.x - x) ** 2 + (t.y - z) ** 2 < (r + t.z) * (r + t.z) * 0.25:
					return false
	return true

func _take(taken: Dictionary, x: float, z: float, r: float) -> void:
	var key := Vector2i(floori(x / 4.0), floori(z / 4.0))
	if not taken.has(key):
		taken[key] = []
	taken[key].append(Vector3(x, z, r))

## Arbres ou buissons d'une sorte, regroupés par modèle (p[6]) ; « shrub » utilise les modèles de buissons.
func _inst_models(kind: String, list: Array, body: StaticBody3D, decor: Array = []) -> void:
	var meshes: Array = _tree_meshes[kind]
	for i in meshes.size():
		var k: float = float(PACK_TREES[kind][i][1]) / float(TREE_REF.get(kind, 1.0))
		var mine := list.filter(func(p): return p[6] == i)
		_collide(mine, body, kind, k)
		_inst(meshes[i], null, mine + decor.filter(func(p): return p[6] == i), null, kind, k)

func _multimesh(mesh: Mesh, m: Material, xforms: Array, colors: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)
	return mmi

const CHUNK := 175.0   # taille d'une zone de décor (m)

func _multimesh_chunked(mesh: Mesh, m: Material, xforms: Array, shadows: bool, colors: Array = []) -> void:
	# Le décor est découpé en zones : la carte graphique ignore celles hors de la vue.
	var cells := {}
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		var key := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
		if not cells.has(key):
			cells[key] = [[], []]
		cells[key][0].append(t)
		if not colors.is_empty():
			cells[key][1].append(colors[i])
	for key in cells:
		var mmi := _multimesh(mesh, m, cells[key][0], cells[key][1])
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Pose les instances (p = [x, y, z, échelle, rotation, étirement, (modèle), (couleur)]) ; k : taille du modèle
## par rapport à la référence des collisions. Collision pour le couvert seulement (arbres, buissons hauts, rochers).
func _inst(mesh: Mesh, m: Material, list: Array, body: StaticBody3D, kind: String, k := 1.0) -> void:
	if list.is_empty():
		return
	var xforms := []
	var colors := []
	for p in list:
		var basis := Basis(Vector3.UP, p[4]).scaled(Vector3(p[3], p[3] * p[5], p[3]))
		xforms.append(Transform3D(basis, Vector3(p[0], p[1], p[2])))
		if p.size() > 7:
			colors.append(p[7])
	if body != null and kind != "pebble" and kind != "log":
		_collide(list, body, kind, k)
	_multimesh_chunked(mesh, m, xforms, kind == "tree" or kind == "round" or kind == "rock", colors)

## Collisions du décor (couvert) : arrêtent les balles et les regards ; seulement près des deux îles de jeu.
func _collide(list: Array, body: StaticBody3D, kind: String, k := 1.0) -> void:
	for p in list:
		if minf(Vector2(p[0], p[2] - MZ).length(), Vector2(p[0], p[2] + MZ).length()) > 260.0:
			continue  # loin des deux îles de jeu : rien ne peut s'y cogner
		var cs := CollisionShape3D.new()
		var s: float = p[3]
		if kind == "tree" or kind == "round":
			var cyl := CylinderShape3D.new()
			cyl.radius = (1.0 if kind == "tree" else 1.7) * s * k
			cyl.height = (8.0 if kind == "tree" else 6.0) * s * k
			cs.shape = cyl
			cs.position = Vector3(p[0], p[1] + cyl.height / 2, p[2])
		else:
			var sph := SphereShape3D.new()
			sph.radius = 0.8 * s * (clampf(p[5] / 0.7, 0.6, 1.0) if kind == "rock" else 1.0)
			cs.shape = sph
			cs.position = Vector3(p[0], p[1] + (0.4 * s if kind == "bush" else 0.0), p[2])
		body.add_child(cs)


# ---------- Herbe et fleurs (seulement pour le décor, n'arrêtent pas les balles) ----------
func _grass() -> void:
	# Deux petites textures décrivent le sol : la hauteur et où pousse l'herbe.
	var w := SEG + 1
	var hmap := ImageTexture.create_from_image(Image.create_from_data(w, w, false, Image.FORMAT_RF, heights.to_byte_array()))
	var mtex := ImageTexture.create_from_image(Image.create_from_data(w, w, false, Image.FORMAT_RGBA8, _grass_mask))
	var fields := [
		# [forme, teinte, canal du masque, densité, touffes par m², vent, garder les normales, taille min, taille max, aplatissement]
		[VEG.tuft(0.9, 0.55), Color("#f2f7e6"), 0, 1.0, 1.6, 0.12, false, 0.8, 1.4, 1.0, "vege_herbe.png"],
		[VEG.tuft(0.8, 0.5), Color.WHITE, 1, 0.6, 0.07, 0.08, false, 0.9, 1.3, 1.0, "vege_fleurs.png"],
		# Feuillages Higgsfield : gazon ras sur l'herbe, fougères en forêt, bruyère entre les rochers.
		[VEG.tuft(0.9, 0.3), Color("#e8eedc"), 0, 1.0, 0.35, 0.06, false, 0.8, 1.3, 1.0, "vege_gazon.png", Vector2(0.75, 2.0)],
		[VEG.tuft(1.1, 0.75), Color.WHITE, 0, 1.0, 0.18, 0.05, false, 0.8, 1.4, 1.0, "vege_fougere.png", Vector2(0.3, 0.65)],
		[VEG.tuft(1.0, 0.55), Color.WHITE, 2, 0.5, 0.15, 0.04, false, 0.8, 1.3, 1.0, "vege_bruyere.png", Vector2(0.6, 2.0)],
		[_pebble_mesh, Color("#4a4742"), 2, 1.0, 0.3, 0.0, true, 0.08, 0.36, 0.42],   # graviers sombres et plats, comme la roche
		[_pebble_mesh, Color("#f4f8fc"), 3, 1.0, 0.12, 0.0, true, 0.3, 1.0, 0.35],
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
		if f.size() > 10:
			m.set_shader_parameter("albedo_tex", load("res://art/" + f[10]))
			m.set_shader_parameter("use_tex", true)
		if f.size() > 11:
			m.set_shader_parameter("mask_range", f[11])
		# Touffes réparties au hasard dans un carré autour de la caméra.
		var count := int(4 * GRASS_RADIUS * GRASS_RADIUS * f[4])
		var xforms := []
		for i in count:
			var s: float = lerpf(f[7], f[8], rng.randf())
			var pos := Vector3((rng.randf() * 2 - 1) * GRASS_RADIUS, 0, (rng.randf() * 2 - 1) * GRASS_RADIUS)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * f[9], s)), pos))
		var mmi := _multimesh(f[0], m, xforms)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-S, -50, -S), Vector3(2 * S, 450, 2 * S))   # le champ peut être partout autour de la caméra
		_grass_fields.append(mmi)

func update_grass(cam: Vector3) -> void:
	# Le champ reste en place ; le shader recycle autour de la caméra les touffes trop éloignées.
	for f in _grass_fields:
		(f.material_override as ShaderMaterial).set_shader_parameter("cam_pos", cam)


# ---------- Personnages ----------
const CAMO_SHADER := preload("res://shaders/camo.gdshader")

# ---------- Le sniper ----------
# Modèle 3D du sniper sans arme et fusil dans le dos (créés avec Higgsfield, sources/), animés avec les animations
# de la « Universal Animation Library » de Quaternius (CC0) : art/sniper_anime.scn, préparé par tools/sniper_anime.gd
# (qui ajuste le squelette des animations au modèle et fabrique aussi la position couchée). Chaque sommet garde sa position « debout » (CUSTOM0) :
# la peinture suit le corps dans toutes les poses.
const FIG_SCENE := preload("res://art/sniper_anime.scn")
const MODEL_TEX := preload("res://art/sniper_couleur.jpg")
const MODEL_LUM := 0.051          # luminance moyenne de la texture (linéaire), pour garder ses plis sous la peinture
# Animations de chaque posture : [nom, vitesse au sol (m/s) à vitesse normale de l'animation] ; la première est à l'arrêt.
const FIG_ANIMS := {
	"debout": [["Idle_Loop", 0.0], ["Walk_Loop", 1.05], ["Jog_Fwd_Loop", 3.6], ["Sprint_Loop", 6.2]],
	"accroupi": [["Crouch_Idle_Loop", 0.0], ["Crouch_Fwd_Loop", 0.75]],
	"couche": [["Prone_Idle_Loop", 0.0], ["Prone_Crawl_Loop", 0.8]],
}
const FIG_HOLD := 0.4             # moment de l'animation à l'arrêt montré quand la pose est figée (atelier)

func _make_figure() -> Node3D:
	var g := Node3D.new()
	var camo := ShaderMaterial.new()
	camo.shader = CAMO_SHADER
	camo.set_shader_parameter("base_color", ZONES["roche"]["color"])
	camo.set_shader_parameter("albedo_tex", MODEL_TEX)
	camo.set_shader_parameter("avg_lum", MODEL_LUM)
	var inst: Node3D = FIG_SCENE.instantiate()
	g.add_child(inst)
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	mi.material_override = camo
	g.set_meta("camo", camo)
	g.set_meta("mesh", mi)
	g.set_meta("skel", mi.get_node(mi.skeleton))
	g.set_meta("anim", inst.find_children("*", "AnimationPlayer", true, false)[0])
	g.set_meta("stance", "debout")
	return g

## Posture figée (atelier de peinture) ou vivante (live : l'animation à l'arrêt tourne, respiration).
func set_stance(fig: Node3D, stance: String, live := false) -> void:
	fig.set_meta("stance", stance)
	var ap: AnimationPlayer = fig.get_meta("anim")
	var anim: String = FIG_ANIMS[stance][0][0]
	ap.speed_scale = 1.0
	if live:
		ap.play(anim, 0.25)
		return
	ap.play(anim, 0.0)
	ap.seek(FIG_HOLD, true)
	ap.pause()

## Pendant la cachette : l'animation suit la posture et la vitesse (m/s), pieds calés sur le sol.
func animate_figure(fig: Node3D, stance: String, speed: float) -> void:
	fig.set_meta("stance", stance)
	var ap: AnimationPlayer = fig.get_meta("anim")
	var list: Array = FIG_ANIMS[stance]
	var pick: Array = list[0]
	var scale := 1.0
	if speed > 0.25:
		var best := INF
		for a in list.slice(1):
			var d := absf(log(speed / a[1]))
			if d < best:
				best = d
				pick = a
		scale = clampf(speed / pick[1], 0.6, 2.4)
	ap.speed_scale = scale
	if ap.current_animation != pick[0] or not ap.is_playing():
		# Même moment de la foulée d'une allure à l'autre : les pieds ne sautent pas.
		var t := 0.0
		if ap.is_playing() and ap.current_animation_length > 0.0 and ap.current_animation != list[0][0]:
			t = ap.current_animation_position / ap.current_animation_length
		ap.play(pick[0], 0.25)
		if t > 0.0:
			ap.seek(t * ap.current_animation_length)

## Saut du personnage (impulsion, en l'air, réception), avec un fondu court.
func play_jump(fig: Node3D, anim: String, blend: float, speed: float) -> void:
	var ap: AnimationPlayer = fig.get_meta("anim")
	ap.speed_scale = speed
	ap.play(anim, blend)

## Le perdant tombe.
func fall(fig: Node3D) -> void:
	var ap: AnimationPlayer = fig.get_meta("anim")
	ap.speed_scale = 1.0
	ap.play("Death01", 0.15)

## Positions des sommets dans la pose affichée (repère du personnage), calculées comme la carte graphique.
func _skinned(fig: Node3D) -> PackedVector3Array:
	var mi: MeshInstance3D = fig.get_meta("mesh")
	var sk: Skeleton3D = fig.get_meta("skel")
	var a := _fig_arrays(fig)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var to_fig := Transform3D.IDENTITY
	var n: Node = mi
	while n != fig:
		to_fig = (n as Node3D).transform * to_fig
		n = n.get_parent()
	sk.force_update_all_bone_transforms()
	var mats: Array[Transform3D] = []
	for b in mi.skin.get_bind_count():
		mats.append(to_fig * sk.get_bone_global_pose(mi.skin.get_bind_bone(b)) * mi.skin.get_bind_pose(b))
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in verts.size():
		var p := Vector3.ZERO
		for j in 4:
			var w := weights[i * 4 + j]
			if w > 0.0:
				p += (mats[bones[i * 4 + j]] * verts[i]) * w
		out[i] = p
	return out

var _arrays_cache := {}
func _fig_arrays(fig: Node3D) -> Array:
	var mesh: Mesh = (fig.get_meta("mesh") as MeshInstance3D).mesh
	if not _arrays_cache.has(mesh):
		_arrays_cache[mesh] = mesh.surface_get_arrays(0)
	return _arrays_cache[mesh]

## D'où part l'éclair du tir, dans le monde : devant la tête du tireur (le fusil est dans son dos).
func muzzle(fig: Node3D) -> Vector3:
	var sk: Skeleton3D = fig.get_meta("skel")
	sk.force_update_all_bone_transforms()
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	return head + fig.global_transform.basis.z.normalized() * 0.45

func pick_part(fig: Node3D, from: Vector3, dir: Vector3) -> Dictionary:
	# Rayon de la souris contre le corps (dans la pose affichée, figée pendant l'atelier).
	# Renvoie le point touché dans le repère « debout », celui de la peinture.
	var ap: AnimationPlayer = fig.get_meta("anim")
	var key := "%s@%.3f" % [ap.assigned_animation, ap.current_animation_position]
	var cache: Array = fig.get_meta("pick_cache", [])
	if cache.is_empty() or cache[0] != key or ap.is_playing():
		var posed := _skinned(fig)
		var idx: PackedInt32Array = _fig_arrays(fig)[Mesh.ARRAY_INDEX]
		var faces := PackedVector3Array()
		faces.resize(idx.size())
		for i in idx.size():
			faces[i] = posed[idx[i]]
		var tm := TriangleMesh.new()
		tm.create_from_faces(faces)
		cache = [key, posed, tm]
		fig.set_meta("pick_cache", cache)
	var inv := fig.global_transform.affine_inverse()
	var hit: Dictionary = (cache[2] as TriangleMesh).intersect_ray(inv * from, (inv.basis * dir).normalized())
	if hit.is_empty():
		return {}
	var a := _fig_arrays(fig)
	var ref: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var posed: PackedVector3Array = cache[1]
	var f: int = hit["face_index"]
	var i0 := idx[f * 3]
	var i1 := idx[f * 3 + 1]
	var i2 := idx[f * 3 + 2]
	var bc := Geometry3D.get_triangle_barycentric_coords(hit["position"], posed[i0], posed[i1], posed[i2])
	var r := Vector3.ZERO
	for c in 3:
		var i: int = [i0, i1, i2][c]
		r += Vector3(ref[i * 4], ref[i * 4 + 1], ref[i * 4 + 2]) * bc[c]
	return {"ref": r, "world": fig.global_transform * (hit["position"] as Vector3)}

## Tenue de feuillage (« ghillie ») : des touffes d'herbe accrochées sur les épaules, le dos, la capuche, les bras et
## les jambes ; elles suivent les os du corps. Teinte de la tenue choisie ; sans effacement près de la caméra.
const GHILLIE_TEX := preload("res://art/vege_herbe.png")

func set_ghillie(fig: Node3D, on: bool, tint: Color) -> void:
	if not fig.has_meta("ghillie"):
		if not on:
			return
		fig.set_meta("ghillie", _make_ghillie(fig))
	var g: MeshInstance3D = fig.get_meta("ghillie")
	g.visible = on
	(g.material_override as ShaderMaterial).set_shader_parameter("tint", tint.lerp(Color.WHITE, 0.25))

func _make_ghillie(fig: Node3D) -> MeshInstance3D:
	var body: MeshInstance3D = fig.get_meta("mesh")
	var a := _fig_arrays(fig)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var we: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pb := PackedInt32Array()
	var pw := PackedFloat32Array()
	var idx := PackedInt32Array()
	var placed := 0
	while placed < 260:
		var i := r.randi() % v.size()
		var p := v[i]
		var n := nr[i]
		# Sur le dessus et les côtés du corps (pas sous les pieds, ni sur le visage).
		if p.y < 0.25 or n.y < -0.4 or (p.y > 1.45 and p.y < 1.68 and n.z > 0.55):
			continue
		placed += 1
		var down := (Vector3.DOWN * 0.7 + n * 0.5 + Vector3(r.randfn(), 0, r.randfn()) * 0.15).normalized()
		var length := r.randf_range(0.16, 0.3)
		var width := r.randf_range(0.1, 0.16)
		for k in 2:
			var side := n.cross(down).normalized().rotated(down, k * PI / 2)
			var base := p + n * 0.01
			var first := pv.size()
			var corners := [base - side * width * 0.5, base + side * width * 0.5, base + side * width * 0.5 + down * length, base - side * width * 0.5 + down * length]
			var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]   # pied des brins accroché au corps
			for q in 4:
				pv.append(corners[q])
				pn.append(n)
				puv.append(uvs[q])
				for j in 4:
					pb.append(bo[i * 4 + j])
					pw.append(we[i * 4 + j])
			idx.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pv
	arr[Mesh.ARRAY_NORMAL] = pn
	arr[Mesh.ARRAY_TEX_UV] = puv
	arr[Mesh.ARRAY_BONES] = pb
	arr[Mesh.ARRAY_WEIGHTS] = pw
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("albedo_tex", GHILLIE_TEX)
	m.set_shader_parameter("alpha_cut", 0.4)
	m.set_shader_parameter("translucency", 0.3)
	m.set_shader_parameter("wind", 0.0)
	m.set_shader_parameter("near_fade", 0.0)
	var g := MeshInstance3D.new()
	g.mesh = mesh
	g.skin = body.skin
	g.material_override = m
	body.get_parent().add_child(g)
	g.skeleton = NodePath("..")
	return g

## Points répartis sur tout le corps (pose debout), pour mesurer le camouflage.
func figure_samples() -> Array[Vector3]:
	var a := _fig_arrays(player)
	var ref: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var verts := PackedVector3Array()
	verts.resize(ref.size() / 4)
	for i in verts.size():
		verts[i] = Vector3(ref[i * 4], ref[i * 4 + 1], ref[i * 4 + 2])
	var areas := PackedFloat32Array()
	var total := 0.0
	for f in idx.size() / 3:
		total += (verts[idx[f * 3 + 1]] - verts[idx[f * 3]]).cross(verts[idx[f * 3 + 2]] - verts[idx[f * 3]]).length() / 2
		areas.append(total)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var out: Array[Vector3] = []
	for i in 2400:
		var f := areas.bsearch(r.randf() * total)
		var u := r.randf()
		var v := r.randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var p0 := verts[idx[f * 3]]
		out.append(p0 + (verts[idx[f * 3 + 1]] - p0) * u + (verts[idx[f * 3 + 2]] - p0) * v)
	return out

func set_camo(fig: Node3D, zone: String) -> void:
	# Tenue unie (l'ennemi) : la couleur du terrain, sans coups de pinceau.
	var m: ShaderMaterial = fig.get_meta("camo")
	m.set_shader_parameter("base_color", ZONES[zone]["color"])
	m.set_shader_parameter("stroke_count", 0)
	m.set_shader_parameter("tex_mix", 0.0)


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
