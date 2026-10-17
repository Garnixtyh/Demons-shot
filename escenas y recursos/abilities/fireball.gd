extends Area2D
## Bola de fuego: proyectil grande dibujado por código (no usa imágenes).
## Daña lo primero que toca (si tiene take_damage) y desaparece.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var damage: float = 60.0
var radius: float = 28.0
var lifetime: float = 2.5
## Quien la lanzó; la bola lo ignora
var shooter: Node = null

var _age: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	z_index = 20
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.08 * sin(_age * 20.0)
	draw_circle(Vector2.ZERO, radius * pulse, Color(1.0, 0.35, 0.05, 0.45))
	draw_circle(Vector2.ZERO, radius * 0.75 * pulse, Color(1.0, 0.55, 0.1, 0.8))
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1.0, 0.9, 0.4, 1.0))


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
