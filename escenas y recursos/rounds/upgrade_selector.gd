class_name UpgradeSelector
extends CanvasLayer
## Pantalla de elección de mejora: muestra las opciones y avisa cuál se eligió.
## Se elige con click o con las teclas 1, 2 y 3. Pausa el juego mientras está abierta.

signal upgrade_chosen(upgrade: Upgrade)

var _options: Array = []
var _root: Control
var _title: Label
var _row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_ui()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func offer(options: Array, round_number: int) -> void:
	_options = options
	_title.text = "Ronda %d — elegí una mejora" % round_number
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for i in options.size():
		var upgrade: Upgrade = options[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 150)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "[%d]  %s\n\n%s\n\n%s" % [i + 1, upgrade.category_name(), upgrade.title, upgrade.description]
		button.pressed.connect(_choose.bind(i))
		_row.add_child(button)
	_root.show()
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < _options.size():
			_choose(index)


func _choose(index: int) -> void:
	if not _root.visible:
		return
	var upgrade: Upgrade = _options[index]
	_root.hide()
	get_tree().paused = false
	upgrade_chosen.emit(upgrade)


func _build_ui() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	box.add_child(_title)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	box.add_child(_row)
