class_name WaveButton
extends Area2D
## Plataforma con botón: se interactúa (tecla de interactuar, la misma que en la tienda) para
## empezar la siguiente fase de oleadas. El RunManager la activa/desactiva según el estado.
## Ponela en la sala principal (wave_button.tscn); se arma sola por código.

signal pressed

## Se puede apretar (el RunManager la apaga mientras hay oleadas y al terminar todas las fases)
var enabled: bool = true:
	set(value):
		enabled = value
		_refresh()

var _player: Node = null
var _prompt: Label
var _button_rect: ColorRect


func _ready() -> void:
	add_to_group("wave_buttons")
	collision_layer = 0
	var zone := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(180, 120)
	zone.shape = shape
	zone.position = Vector2(0, -50)
	add_child(zone)

	# Plataforma + botón (placeholder)
	var platform := ColorRect.new()
	platform.color = Color(0.35, 0.3, 0.4)
	platform.position = Vector2(-90, -16)
	platform.size = Vector2(180, 16)
	platform.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(platform)
	_button_rect = ColorRect.new()
	_button_rect.position = Vector2(-26, -32)
	_button_rect.size = Vector2(52, 16)
	_button_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_button_rect)

	_prompt = Label.new()
	_prompt.text = "[R] Iniciar oleadas"
	_prompt.position = Vector2(-80, -86)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.hide()
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not enabled or not InputMap.has_action("interact"):
		return
	if event.is_action_pressed("interact"):
		pressed.emit()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _button_rect == null:
		return
	_button_rect.color = Color(0.3, 0.85, 0.35) if enabled else Color(0.6, 0.15, 0.15)
	_prompt.visible = enabled and _player != null


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		_player = body
		_refresh()


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		_refresh()
