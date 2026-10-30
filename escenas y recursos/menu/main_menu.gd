extends Control
## Menú de inicio: Práctica (va a la sala de pruebas), Lobbies (lista preliminar) y Salir.
## La interfaz se arma por código para que la escena sea mínima y fácil de ajustar.

## Escena de la sala de pruebas
@export_file("*.tscn") var practice_scene: String = "res://escenas y recursos/test_room/test_room.tscn"
## Escena de la lista de lobbies
@export_file("*.tscn") var lobby_list_scene: String = "res://escenas y recursos/menu/lobby_list.tscn"


var _message_label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)


	box.add_child(Control.new())  # separador

	var practice_button := _make_button("Modo práctica")
	practice_button.pressed.connect(_on_practice_pressed)
	box.add_child(practice_button)

	var lobbies_button := _make_button("Ver lobbies")
	lobbies_button.pressed.connect(_on_lobbies_pressed)
	box.add_child(lobbies_button)

	var quit_button := _make_button("Salir")
	quit_button.pressed.connect(get_tree().quit)
	box.add_child(quit_button)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.modulate = Color(1, 0.5, 0.4)
	box.add_child(_message_label)

	practice_button.grab_focus()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2( 0, 52)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _on_practice_pressed() -> void:
	_go_to(practice_scene)


func _on_lobbies_pressed() -> void:
	_go_to(lobby_list_scene)


func _go_to(path: String) -> void:
	if not ResourceLoader.exists(path):
		_message_label.text = "No se encontró la escena:\n%s" % path
		push_warning("MainMenu: no existe la escena '%s'. Revisá la ruta en el Inspector." % path)
		return
	get_tree().change_scene_to_file(path)
