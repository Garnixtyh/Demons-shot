class_name DeathScreen
extends CanvasLayer
## Pantalla de muerte del modo un jugador: oscurece todo, pausa el juego y deja elegir entre
## reintentar la run o volver al menú. Se arma por código; la crea el RunManager cuando el jugador muere.

## Escena del menú principal (la pasa el RunManager)
var menu_scene: String = "res://escenas y recursos/menu/main_menu.tscn"
## Puntos del jugador, para mostrarlos (opcional)
var points: int = 0

var _retry_button: Button


func _ready() -> void:
	# Sigue funcionando con el juego en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	get_tree().paused = true

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)  # también frena los clicks hacia el juego

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "HAS MUERTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(title)

	var score := Label.new()
	score.text = "Puntos: %d" % points
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 24)
	box.add_child(score)

	_retry_button = _make_button("Reintentar", _on_retry)
	box.add_child(_retry_button)
	box.add_child(_make_button("Menú principal", _on_menu))

	_retry_button.grab_focus()
	create_tween().tween_property(root, "modulate:a", 1.0, 0.6)


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	return button


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	if ResourceLoader.exists(menu_scene):
		get_tree().change_scene_to_file(menu_scene)
