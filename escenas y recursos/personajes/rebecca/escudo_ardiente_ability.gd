extends "../../abilities/ability.gd"
## Habilidad de Rebecca con la mejora "Protección ardiente" (reemplaza a Lanzar orbes).
## Escudo de invencibilidad con más velocidad. Mientras dura NO puede atacar.
## Al terminar se apagan todos sus orbes.

## Segundos de escudo
@export var shield_time: float = 3.0
## Multiplicador de velocidad mientras dura
@export var speed_multiplier: float = 1.5
@export var recarga: float = 12.0

var _active: bool = false
var _base_speed: float = 0.0


func _init() -> void:
	ability_name = "Protección ardiente"
	cooldown = recarga


func _activate() -> void:
	player.start_shield(shield_time)
	_base_speed = player.max_speed
	player.max_speed = _base_speed * speed_multiplier
	_active = true


func _process(delta: float) -> void:
	super(delta)
	if _active and not player.is_shielded():
		_finish()


func _finish() -> void:
	_active = false
	player.max_speed = _base_speed
	var passive = player.get_passive()
	if passive != null:
		passive.clear_orbs()


## Si la habilidad se cambia en pleno escudo, devuelve la velocidad normal.
func _exit_tree() -> void:
	if _active and is_instance_valid(player):
		player.max_speed = _base_speed
