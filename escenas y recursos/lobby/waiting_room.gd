extends Control
## Sala de espera en red. Muestra la config del lobby (LobbyConfig.current) y los dos equipos,
## con los jugadores que manda LanNetwork. El host puede empezar; cualquiera puede cambiar de equipo.

@export_file("*.tscn") var lobby_list_scene: String = "res://escenas y recursos/menu/lobby_list.tscn"
@export var background_color: Color = Color(0.16, 0.0, 0.237, 0.621)

const TEAM_NAMES := ["ROJO", "AZUL"]
const TEAM_COLORS := [Color(1.0, 0.4, 0.4), Color(0.4, 0.6, 1.0)]

var config: LobbyConfig

var _team_boxes: Array[VBoxContainer] = []
var _start_button: Button
var _message_label: Label


func _ready() -> void:
	if not LanNetwork.in_lobby:
		# Abriste la escena sola para probarla: hostea un lobby de prueba
		var test_config := LobbyConfig.new()
		test_config.lobby_name = "Lobby de prueba"
		test_config.map_name = LobbyConfig.MAPS.keys()[0]
		LanNetwork.host_lobby(test_config)
	config = LobbyConfig.current
	_build_ui()
	_refresh_slots()
	LanNetwork.players_changed.connect(_refresh_slots)
	LanNetwork.left_lobby.connect(func(_reason: String) -> void: _go_to_lobby_list())


func _refresh_slots() -> void:
	var my_id := multiplayer.get_unique_id()
	for team in 2:
		var box := _team_boxes[team]
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		var members: Array = []
		for id in LanNetwork.players.keys():
			var p: Dictionary = LanNetwork.players[id]
			if int(p["team"]) == team:
				var label := str(p["name"])
				if id == 1:
					label += "  (host)"
				if id == my_id:
					label += "  ← vos"
				members.append(label)
		for i in config.team_size:
			var slot := Label.new()
			if i < members.size():
				slot.text = members[i]
			else:
				slot.text = "(vacío)"
				slot.modulate = Color(1, 1, 1, 0.4)
			slot.custom_minimum_size = Vector2(240, 36)
			box.add_child(slot)


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

	# Encabezado: nombre del lobby + nombre del jugador editable
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var title := Label.new()
	title.text = "%s  (%s)" % [config.lobby_name, config.team_label()]
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var name_label := Label.new()
	name_label.text = "Tu nombre:"
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_label)

	var name_edit := PlayerNameEdit.new()
	name_edit.custom_minimum_size = Vector2(200, 36)
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_edit)

	# Resumen de la configuración
	var summary := Label.new()
	summary.modulate = Color(1, 1, 1, 0.75)
	summary.text = "Mapa: %s   |   Puntos por ronda: %d   |   Rondas para ganar: %d   |   Mejoras por ronda: %d   |   Rerolls: %d" % [
		config.map_name, config.points_to_win_round, config.rounds_to_win,
		config.upgrades_per_round, config.rerolls,
	]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	if multiplayer.is_server():
		var ip_label := Label.new()
		ip_label.modulate = Color(1, 1, 1, 0.5)
		ip_label.text = "Tu IP en la red (para entrar por IP directa): %s" % LanNetwork.get_lan_ip()
		box.add_child(ip_label)

	# Equipos
	var teams := HBoxContainer.new()
	teams.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teams.alignment = BoxContainer.ALIGNMENT_CENTER
	teams.add_theme_constant_override("separation", 60)
	box.add_child(teams)

	for team in 2:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		teams.add_child(column)

		var team_title := Label.new()
		team_title.text = TEAM_NAMES[team]
		team_title.add_theme_font_size_override("font_size", 24)
		team_title.modulate = TEAM_COLORS[team]
		team_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(team_title)

		var slots := VBoxContainer.new()
		slots.add_theme_constant_override("separation", 6)
		column.add_child(slots)
		_team_boxes.append(slots)

	_message_label = Label.new()
	_message_label.modulate = Color(1, 0.5, 0.4)
	box.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	var leave_button := Button.new()
	leave_button.text = "Salir"
	leave_button.custom_minimum_size = Vector2(140, 44)
	leave_button.pressed.connect(_on_leave_pressed)
	buttons.add_child(leave_button)

	var switch_button := Button.new()
	switch_button.text = "Cambiar de equipo"
	switch_button.custom_minimum_size = Vector2(180, 44)
	switch_button.pressed.connect(LanNetwork.request_switch_team)
	buttons.add_child(switch_button)

	_start_button = Button.new()
	_start_button.custom_minimum_size = Vector2(180, 44)
	_start_button.pressed.connect(_on_start_pressed)
	if multiplayer.is_server():
		_start_button.text = "Empezar"
	else:
		_start_button.text = "Esperando al host..."
		_start_button.disabled = true
	buttons.add_child(_start_button)


func _on_leave_pressed() -> void:
	LanNetwork.leave()
	_go_to_lobby_list()


func _go_to_lobby_list() -> void:
	if ResourceLoader.exists(lobby_list_scene):
		get_tree().change_scene_to_file(lobby_list_scene)
	else:
		push_warning("WaitingRoom: no existe la escena '%s'." % lobby_list_scene)


func _on_start_pressed() -> void:
	var err := LanNetwork.start_game()
	if err == ERR_FILE_NOT_FOUND:
		_message_label.text = "No se encontró el mapa:\n%s\n(revisá LobbyConfig.MAPS)" % config.map_path()
	elif err != OK:
		_message_label.text = "No se pudo empezar la partida (error %d)." % err
