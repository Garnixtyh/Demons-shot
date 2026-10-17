extends "ability.gd"
## Habilidad de ejemplo (template): lanza una bola de fuego grande hacia el mouse.

const FireballScript := preload("fireball.gd")

@export var damage: float = 60.0
@export var speed: float = 520.0
## Tamaño de la bola (radio en píxeles)
@export var radius: float = 28.0
## Segundos que viaja antes de apagarse
@export var lifetime: float = 2.5


func _init() -> void:
	ability_name = "Bola de fuego"
	cooldown = 6.0


func _activate() -> void:
	var weapon: Node = player.get_weapon()
	var direction: Vector2 = weapon.aim_direction
	var origin: Vector2 = weapon.muzzle.global_position

	var fireball: Area2D = FireballScript.new()
	# Las propiedades se asignan antes de agregarla a la escena
	fireball.direction = direction
	fireball.speed = speed
	fireball.damage = damage
	fireball.radius = radius
	fireball.lifetime = lifetime
	fireball.shooter = player
	get_tree().current_scene.add_child(fireball)
	# Nace un poco adelante para no pegarse al jugador
	fireball.global_position = origin + direction * radius
