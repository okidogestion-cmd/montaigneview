class_name GameConfig
extends Resource
## Tous les réglages modifiables du jeu, au même endroit (voir config/game_config.tres).

@export_group("Arène")
@export var island_distance := 90.0       ## distance entre les centres des deux îles (m)
@export var water_level := 0.0            ## hauteur de la mer
@export var fall_respawn_depth := 0.4     ## sous ce niveau de la mer, retour au point d'apparition

@export_group("Déplacement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var crouch_speed := 2.2
@export var acceleration := 28.0
@export var deceleration := 36.0
@export var jump_velocity := 5.2
@export var gravity := 14.0
@export var stand_height := 1.8
@export var crouch_height := 1.15

@export_group("Caméra")
@export var mouse_sensitivity := 0.0025
@export var invert_y := false
@export var camera_distance := 3.6
@export var camera_shoulder := 0.55       ## décalage au-dessus de l'épaule droite
@export var camera_height := 1.55
@export var camera_fov := 70.0
