extends Control
## Lista de lobbies (PRELIMINAR). Todavía no hay red: muestra lobbies de ejemplo.
##
## Para conectarlo después: llamá a `set_lobbies(lista)` con un Array de Dictionary:
##   { "name": String, "host": String, "players": int, "max_players": int }
## y conectá `join_requested` a la lógica de unirse.

signal join_requested(lobby: Dictionary)
signal refresh_requested

@export_file("*.tscn") var main_menu_scene: String = "res://escenas y recursos/menu/main_menu.tscn"
## Mientras no exista la red, muestra lobbies falsos para ver cómo queda
@export var show_placeholder_lobbies: bool = true
@export var background_color: Color = Color(0.16, 0.0, 0.237, 0.621)

const PLACEHOLDER_LOBBIES := [
	{"name": "Sala de ejemplo 1", "host": "Jugador1", "players": 2, "max_players": 4},
	{"name": "Sala de ejemplo 2", "host": "Jugador2", "players": 4, "max_players": 4},
	{"name": "Sala de ejemplo 3", "host": "Jugador3", "players": 1, "max_players": 6},
]

var lobbies: Array = []

var _list_box: VBoxContainer
var _status_label: Label


func _ready() -> void:
	_build_ui()
	refresh()


func refresh() -> void:
	refresh_requested.emit()
	# TODO: acá va la búsqueda de partidas en la LAN
	if show_placeholder_lobbies:
		set_lobbies(PLACEHOLDER_LOBBIES)
		_status_label.text = "Lista de ejemplo: todavía no hay búsqueda en la red."
	else:
		set_lobbies([])
		_status_label.text = "No se encontraron lobbies."


func set_lobbies(new_lobbies: Array) -> void:
	lobbies = new_lobbies
	for child in _list_box.get_children():
		child.queue_free()
	if lobbies.is_empty():
		var empty := Label.new()
		empty.text = "(sin lobbies)"
		empty.modulate = Color(1, 1, 1, 0.5)
		_list_box.add_child(empty)
		return
	for lobby in lobbies:
		_list_box.add_child(_make_row(lobby))


func _make_row(lobby: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = "%s  (host: %s)" % [lobby.get("name", "?"), lobby.get("host", "?")]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

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

	var title := Label.new()
	title.text = "LOBBIES"
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

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
	create_button.disabled = true  # todavía no implementado
	create_button.tooltip_text = "Próximamente"
	buttons.add_child(create_button)


func _on_back_pressed() -> void:
	if not ResourceLoader.exists(main_menu_scene):
		push_warning("LobbyList: no existe la escena '%s'." % main_menu_scene)
		return
	get_tree().change_scene_to_file(main_menu_scene)
