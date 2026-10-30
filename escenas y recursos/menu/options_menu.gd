extends CanvasLayer
## HUD de opciones: se muestra POR ENCIMA de la escena (menú o partida).
## Por ahora configura el volumen; para agregar más opciones, sumá una sección en _build_sections()
## (con add_section / add_volume_row). Lo guardado queda en user://opciones.cfg.
##
## Uso:  var options := preload("options_menu.gd").new();  add_child(options)
## Al arrancar el juego, OptionsMenu.apply_saved() aplica el volumen guardado.

signal closed

const CONFIG_PATH := "user://opciones.cfg"
## [Texto, nombre del bus de audio]. Los buses que no existan en el proyecto no se muestran.
## "Master" es el volumen general; para música/efectos creá los buses "Musica" y "Efectos".
const VOLUME_BUSES := [
	["Volumen general", "Master"],
	["Música", "Musica"],
	["Efectos", "Efectos"],
]

var _dim: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _closing: bool = false


## Aplica el volumen guardado (se puede llamar sin abrir el menú).
static func apply_saved() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	for entry in VOLUME_BUSES:
		var bus := AudioServer.get_bus_index(entry[1])
		if bus != -1:
			_set_bus_volume(bus, float(config.get_value("audio", entry[1], 100.0)))


static func _set_bus_volume(bus: int, percent: float) -> void:
	AudioServer.set_bus_mute(bus, percent <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(percent, 0.001) / 100.0))


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Fondo oscuro: tapa el menú de atrás y cierra al hacer click afuera
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.65)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	root.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.02, 0.07, 0.96)
	style.border_color = Color(0.9, 0.35, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(26.0)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	_panel.add_child(_content)

	var title := Label.new()
	title.text = "OPCIONES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	_content.add_child(title)

	_build_sections()

	var back := Button.new()
	back.text = "Volver"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0.0, 46.0)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	_content.add_child(back)

	_animate_in()


## Acá se arman las secciones. Más configuraciones a futuro: agregá otra llamada.
func _build_sections() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	var any_bus := false
	for entry in VOLUME_BUSES:
		var bus := AudioServer.get_bus_index(entry[1])
		if bus == -1:
			continue
		any_bus = true
		add_volume_row(entry[0], entry[1], bus, float(config.get_value("audio", entry[1], 100.0)))
	if not any_bus:
		var warning := Label.new()
		warning.text = "No hay buses de audio en el proyecto."
		_content.add_child(warning)


## Fila: nombre + slider (0-100) + porcentaje.
func add_volume_row(label_text: String, bus_name: String, bus: int, percent: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150.0, 0.0)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = percent
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.text = "%d%%" % int(percent)
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value)
		_set_bus_volume(bus, value)
		_save_value("audio", bus_name, value))


func _save_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _animate_in() -> void:
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	# El tamaño recién se conoce después del primer frame de layout
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2.ONE * 0.85
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.15)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(_panel, "scale", Vector2.ONE * 0.9, 0.15)
	await tween.finished
	closed.emit()
	queue_free()
