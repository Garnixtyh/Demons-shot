@tool
class_name Room
extends Node2D
## Una sala de la run (modo un jugador), estilo The Binding of Isaac / NES: una pantalla fija.
##
## Se arma en el editor como cualquier escena: paredes, piso, plataformas de recursos mapas/,
## enemigos, etc. Las salidas son instancias de puerta.tscn (RoomDoor) que ponés donde quieras.
## El origen del nodo es la esquina superior izquierda; en el editor se ve el recuadro celeste
## del área que muestra la cámara.
##
## En mapa_run.tscn cada sala se instancia una vez y se le pone su `grid_coord`.

## Tipo de sala (lo usará el generador procedural para elegir qué escena poner)
@export_enum("main", "treasure", "shop", "normal", "boss") var kind: String = "normal"
@export var room_name: String = "Sala"
## Tamaño de la pantalla de la sala
@export var size: Vector2 = Vector2(1280, 720):
	set(value):
		size = value
		queue_redraw()
## Posición en la grilla del mapa (x a la derecha, y hacia abajo). La sala principal es (0,0).
@export var grid_coord: Vector2i = Vector2i.ZERO


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("run_rooms")


## Puertas que pertenecen a esta sala
func doors() -> Array[RoomDoor]:
	var result: Array[RoomDoor] = []
	for node in get_tree().get_nodes_in_group("room_doors"):
		if is_ancestor_of(node):
			result.append(node as RoomDoor)
	return result


## Puerta que lleva hacia `direction` (null si la sala no tiene)
func door_for(direction: Vector2i) -> RoomDoor:
	for door in doors():
		if door.direction() == direction:
			return door
	return null


## Dónde aparece el jugador al empezar la run: nodo "Inicio" (Marker2D) o el centro del piso
func start_position() -> Vector2:
	var marker := get_node_or_null("Inicio") as Node2D
	if marker != null:
		return marker.global_position
	return global_position + Vector2(size.x * 0.5, size.y - 130.0)


## Centro de la sala en coordenadas globales (hacia ahí apunta la cámara)
func center_global() -> Vector2:
	return global_position + size * 0.5


## Activa o desactiva la sala (la que no se ve no procesa nada)
func set_active(value: bool) -> void:
	visible = value
	process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED


## Solo en el editor: recuadro del área de la sala
func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.9, 1.0, 0.9), false, 4.0)
