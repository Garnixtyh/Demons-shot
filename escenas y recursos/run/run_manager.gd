class_name RunManager
extends Node2D
## Controla la run del modo un jugador. Va en la raíz de mapa_run.tscn.
##
## Las salas ya están puestas en la escena (instancias de sala, cada una con su `grid_coord`):
## acá no se crea ni se destruye nada. El RunManager las junta, abre/cierra sus puertas según
## los vecinos que existan y hace la transición al cruzar una puerta: la cámara se desliza a la
## sala vecina (como The Binding of Isaac / NES) y el jugador aparece en la puerta contraria.
##
## Grilla: x crece a la derecha, y crece hacia ABAJO (UP = (0,-1)).

signal room_changed(room: Room)

@export var player_path: NodePath = ^"Player"
## Duración (segundos) del deslizamiento entre salas
@export var slide_time: float = 0.6
@export_group("Cámara")
## Qué tan cerca está la cámara. 1 = se ve la sala entera; mayor = más cerca del jugador
## (la cámara lo sigue sin salirse de los bordes de la sala)
@export_range(1.0, 4.0, 0.05) var camera_zoom_multiplier: float = 1.6
## Qué tan rápido alcanza la cámara al jugador (más alto = más pegada)
@export var camera_follow_speed: float = 10.0
@export_group("")
@export_file("*.tscn") var menu_scene: String = "res://escenas y recursos/menu/main_menu.tscn"

## Vector2i -> Room
var layout: Dictionary = {}
var current_coord: Vector2i = Vector2i.ZERO
var current_room: Room = null

var _player: CharacterBody2D
var _camera: Camera2D
var _transitioning: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	if _player == null:
		push_error("RunManager: no encontré al jugador en '%s'." % player_path)
		return
	# Modo un jugador: al morir no reaparece, sale la pantalla de muerte
	_player.auto_respawn = false
	_player.died.connect(_on_player_died)
	_setup_backdrop()
	_setup_camera()
	_collect_rooms()
	if layout.is_empty():
		push_error("RunManager: no hay salas (instancias de sala con el grupo run_rooms) en la escena.")
		return
	var start: Vector2i = Vector2i.ZERO if layout.has(Vector2i.ZERO) else layout.keys()[0]
	_enter_room(start, Vector2i.ZERO)


func _on_player_died() -> void:
	# Un momento para ver la muerte antes de oscurecer todo
	await get_tree().create_timer(0.8).timeout
	if get_node_or_null("PantallaMuerte") != null:
		return
	var screen := DeathScreen.new()
	screen.name = "PantallaMuerte"
	screen.menu_scene = menu_scene
	screen.points = _player.points
	add_child(screen)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and ResourceLoader.exists(menu_scene):
		get_tree().change_scene_to_file(menu_scene)


# ---------------------------------------------------------------- Mapa

## Junta las salas de la escena y abre/cierra sus puertas según los vecinos.
## Para generación procedural: acá se podrían instanciar/mover salas antes de juntarlas.
func _collect_rooms() -> void:
	layout.clear()
	for node in get_tree().get_nodes_in_group("run_rooms"):
		var room := node as Room
		if layout.has(room.grid_coord):
			push_warning("RunManager: dos salas con la misma grid_coord %s ('%s' y '%s')."
					% [room.grid_coord, layout[room.grid_coord].name, room.name])
			continue
		layout[room.grid_coord] = room
		room.set_active(false)
	for coord: Vector2i in layout:
		var room: Room = layout[coord]
		for door in room.doors():
			door.open = layout.has(coord + door.direction())
			door.player_entered.connect(_on_door_entered.bind(room))


# ---------------------------------------------------------------- Transiciones

func _on_door_entered(door: RoomDoor, room: Room) -> void:
	if _transitioning or room != current_room:
		return
	var direction := door.direction()
	if layout.has(current_coord + direction):
		_enter_room(current_coord + direction, direction)


## Entra a la sala `coord`. `direction` = hacia dónde se movió el jugador (ZERO = arranque, sin deslizar).
func _enter_room(coord: Vector2i, direction: Vector2i) -> void:
	_transitioning = true
	var old_room := current_room
	var room: Room = layout[coord]
	room.set_active(true)
	# Aparece en la puerta contraria a la que cruzó (si no tiene, en el inicio de la sala)
	var entry_door := room.door_for(-direction) if direction != Vector2i.ZERO else null
	var entry := entry_door.entry_position() if entry_door != null else room.start_position()

	if old_room == null:
		_player.global_position = entry
		_camera.zoom = _zoom_for(room)
		_camera.global_position = _camera_target(room, entry)
		_camera.reset_smoothing()
	else:
		_player.set_net_frozen(true)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_camera, "global_position", _camera_target(room, entry), slide_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_camera, "zoom", _zoom_for(room), slide_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_player, "global_position", entry, slide_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		old_room.set_active(false)
		_player.set_net_frozen(false, false)
		if direction == Vector2i.DOWN:
			# Vino desde abajo: un impulso para no volver a caer
			_player.velocity.y = _player.jump_velocity

	current_coord = coord
	current_room = room
	_player.spawn_position = entry
	_player.fall_death_y = room.global_position.y + room.size.y + 800.0
	# Un instante para no volver a disparar la puerta por la que se acaba de entrar
	await get_tree().create_timer(0.25).timeout
	_transitioning = false
	room_changed.emit(room)


# ---------------------------------------------------------------- Cámara y fondo

func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "CamaraSala"
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	# La cámara del jugador se apaga: acá la cámara va a la sala, no al jugador
	var player_cam := _player.get_node_or_null("Camera2D") as Camera2D
	if player_cam != null:
		player_cam.enabled = false
	_camera.make_current()
	get_viewport().size_changed.connect(func() -> void:
		if current_room != null:
			_camera.zoom = _zoom_for(current_room))


## La cámara sigue al jugador dentro de la sala (salvo durante la transición entre salas)
func _process(delta: float) -> void:
	if _transitioning or current_room == null or _camera == null:
		return
	var target := _camera_target(current_room, _player.global_position)
	_camera.global_position = _camera.global_position.lerp(target, 1.0 - exp(-camera_follow_speed * delta))


## A dónde mira la cámara: sobre `focus`, pero sin mostrar nada fuera de la sala.
## Si la sala es más chica que la vista, queda centrada en esa dirección.
func _camera_target(room: Room, focus: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / _zoom_for(room).x * 0.5
	var rect := Rect2(room.global_position, room.size)
	var result := focus
	for axis in 2:
		var low: float = rect.position[axis] + half_view[axis]
		var high: float = rect.end[axis] - half_view[axis]
		result[axis] = rect.get_center()[axis] if high < low else clampf(focus[axis], low, high)
	return result


## Zoom: la sala entera llena la pantalla, multiplicado por camera_zoom_multiplier
func _zoom_for(room: Room) -> Vector2:
	var view := get_viewport_rect().size
	var z := maxf(view.x / room.size.x, view.y / room.size.y) * camera_zoom_multiplier
	return Vector2(z, z)


## Fondo negro (detrás de todo) para que fuera de las salas no se vea gris
func _setup_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)
