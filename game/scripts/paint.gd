extends RefCounted
## La peinture de camouflage du joueur : une couleur de fond et des coups de pinceau
## posés sur le corps. Calcule aussi à quel point le sniper ressemble à chaque terrain.

const MAX := 600                       # même limite que le shader camo
const SIZES := [0.045, 0.09, 0.17]     # rayon du pinceau : petit, moyen, gros
const DEFAULT_BASE := Color("#8f8a6c")   # toile kaki
const PALETTE := [
	Color("#eef3f9"), Color("#c9d3dc"), Color("#b9b2a5"), Color("#928e86"),
	Color("#6d6a64"), Color("#e3d39a"), Color("#a0855c"), Color("#7a5233"),
	Color("#9ccc5a"), Color("#6fae44"), Color("#4c8a34"), Color("#5a6b3a"),
	Color("#3b7a3c"), Color("#2a5530"), Color("#1e2224"), Color("#c0503a"),
]
const MATCH_DIST := 0.32               # au-delà de cet écart de couleur, ça ne ressemble plus du tout

var base := DEFAULT_BASE
var strokes: Array = []                # [Vector4(x, y, z, rayon), Color]
var history: Array = []                # états précédents pour « Annuler »
var material: ShaderMaterial
var samples: Array[Vector3] = []       # points répartis sur le corps
var sample_colors: Array[Color] = []
var _last := Vector3.INF
var _rng := RandomNumberGenerator.new()
var _match_cache := {}                 # score par terrain, recalculé seulement quand la peinture change
var _stroke_tex: ImageTexture


func _init(mat: ShaderMaterial, parts: Array, part_transform: Callable) -> void:
	material = mat
	_rng.seed = 7
	_build_samples(parts, part_transform)
	_set_default()
	refresh()

func _build_samples(parts: Array, part_transform: Callable) -> void:
	# Environ 900 points par m² de surface, sur la pose debout.
	for part in parts:
		if part.size() > 5 and part[5] != null:
			continue  # pièce à couleur fixe (fusil) : pas peinte, pas comptée
		var size: Vector3 = part[2]
		var t: Transform3D = part_transform.call(part, "debout")
		var area := 0.0
		match part[1]:
			"box":
				area = 2 * (size.x * size.y + size.y * size.z + size.x * size.z)
			"sphere", "capsule":
				area = 4 * PI * size.x * size.x + (TAU * size.x * (size.y - 2 * size.x) if part[1] == "capsule" else 0.0)
			_:
				area = TAU * size.x * size.y
		for i in maxi(4, int(area * 900)):
			var p := Vector3.ZERO
			match part[1]:
				"box":
					p = Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * size
					var axis := _rng.randi() % 3
					p[axis] = size[axis] / 2 * (1 if _rng.randf() < 0.5 else -1)
				"sphere":
					p = Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()).normalized() * size.x
				"capsule":
					var hh: float = size.y / 2 - size.x
					var side := TAU * size.x * 2 * hh
					if _rng.randf() * area < side:
						var a := _rng.randf() * TAU
						p = Vector3(cos(a) * size.x, _rng.randf_range(-hh, hh), sin(a) * size.x)
					else:
						p = Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()).normalized() * size.x
						p.y += hh if p.y > 0 else -hh
				_:
					var a := _rng.randf() * TAU
					p = Vector3(cos(a) * size.x, (_rng.randf() - 0.5) * size.y, sin(a) * size.x)
			samples.append(t * p)

func color_at(p: Vector3) -> Color:
	var c := base
	for s in strokes:
		var v: Vector4 = s[0]
		if p.distance_to(Vector3(v.x, v.y, v.z)) < v.w:
			c = s[1]
	return c


# ---------- Pinceau ----------
func _snapshot() -> void:
	history.append([base, strokes.duplicate()])
	if history.size() > 40:
		history.pop_front()

func begin() -> void:
	_snapshot()
	_last = Vector3.INF

func is_full() -> bool:
	return strokes.size() >= MAX

func dab(ref: Vector3, color: Color, size_idx: int, tool: String) -> void:
	var r: float = SIZES[size_idx]
	if tool == "taches":
		# Une tache = un petit groupe de boules irrégulières.
		if _last.distance_to(ref) < r * 2.2:
			return
		_last = ref
		for i in 6:
			var off := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()) * r * 0.55
			_add(ref + off, r * _rng.randf_range(0.45, 0.9), color)
	else:
		if _last.distance_to(ref) < r * 0.35:
			return
		_last = ref
		_add(ref, r, color)
	_apply()

func _add(p: Vector3, r: float, color: Color) -> void:
	if is_full():
		return
	strokes.append([Vector4(p.x, p.y, p.z, r), color])
	_match_cache.clear()
	for i in samples.size():
		if samples[i].distance_to(p) < r:
			sample_colors[i] = color

func fill(color: Color) -> void:
	_snapshot()
	base = color
	strokes.clear()
	refresh()

func clear() -> void:
	_snapshot()
	_set_default()
	refresh()

