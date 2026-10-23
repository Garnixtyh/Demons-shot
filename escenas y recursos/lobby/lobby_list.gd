extends Control
## Lista de lobbies por red LAN. Escucha los anuncios de los hosts (LanNetwork) y los lista.
## "Unirse" se conecta al host; "Crear lobby" abre la configuración y hostea.
## Si el descubrimiento no encuentra nada (firewall, otra subred), se puede entrar por IP directa.

signal join_requested(lobby: Dictionary)
signal refresh_requested

@export_file("*.tscn") var main_menu_scene: String = "res://escenas y recursos/menu/main_menu.tscn"
@export_file("*.tscn") var lobby_create_scene: String = "res://escenas y recursos/lobby/lobby_create.tscn"
@export_file("*.tscn") var waiting_room_scene: String = "res://escenas y recursos/lobby/waiting_room.tscn"
## Para ver cómo queda el diseño sin red: muestra lobbies falsos en vez de buscar en la LAN
@export var show_placeholder_lobbies: bool = false
@export var background_color: Color = Color(0.16, 0.0, 0.237, 0.621)


var lobbies: Array = []

var _list_box: VBoxContainer
var _status_label: Label
var _name_edit: PlayerNameEdit
var _ip_edit: LineEdit
var _create_overlay: Control
var _connecting: bool = false


func _ready() -> void:
	# Busca el LineEdit del nombre que ya pusiste en la escena (o crea uno si falta)
	for child in get_children():
		if child is PlayerNameEdit:
			_name_edit = child
			break
	if _name_edit == null:
		_name_edit = PlayerNameEdit.new()
	_build_ui()

	LanNetwork.leave()  # por si se vuelve acá desde una sala
	LanNetwork.lobbies_updated.connect(_on_lobbies_updated)
	LanNetwork.lobby_joined.connect(_on_lobby_joined)
	LanNetwork.join_failed.connect(_on_join_failed)
	join_requested.connect(_on_join_requested)

	refresh()
	if not LanNetwork.last_notice.is_empty():
		_status_label.text = LanNetwork.last_notice
		LanNetwork.last_notice = ""


func _exit_tree() -> void:
	LanNetwork.stop_discovery()


func refresh() -> void:
	refresh_requested.emit()
	if show_placeholder_lobbies:
		_status_label.text = "Lista de ejemplo: la búsqueda en la red está desactivada."
		return
	set_lobbies([])
	var err := LanNetwork.start_discovery()
	if err != OK:
		_status_label.text = "No se pudo buscar en la red (puerto %d ocupado). Probá entrar por IP." % LanNetwork.DISCOVERY_PORT
	else:
		_status_label.text = "Buscando lobbies en la red local..."


func set_lobbies(new_lobbies: Array) -> void:
	lobbies = new_lobbies
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	if lobbies.is_empty():
		var empty := Label.new()
		empty.text = "(sin lobbies)"
		empty.modulate = Color(1, 1, 1, 0.5)
		_list_box.add_child(empty)
		return
	for lobby in lobbies:
		_list_box.add_child(_make_row(lobby))


func _on_lobbies_updated(found: Array) -> void:
	if show_placeholder_lobbies or _connecting:
		return
	set_lobbies(found)
	_status_label.text = "Lobbies encontrados: %d" % found.size() if not found.is_empty() \
		else "No se encontraron lobbies. Creá uno o entrá por IP."


