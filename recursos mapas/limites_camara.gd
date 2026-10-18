@tool
extends Node2D
## Define el área hasta donde puede llegar la cámara del jugador.
## Poné UNA instancia en el mapa: la esquina superior izquierda es la posición
## del nodo y `size` es el ancho y alto del área. La cámara nunca muestra
## nada fuera de ese rectángulo.

@export var size: Vector2 = Vector2(1928, 1032):
	set(value):
		size = value
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("camera_bounds")


## Rectángulo en coordenadas globales (lo usa el jugador)
func get_rect_global() -> Rect2:
	return Rect2(global_position, size * global_scale)


## Solo se dibuja en el editor, para ver el área
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.9, 1.0, 0.9), false, 4.0)
