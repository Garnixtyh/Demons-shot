extends Control
## Pantalla "Crear lobby". La interfaz se arma por código, así no depende de nodos hijos.
## Conectá las señales desde tu menú:
##   lobby_requested(config) -> acá hosteás el servidor con esa config y vas a la sala de espera
##   cancelled               -> volvés a la lista de lobbys

signal lobby_requested(config: LobbyConfig)
signal cancelled

var _name_edit: LineEdit
var _team_option: OptionButton
var _points_spin: SpinBox
var _rounds_spin: SpinBox
var _upgrades_spin: SpinBox
var _rerolls_spin: SpinBox
var _map_option: OptionButton
var _create_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_create_button()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Crear lobby"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)

	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 220
	_name_edit.max_length = 24
	_name_edit.text = "Sala de %s" % PlayerProfile.player_name
	_name_edit.text_changed.connect(func(_t): _refresh_create_button())
	_add_row(grid, "Nombre del lobby", _name_edit)

	_team_option = OptionButton.new()
	for size in LobbyConfig.TEAM_SIZES:
		_team_option.add_item("%dvs%d" % [size, size], size)
	_add_row(grid, "Tamaño de equipos", _team_option)

	_points_spin = _make_spin(1, 20, 3)
	_add_row(grid, "Puntos para ganar la ronda", _points_spin)

	_rounds_spin = _make_spin(1, 15, 3)
	_add_row(grid, "Rondas para ganar", _rounds_spin)

	_upgrades_spin = _make_spin(1, 5, 3)
	_add_row(grid, "Mejoras por ronda", _upgrades_spin)

	_rerolls_spin = _make_spin(0, 10, 1)
	_add_row(grid, "Rerolls de mejoras", _rerolls_spin)

	_map_option = OptionButton.new()
	for map_name in LobbyConfig.MAPS.keys():
		_map_option.add_item(map_name)
	_add_row(grid, "Mapa", _map_option)


	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	var back := Button.new()
	back.text = "Volver"
	back.pressed.connect(func(): cancelled.emit())
	buttons.add_child(back)

	_create_button = Button.new()
	_create_button.text = "Crear lobby"
	_create_button.pressed.connect(_on_create_pressed)
	buttons.add_child(_create_button)


func _make_spin(min_v: int, max_v: int, default_v: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 1
	s.value = default_v
	s.rounded = true
	return s


func _add_row(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _refresh_create_button() -> void:
	_create_button.disabled = _name_edit.text.strip_edges().is_empty() \
		or _map_option.item_count == 0


func get_config() -> LobbyConfig:
	var c := LobbyConfig.new()
	c.lobby_name = _name_edit.text.strip_edges()
	c.team_size = _team_option.get_selected_id()
	c.points_to_win_round = int(_points_spin.value)
	c.rounds_to_win = int(_rounds_spin.value)
	c.upgrades_per_round = int(_upgrades_spin.value)
	c.rerolls = int(_rerolls_spin.value)
	c.map_name = _map_option.get_item_text(_map_option.selected)
	return c


func _on_create_pressed() -> void:
	var config := get_config()
	if config.is_valid():
		lobby_requested.emit(config)