func _make_row(lobby: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = "%s  (host: %s)" % [lobby.get("name", "?"), lobby.get("host", "?")]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	if lobby.has("map") and not str(lobby["map"]).is_empty():
		var map_label := Label.new()
		map_label.text = str(lobby["map"])
		map_label.modulate = Color(1, 1, 1, 0.6)
		row.add_child(map_label)

	if lobby.has("team_size"):
		var size := int(lobby["team_size"])
		var mode_label := Label.new()
		mode_label.text = "%dvs%d" % [size, size]
		row.add_child(mode_label)

	var players := int(lobby.get("players", 0))
	var max_players := int(lobby.get("max_players", 0))
	var count_label := Label.new()
	count_label.text = "%d/%d" % [players, max_players]
	row.add_child(count_label)

	var join_button := Button.new()
	join_button.text = "Unirse"
	join_button.disabled = players >= max_players
	join_button.pressed.connect(func() -> void: join_requested.emit(lobby))
	row.add_child(join_button)
	return row


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = background_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	# Encabezado: título a la izquierda, nombre del jugador a la derecha
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var title := Label.new()
	title.text = "LOBBIES"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var name_label := Label.new()
	name_label.text = "Tu nombre:"
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_label)

	if _name_edit.get_parent() != null:
		_name_edit.reparent(header, false)  # lo saca de abajo del fondo y lo pone arriba
	else:
		header.add_child(_name_edit)
	_name_edit.custom_minimum_size = Vector2(200, 36)
	_name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_status_label = Label.new()
	_status_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

	# Entrar por IP directa
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 10)
	box.add_child(ip_row)

	var ip_label := Label.new()
	ip_label.text = "IP directa:"
	ip_row.add_child(ip_label)

	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "ej: 192.168.1.10"
	_ip_edit.custom_minimum_size = Vector2(220, 36)
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _on_ip_connect_pressed())
	ip_row.add_child(_ip_edit)

	var ip_button := Button.new()
	ip_button.text = "Conectar"
	ip_button.pressed.connect(_on_ip_connect_pressed)
	ip_row.add_child(ip_button)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	var back_button := Button.new()
	back_button.text = "Volver"
	back_button.custom_minimum_size = Vector2(140, 44)
	back_button.pressed.connect(_on_back_pressed)
	buttons.add_child(back_button)

	var refresh_button := Button.new()
	refresh_button.text = "Actualizar"
	refresh_button.custom_minimum_size = Vector2(140, 44)
	refresh_button.pressed.connect(refresh)
	buttons.add_child(refresh_button)

	var create_button := Button.new()
	create_button.text = "Crear lobby"
	create_button.custom_minimum_size = Vector2(140, 44)
	create_button.pressed.connect(_on_create_pressed)
	buttons.add_child(create_button)


# ---------------------------------------------------------------- Unirse

func _on_join_requested(lobby: Dictionary) -> void:
	if not lobby.has("ip"):
		return  # lobby de ejemplo, no hay a dónde conectarse
	_connect_to(str(lobby["ip"]), int(lobby.get("port", LanNetwork.GAME_PORT)))


func _on_ip_connect_pressed() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip.is_empty():
		_status_label.text = "Escribí la IP del host."
		return
	_connect_to(ip, LanNetwork.GAME_PORT)


func _connect_to(ip: String, port: int) -> void:
	if _connecting:
		return
	_connecting = true
	_status_label.text = "Conectando a %s..." % ip
	if LanNetwork.join_lobby(ip, port) != OK:
		_connecting = false  # join_failed ya mostró el motivo


func _on_lobby_joined() -> void:
	_connecting = false
	_go_to_waiting_room()


func _on_join_failed(reason: String) -> void:
	_connecting = false
	_status_label.text = reason
	LanNetwork.start_discovery()  # vuelve a buscar lobbies


# ---------------------------------------------------------------- Crear

func _on_create_pressed() -> void:
	if _create_overlay != null or _connecting:
		return
	if not ResourceLoader.exists(lobby_create_scene):
		push_warning("LobbyList: no existe la escena '%s'." % lobby_create_scene)
		_status_label.text = "No se encontró la escena de crear lobby."
		return

	_create_overlay = Control.new()
	_create_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_create_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_create_overlay.add_child(dim)

	var create_screen: Control = (load(lobby_create_scene) as PackedScene).instantiate()
	_create_overlay.add_child(create_screen)
	create_screen.lobby_requested.connect(_on_lobby_requested)
	create_screen.cancelled.connect(_close_create_overlay)


func _close_create_overlay() -> void:
	if _create_overlay != null:
		_create_overlay.queue_free()
		_create_overlay = null


func _on_lobby_requested(config: LobbyConfig) -> void:
	var err := LanNetwork.host_lobby(config)
	if err != OK:
		_close_create_overlay()
		_status_label.text = "No se pudo crear el lobby (error %d). ¿Ya hay uno abierto en esta PC?" % err
		LanNetwork.start_discovery()
		return
	_go_to_waiting_room()


func _go_to_waiting_room() -> void:
	if not ResourceLoader.exists(waiting_room_scene):
		push_warning("LobbyList: no existe la escena '%s'." % waiting_room_scene)
		_close_create_overlay()
		_status_label.text = "No se encontró la sala de espera."
		return
	get_tree().change_scene_to_file(waiting_room_scene)


func _on_back_pressed() -> void:
	if not ResourceLoader.exists(main_menu_scene):
		push_warning("LobbyList: no existe la escena '%s'." % main_menu_scene)
		return
	get_tree().change_scene_to_file(main_menu_scene)
