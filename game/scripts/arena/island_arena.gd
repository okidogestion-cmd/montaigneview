extends Node3D
## L'arène « Le Lagon des Deux Fanions » : deux îles identiques face à face,
## le lagon, le ciel et la lumière de fin d'après-midi.
## Ne gère que le décor et les points d'apparition (pas les règles de victoire).

const IslandHalf := preload("res://scenes/arena/island_half.tscn")

@export var config: GameConfig
@export var accent_a := Color("#347BC1")   ## bleu outremer
@export var accent_b := Color("#E96C52")   ## corail

var island_a: Node3D
var island_b: Node3D


func _ready() -> void:
	var half := config.island_distance / 2.0
	# Île A au sud, regarde vers +Z ; île B au nord, tournée de 180°.
	island_a = _island(Vector3(0, 0, -half), 0.0, accent_a, 1)
	island_b = _island(Vector3(0, 0, half), PI, accent_b, 2)
	_build_water(half)
	# Soleil de fin d'après-midi, de côté : aucun des deux joueurs ne l'a dans les yeux.
	$Sun.look_at_from_position(Vector3(-100, 62, 0), Vector3.ZERO)

func _island(pos: Vector3, turn: float, accent: Color, seed: int) -> Node3D:
	var isl: Node3D = IslandHalf.instantiate()
	isl.accent_color = accent
	isl.decor_seed = seed
	isl.position = pos
	isl.rotation.y = turn
	add_child(isl)
	return isl

func _build_water(half: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/lagoon.gdshader")
	m.set_shader_parameter("island_a", Vector3(0, 0, -half))
	m.set_shader_parameter("island_b", Vector3(0, 0, half))
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.material_override = m
	water.position.y = config.water_level
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func spawn_transform(side: int) -> Transform3D:
	return (island_a if side == 0 else island_b).spawn_transform()
