class_name CajaPandora
extends Area2D
## Caja de Pandora: se abre UNA vez con la tecla de interactuar (F) y suelta algo al azar:
##  - un arma (todavía no hay ninguna: poné escenas en `weapon_scenes` y se activa sola),
##  - una mejora (sale como carta: la usás con click o la rechazás con el botón),
##  - un trago misterioso (te deja elegir una mejora entre varias),
##  - una oleada de enemigos (las puertas se cierran hasta matarlos a todos),
##  - un cangrejo.
## Todo lo visual está en la escena (caja_pandora.tscn): el sprite de la caja, la zona y el aviso.
## Para ponerle tu sprite, cambiá la textura del nodo "Caja".

signal opened(result: String)

enum Result { WEAPON, UPGRADES, DRINK, WAVE, CRAB }

@export_group("Probabilidades (pesos relativos)")
## Cuanto más alto el peso, más probable. 0 = nunca sale. El arma solo sale si hay `weapon_scenes`.
@export var weight_weapon: int = 20
@export var weight_upgrades: int = 25
@export var weight_drink: int = 20
@export var weight_wave: int = 20
@export var weight_crab: int = 15
@export_group("Contenido")
## Armas que puede soltar (todavía no hay ninguna implementada)
@export var weapon_scenes: Array[PackedScene] = []
## Escena del cangrejo que puede salir
@export_file("*.tscn") var crab_scene: String = "res://escenas y recursos/enemigos/enemigo_cangrejo.tscn"
@export_group("Animación")
## Segundos entre apretar F y que pase lo que sea (la caja se sacude)
@export var open_time: float = 0.7
## Color de la caja una vez abierta
@export var opened_color: Color = Color(0.45, 0.45, 0.45)

var is_open: bool = false

var _player: Node = null

@onready var _prompt: Label = $Aviso
@onready var _box: Node2D = $Caja


func _ready() -> void:
	_prompt.show()
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or is_open or not InputMap.has_action("interact"):
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and body.is_multiplayer_authority():
		_player = body
		_prompt.visible = not is_open


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		_prompt.visible = false


func _open() -> void:
	is_open = true
	_prompt.visible = false
	var player := _player
	await _shake()
	if not is_inside_tree() or not is_instance_valid(player):
		return
	_box.modulate = opened_color
	var result := _roll()
	_give(result, player)
	opened.emit(Result.keys()[result])


## Sacude la caja y la deja con un pequeño salto al abrirse
func _shake() -> void:
	var tween := create_tween()
	var steps := maxi(int(open_time / 0.08), 2)
	for i in steps:
		var side := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(_box, "rotation", side * 0.12, 0.04)
		tween.tween_property(_box, "rotation", 0.0, 0.04)
	tween.tween_property(_box, "scale", _box.scale * 1.25, 0.08)
	tween.tween_property(_box, "scale", _box.scale, 0.12)
	await tween.finished


## Sortea qué suelta, según los pesos (sin contar lo que no se puede dar).
func _roll() -> int:
	var options := {}
	if weight_weapon > 0 and not weapon_scenes.is_empty():
		options[Result.WEAPON] = weight_weapon
	if weight_upgrades > 0:
		options[Result.UPGRADES] = weight_upgrades
	if weight_drink > 0:
		options[Result.DRINK] = weight_drink
	if weight_wave > 0 and _run_manager() != null and _room() != null:
		options[Result.WAVE] = weight_wave
	if weight_crab > 0 and ResourceLoader.exists(crab_scene):
		options[Result.CRAB] = weight_crab
	if options.is_empty():
		return Result.UPGRADES
	var total := 0
	for weight: int in options.values():
		total += weight
	var pick := randi() % total
	for key in options:
		pick -= options[key]
		if pick < 0:
			return key
	return Result.UPGRADES


func _give(result: int, player: Node) -> void:
	match result:
		Result.WEAPON:
			_float_text("¡Un arma!", Color(0.6, 0.9, 1.0))
			var weapon := weapon_scenes.pick_random().instantiate() as Node2D
			get_parent().add_child(weapon)
			weapon.global_position = global_position + Vector2(0.0, -70.0)
		Result.UPGRADES:
			_float_text("¡Una mejora!", Color(1.0, 0.9, 0.3))
			ShopPool.offer_single_upgrade(player, "Caja de Pandora — ¿usar esta mejora?")
		Result.DRINK:
			_float_text("¡Trago misterioso!", Color(0.85, 0.5, 1.0))
			ShopPool.open_mystery_drink(player)
		Result.WAVE:
			_float_text("¡Oleada!", Color(1.0, 0.4, 0.4))
			_run_manager().start_event_wave(_room())
		Result.CRAB:
			_float_text("¡Un cangrejo!", Color(1.0, 0.55, 0.3))
			_spawn_crab()


func _spawn_crab() -> void:
	var crab := (load(crab_scene) as PackedScene).instantiate() as Node2D
	# Los enemigos de oleada no reaparecen solos
	if "respawn_time" in crab:
		crab.set("respawn_time", 0.0)
	get_parent().add_child(crab)
	var side := 1.0 if randf() < 0.5 else -1.0
	crab.global_position = global_position + Vector2(side * 110.0, -20.0)


func _run_manager() -> Node:
	return get_tree().get_first_node_in_group("run_manager")


func _room() -> Room:
	var node := get_parent()
	while node != null and not (node is Room):
		node = node.get_parent()
	return node as Room


## Texto flotante sobre la caja (sube y se desvanece, mismo estilo que los de la tienda)
func _float_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	get_tree().current_scene.add_child(label)
	label.reset_size()
	label.global_position = global_position + Vector2(0.0, -130.0) - label.size * 0.5
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 1.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.9)
	tween.chain().tween_callback(label.queue_free)
