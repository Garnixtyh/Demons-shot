@tool
extends StaticBody2D
## Plataforma estática de un solo sentido (capa 3).
## Se puede subir desde abajo y bajar con S (lo maneja el jugador).
## Cambiá `size` en el Inspector para estirarla: el collider y el dibujo se ajustan solos.

@export var size: Vector2 = Vector2(256, 24):
	set(value):
		size = value
		_refresh()
@export var color: Color = Color(0.55, 0.4, 0.25):
	set(value):
		color = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var rect := RectangleShape2D.new()  # propio de cada instancia
	rect.size = size
	var collision_shape := $CollisionShape2D as CollisionShape2D
	collision_shape.shape = rect
	collision_shape.one_way_collision = true
	collision_shape.one_way_collision_margin = 8.0
	var half := size / 2.0
	var visual := $Visual as Polygon2D
	visual.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	visual.color = color
