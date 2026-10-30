extends "../../abilities/ability.gd"
## Habilidad de Rebecca (E): lanza en línea recta, hacia el mouse, TODOS los orbes que tenga
## en ese momento. Se queda sin ninguno (hay que volver a conectar el fuego para generar más).
## Sin orbes no se puede usar (y no gasta recarga).

@export var recarga: float = 6.0


func _init() -> void:
	ability_name = "Lanzar orbes"
	cooldown = recarga


func can_activate() -> bool:
	var passive = player.get_passive()
	return super() and passive != null and passive.orb_count() > 0


func _activate() -> void:
	var direction: Vector2 = player.get_weapon().aim_direction
	for orb in player.get_passive().take_all_orbs():
		if is_instance_valid(orb):
			orb.launch(direction)
