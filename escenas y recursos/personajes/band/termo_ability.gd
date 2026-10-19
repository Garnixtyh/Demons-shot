extends "../../abilities/ability.gd"
## Habilidad de Band (E): lanza un termo explosivo hacia el mouse.
## El termo es una escena propia (termo_explosivo.tscn): ahí se le pone el sprite
## y se ajusta la mecha, el daño y el radio.

const TermoScene := preload("termo_explosivo.tscn")

## Velocidad del lanzamiento
@export var throw_speed: float = 750.0
## Impulso extra hacia arriba (para que salga en arco)
@export var upward_boost: float = 150.0


func _init() -> void:
	ability_name = "Termo explosivo"
	cooldown = 8.0


func _activate() -> void:
	var weapon: Node = player.get_weapon()
	var thermos := TermoScene.instantiate() as RigidBody2D
	thermos.owner_player = player
	get_tree().current_scene.add_child(thermos)
	thermos.global_position = weapon.muzzle.global_position
	# No choca con quien lo lanza
	thermos.add_collision_exception_with(player)
	thermos.linear_velocity = weapon.aim_direction * throw_speed \
			+ Vector2(0.0, -upward_boost) + player.velocity * 0.5
	thermos.angular_velocity = randf_range(-6.0, 6.0)
