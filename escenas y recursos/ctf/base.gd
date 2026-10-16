extends Area2D
## Base de un equipo. Hace dos cosas:
## - Es donde reaparecen los jugadores de ese equipo.
## - Si un jugador de este equipo entra llevando una bandera enemiga, suma el punto.

const TEAM_COLORS := [Color(0.9, 0.2, 0.2, 0.3), Color(0.2, 0.45, 0.95, 0.3)]

@export_enum("Rojo", "Azul") var team: int = 0
## Desplazamiento del punto de reaparición respecto del centro de la base
@export var spawn_offset: Vector2 = Vector2(0, -10)

@onready var _rect: ColorRect = $ColorRect


func _ready() -> void:
	add_to_group("bases")
	_rect.color = TEAM_COLORS[team]


func get_spawn_position() -> Vector2:
	return global_position + spawn_offset


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("players"):
			continue
		if body.is_dead or body.team != team or body.carried_flag == null:
			continue
		body.carried_flag.capture()
