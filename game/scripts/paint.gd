extends RefCounted
## La peinture de camouflage du joueur : une couleur de fond et des coups de pinceau
## posés sur le corps. Calcule aussi à quel point le sniper ressemble à chaque terrain.

const MAX := 600                       # même limite que le shader camo
const SIZES := [0.045, 0.09, 0.17]     # rayon du pinceau : petit, moyen, gros
const DEFAULT_BASE := Color("#383127")   # tenue du modèle 3D (couleur moyenne de sa texture)
const PALETTE := [
	Color("#eef3f9"), Color("#c9d3dc"), Color("#b9b2a5"), Color("#928e86"),
	Color("#6d6a64"), Color("#e3d39a"), Color("#a0855c"), Color("#7a5233"),
	Color("#9ccc5a"), Color("#6fae44"), Color("#4c8a34"), Color("#5a6b3a"),
	Color("#3b7a3c"), Color("#2a5530"), Color("#1e2224"), Color("#c0503a"),
]
# Tenues de camouflage (mode normal : on choisit une tenue au lieu de peindre ; la peinture reviendra dans un
# mode à part). Motifs donnés par l'utilisateur (art/camo_*.jpg). [nom, motif, couleur moyenne, camouflage par terrain]
# Tenues (motifs créés avec Higgsfield, 31/10/2026, sources/higgsfield/camouflage/) :
# [nom, motif, couleur moyenne, ressemblance avec chaque terrain].
const OUTFITS := {
	"foret_alpine": ["Forêt alpine", "res://art/camo_foret_alpine.jpg", "#30321e", {"foret": 0.9, "herbe": 0.55, "roche": 0.25, "neige": 0.05}],
	"prairie": ["Prairie", "res://art/camo_prairie.jpg", "#71732b", {"herbe": 0.9, "foret": 0.5, "roche": 0.3, "neige": 0.05}],
	"granit": ["Granit", "res://art/camo_granit.jpg", "#65645d", {"roche": 0.9, "neige": 0.4, "herbe": 0.3, "foret": 0.2}],
	"neige_roche": ["Neige et roche", "res://art/camo_neige_roche.jpg", "#cacdd0", {"neige": 0.9, "roche": 0.6, "herbe": 0.1, "foret": 0.05}],
	"multi_alpin": ["Multi-alpin", "res://art/camo_multi_alpin.jpg", "#6e6449", {"foret": 0.65, "herbe": 0.65, "roche": 0.65, "neige": 0.2}],
	"bruyere": ["Bruyère", "res://art/camo_bruyere.jpg", "#75502e", {"herbe": 0.75, "foret": 0.6, "roche": 0.45, "neige": 0.05}],
}
# Tenue de l'ennemi selon le terrain qu'il a choisi.
const ZONE_OUTFIT := {"foret": "foret_alpine", "herbe": "prairie", "roche": "granit", "neige": "neige_roche"}
var outfit := ""   # tenue portée ("" : peinture libre)
# Tenues de feuillage (ghillie) : planches de feuillage Higgsfield ; bonus de ressemblance selon le terrain.
const GHILLIES := {
	"herbes": ["Herbes hautes", "res://art/vege_herbe.png", {"herbe": 0.14, "foret": 0.06, "roche": 0.04, "neige": 0.0}],
	"fougeres": ["Fougères", "res://art/vege_fougere.png", {"foret": 0.14, "herbe": 0.08, "roche": 0.03, "neige": 0.0}],
	"pin": ["Branches de pin", "res://art/vege_pin.png", {"foret": 0.15, "herbe": 0.05, "roche": 0.04, "neige": 0.02}],
	"bruyere": ["Bruyère", "res://art/vege_bruyere.png", {"herbe": 0.1, "roche": 0.1, "foret": 0.06, "neige": 0.0}],
	"lichen": ["Lichen et neige", "res://art/vege_lichen.png", {"neige": 0.14, "roche": 0.12, "herbe": 0.02, "foret": 0.0}],
}
const ZONE_GHILLIE := {"foret": "pin", "herbe": "herbes", "roche": "bruyere", "neige": "lichen"}

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


func _init(mat: ShaderMaterial, body_samples: Array[Vector3]) -> void:
	# body_samples : points répartis sur le corps, dans la pose debout (world.figure_samples()).
	material = mat
	_rng.seed = 7
	samples = body_samples
	_set_default()
	refresh()


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
	_no_outfit()
	base = color
	strokes.clear()
	refresh()

func clear() -> void:
	_snapshot()
	_no_outfit()
	_set_default()
	refresh()

func _no_outfit() -> void:
	outfit = ""
	material.set_shader_parameter("camo_mix", 0.0)

func _set_default() -> void:
	# Tenue de départ : celle du modèle 3D (sa texture), sans peinture. À repeindre pour se camoufler.
	base = DEFAULT_BASE
	strokes = []

## Met une tenue : le motif est plaqué sur tout le corps ; son camouflage par terrain est donné par OUTFITS.
func wear(o: String) -> void:
	outfit = o
	base = Color(OUTFITS[o][2])
	strokes = []
	history.clear()
	material.set_shader_parameter("camo_tex", load(OUTFITS[o][1]))
	material.set_shader_parameter("camo_mix", 1.0)
	refresh()

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
	# Tant que le fond n'a pas été repeint (outil Remplir), on voit la tenue d'origine du modèle.
	material.set_shader_parameter("tex_mix", 1.0 if base == DEFAULT_BASE else 0.0)

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
	if outfit != "":
		return OUTFITS[outfit][3][zone]
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
