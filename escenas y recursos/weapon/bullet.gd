class_name Bullet
extends Area2D
## Bala: avanza en línea recta, daña lo que tenga take_damage() y desaparece al chocar.

var damage: float = 20.0
var speed: float = 900.0
var lifetime: float = 1.5
## Quien disparó; la bala lo ignora para no dañarse a sí mismo
var shooter: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += transform.x * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
