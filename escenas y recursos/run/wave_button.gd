class_name WaveButton
extends Area2D
## Plataforma con botón: se interactúa (tecla de interactuar, la misma que en la tienda) para
## empezar la siguiente fase de oleadas. El RunManager la activa/desactiva según el estado.
## Ponela en la sala principal (wave_button.tscn). El texto del aviso se cambia en el nodo "Aviso".

signal pressed

## Se puede apretar (el RunManager la apaga mientras hay oleadas y al terminar todas las fases)
var enabled: bool = true:
	set(value):
		enabled = value
		_refresh()

## Cómo se ve cuando se puede apretar y cuando está apagado (hay oleadas o ya terminaron).
## Se aplica al nodo "Altar" (Sprite2D) y, si existe un ColorRect "Boton", a su color.
@export var color_enabled: Color = Color(1, 1, 1)
@export var color_disabled: Color = Color(0.5, 0.5, 0.5)

var _player: Node = null
## Todo lo visual está en la escena (wave_button.tscn): el altar y el texto del aviso.
@onready var _prompt: Label = $Aviso
@onready var _altar: Node2D = get_node_or_null("Altar") as Node2D
@onready var _button_rect: ColorRect = get_node_or_null("Boton") as ColorRect


func _ready() -> void:
	add_to_group("wave_buttons")
	_prompt.hide()
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
	if _prompt == null:
		return
	var tint := color_enabled if enabled else color_disabled
	if _altar != null:
		_altar.modulate = tint
	if _button_rect != null:
		_button_rect.color = tint
	_prompt.visible = enabled and _player != null


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		_player = body
		_refresh()


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		_refresh()
