@tool
class_name RoomDoor
extends Area2D
## Puerta de una sala. Ponela en la escena de la sala (puerta.tscn) y movela donde quieras:
## el RunManager la abre o la cierra solo, según si del otro lado hay una sala.
##  - Abierta: al tocarla el jugador pasa a la sala vecina (en la dirección `side`).
##  - Cerrada: se vuelve una pared sólida (así el hueco de la pared queda tapado).
##
## Al entrar a una sala, el jugador aparece en `entry_offset` de la puerta contraria
## (si cruzó hacia la derecha, aparece en la puerta izquierda de la sala nueva).
## En el editor se ve la zona y, con la puerta seleccionada, el punto de aparición.

## Se emite cuando el jugador toca una puerta abierta
signal player_entered(door: RoomDoor)

enum Side { LEFT, RIGHT, UP, DOWN }

## Hacia dónde lleva esta puerta
@export var side: RoomDoor.Side = Side.LEFT:
	set(value):
		side = value
		queue_redraw()
## Tamaño de la zona de la puerta (centrada en el nodo)
@export var size: Vector2 = Vector2(64, 256):
	set(value):
		size = value
		_apply_size()
## Dónde aparece el jugador al llegar por esta puerta (relativo a la puerta)
@export var entry_offset: Vector2 = Vector2(150, 58):
	set(value):
		entry_offset = value
		queue_redraw()
## Abierta (pasa a la otra sala) o cerrada (pared). Lo cambia el RunManager.
@export var open: bool = true:
	set(value):
		open = value
		_apply_open()
@export var closed_color: Color = Color(0.3, 0.24, 0.3)


func _ready() -> void:
	_apply_size()
	_apply_open()
	if Engine.is_editor_hint():
		return
	add_to_group("room_doors")
	body_entered.connect(_on_body_entered)


## Dirección en la grilla (LEFT = (-1,0), RIGHT = (1,0), UP = (0,-1), DOWN = (0,1))
func direction() -> Vector2i:
	match side:
		Side.LEFT: return Vector2i.LEFT
		Side.RIGHT: return Vector2i.RIGHT
		Side.UP: return Vector2i.UP
	return Vector2i.DOWN


## Posición global donde aparece el jugador al llegar por esta puerta
func entry_position() -> Vector2:
	return to_global(entry_offset)


func _on_body_entered(body: Node) -> void:
	if open and body.is_in_group("players"):
		player_entered.emit(self)


func _apply_size() -> void:
	var zone := get_node_or_null("Zona") as CollisionShape2D
	var seal := get_node_or_null("Cierre/Forma") as CollisionShape2D
	for col in [zone, seal]:
		if col != null and col.shape is RectangleShape2D:
			(col.shape as RectangleShape2D).size = size
	queue_redraw()


func _apply_open() -> void:
	var seal := get_node_or_null("Cierre/Forma") as CollisionShape2D
	if seal != null:
		seal.set_deferred("disabled", open)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	if open:
		draw_rect(rect, Color(0.95, 0.8, 0.3, 0.28))
		draw_rect(rect, Color(0.95, 0.8, 0.3, 0.8), false, 2.0)
	else:
		draw_rect(rect, closed_color)
	if Engine.is_editor_hint():
		# Punto de aparición del jugador
		draw_line(Vector2.ZERO, entry_offset, Color(0.3, 1, 0.5, 0.7), 2.0)
		draw_circle(entry_offset, 10.0, Color(0.3, 1, 0.5, 0.9))