func _set_default() -> void:
	# Tenue de départ : toile kaki, capuche et gilet plus foncés, visage, bottes. À repeindre pour se camoufler.
	base = DEFAULT_BASE
	strokes = [
		[Vector4(0, 1.71, -0.04, 0.215), Color("#77744f")],   # capuche
		[Vector4(0, 1.665, 0.19, 0.16), Color("#e2b48a")],    # visage (après la capuche : il reste visible)
		[Vector4(-0.12, 0.82, 0, 0.19), Color("#7a7457")],     # pantalon
		[Vector4(0.12, 0.82, 0, 0.19), Color("#7a7457")],
		[Vector4(-0.12, 0.62, 0, 0.19), Color("#7a7457")],
		[Vector4(0.12, 0.62, 0, 0.19), Color("#7a7457")],
		[Vector4(-0.12, 0.42, 0, 0.19), Color("#7a7457")],
		[Vector4(0.12, 0.42, 0, 0.19), Color("#7a7457")],
		[Vector4(-0.12, 0.22, 0, 0.19), Color("#7a7457")],
		[Vector4(0.12, 0.22, 0, 0.19), Color("#7a7457")],
		[Vector4(-0.12, 0.07, 0.05, 0.21), Color("#3b2e25")],  # bottes
		[Vector4(0.12, 0.07, 0.05, 0.21), Color("#3b2e25")],
		[Vector4(0, 1.25, -0.27, 0.3), Color("#5e5a45")],     # sac et tapis
	]

func undo() -> void:
	if history.is_empty():
		return
	var h: Array = history.pop_back()
	base = h[0]
	strokes = h[1]
	refresh()

func refresh() -> void:
	_match_cache.clear()
	sample_colors.resize(samples.size())
	for i in samples.size():
		sample_colors[i] = color_at(samples[i])
	_apply()

func _apply() -> void:
	# Les coups vont dans une petite image MAX × 2 lue par le shader camo.
	var data := PackedFloat32Array()
	data.resize(MAX * 2 * 4)
	for i in strokes.size():
		var v: Vector4 = strokes[i][0]
		var c: Color = strokes[i][1]
		var a := i * 4
		var b := (MAX + i) * 4
		data[a] = v.x
		data[a + 1] = v.y
		data[a + 2] = v.z
		data[a + 3] = v.w
		data[b] = c.r
		data[b + 1] = c.g
		data[b + 2] = c.b
		data[b + 3] = 1.0
	var img := Image.create_from_data(MAX, 2, false, Image.FORMAT_RGBAF, data.to_byte_array())
	if _stroke_tex == null:
		_stroke_tex = ImageTexture.create_from_image(img)
		material.set_shader_parameter("stroke_tex", _stroke_tex)
	else:
		_stroke_tex.update(img)
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("stroke_count", strokes.size())

func set_cursor(ref: Vector3, size_idx: int) -> void:
	material.set_shader_parameter("cursor", Vector4(ref.x, ref.y, ref.z, SIZES[size_idx]))

func hide_cursor() -> void:
	material.set_shader_parameter("cursor", Vector4(0, 0, 0, -1))


# ---------- Ressemblance avec le terrain ----------
# Chaque terrain a ses teintes : claire, normale, à l'ombre.
const ZONE_PALETTES := {
	"neige": [Color("#eef3f9"), Color("#c9d3dc")],
	"roche": [Color("#928e86"), Color("#b9b2a5"), Color("#6d6a64")],
	"herbe": [Color("#6fae44"), Color("#9ccc5a"), Color("#4c8a34")],
	"foret": [Color("#3b7a3c"), Color("#2a5530"), Color("#5a6b3a")],
}
const PATTERN_BONUS := 0.12   # motif d'au moins deux teintes du terrain : la silhouette se « casse »

func match_zone(zone: String) -> float:
	# 1 = le sniper se fond complètement dans ce terrain, 0 = rien à voir.
	if _match_cache.has(zone):
		return _match_cache[zone]
	var pal: Array = ZONE_PALETTES[zone]
	var total := 0.0
	var used := []
	used.resize(pal.size())
	used.fill(0)
	for c in sample_colors:
		var best := 0.0
		var best_i := 0
		for i in pal.size():
			var p: Color = pal[i]
			var s := clampf(1.0 - Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length() / MATCH_DIST, 0.0, 1.0)
			if s > best:
				best = s
				best_i = i
		total += best
		if best > 0.6:
			used[best_i] += 1
	var n := maxi(1, sample_colors.size())
	var score := total / n
	if used.filter(func(u): return u > n * 0.15).size() >= 2:
		score += PATTERN_BONUS
	score = clampf(score, 0.0, 1.0)
	_match_cache[zone] = score
	return score

func has_pattern(zone: String) -> bool:
	var before := match_zone(zone)
	return before > 0 and _raw(zone) < before

func _raw(zone: String) -> float:
	var pal: Array = ZONE_PALETTES[zone]
	var total := 0.0
	for c in sample_colors:
		var best := 0.0
		for p in pal:
			best = maxf(best, clampf(1.0 - Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length() / MATCH_DIST, 0.0, 1.0))
		total += best
	return total / maxi(1, sample_colors.size())
