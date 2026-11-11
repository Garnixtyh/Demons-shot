class_name TragoPickup
extends Area2D
## Trago misterioso que sale del altar al lograr FC x3 en la última fase. Sale saltando del altar y
## queda flotando; con la tecla de interactuar (F) lo bebés y se abre el selector de mejoras.
## Todo lo visual está en la escena (trago_pickup.tscn): el sprite, la zona y el aviso.

signal drunk

## Qué tan alto sube al salir del altar (px) y cuánto tarda
@export var rise_height: float = 90.0
@export var rise_time: float = 0.6
## Cuánto sube y baja flotando una vez afuera (px)
@export var float_amplitude: float = 6.0

var _player: Node = null
var _used: bool = false
var _ready_to_drink: bool = false

@onready var _prompt: Label = $Aviso
@onready var _sprite: Node2D = $Trago


func _ready() -> void:
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_pop_out()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _used or not _ready_to_drink or not InputMap.has_action("interact"):
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_drink()


## Sale del altar: arranca chico, sube con rebote y después flota
func _pop_out() -> void:
	var final_scale := _sprite.scale
	_sprite.scale = final_scale * 0.2
	_sprite.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise_height, rise_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", final_scale, rise_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate:a", 1.0, rise_time * 0.4)
	await tween.finished
	_ready_to_drink = true
	_prompt.visible = _player != null
	var bob := _sprite.create_tween().set_loops()
	bob.tween_property(_sprite, "position:y", _sprite.position.y - float_amplitude, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_sprite, "position:y", _sprite.position.y, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _drink() -> void:
	_used = true
	_prompt.visible = false
	var player := _player
	drunk.emit()
	ShopPool.open_mystery_drink(player)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and body.is_multiplayer_authority():
		_player = body
		_prompt.visible = _ready_to_drink and not _used


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		_prompt.visible = false
