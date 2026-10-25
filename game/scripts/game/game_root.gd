extends Node3D
## Racine de la partie (Milestone 1) : l'arène, un joueur, l'aide des commandes.
## Les manches, le duel et le réseau viendront aux milestones suivants.

@export var config: GameConfig

@onready var arena: Node3D = $IslandArena
@onready var player: CharacterBody3D = $Player
@onready var help: Label = $UI/Help
@onready var status: Label = $UI/Status

var side := 0   # 0 : île A (bleue), 1 : île B (corail)


func _ready() -> void:
	player.fell_in_water.connect(func(): _flash("Plouf ! Retour au point d'apparition."))
	_place_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# L'aide des commandes s'efface au bout de quelques secondes (F1 pour la revoir).
	get_tree().create_timer(10.0).timeout.connect(func(): help.visible = false)

func _place_player() -> void:
	player.accent_color = arena.accent_a if side == 0 else arena.accent_b
	player.respawn_at(arena.spawn_transform(side))
	_flash("Île %s" % ["A (bleue)", "B (corail)"][side])

func _flash(msg: String) -> void:
	status.text = msg
	status.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(status, "modulate:a", 0.0, 0.4)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("toggle_help"):
		help.visible = not help.visible
	elif e.is_action_pressed("debug_switch_island"):
		# Outil de test : passer d'une île à l'autre pour vérifier qu'elles sont identiques.
		side = 1 - side
		_place_player()
