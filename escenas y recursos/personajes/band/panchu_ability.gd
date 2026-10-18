extends "../../abilities/ability.gd"
## Habilidad de Band con la mejora "Panchu": suelta a su perro, que persigue
## al enemigo más cercano y le da un cabezazo (daño + aturdimiento).

const PanchuScript := preload("panchu.gd")

@export var damage: float = 40.0
## Segundos que aturde el cabezazo
@export var stun_time: float = 0.5
## Segundos que Panchu anda suelto
@export var duration: float = 8.0
@export var speed: float = 420.0


func _init() -> void:
	ability_name = "Panchu"
	cooldown = 10.0


func _activate() -> void:
	var panchu: CharacterBody2D = PanchuScript.new()
	panchu.owner_player = player
	panchu.damage = damage
	panchu.stun_time = stun_time
	panchu.duration = duration
	panchu.speed = speed
	get_tree().current_scene.add_child(panchu)
	# Nace al lado del jugador, del lado donde apunta el mouse
	var side := 1.0 if player.get_global_mouse_position().x >= player.global_position.x else -1.0
	panchu.global_position = player.global_position + Vector2(side * 60.0, 0.0)
