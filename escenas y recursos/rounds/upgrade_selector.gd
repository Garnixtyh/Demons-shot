class_name UpgradeSelector
extends CanvasLayer
## Pantalla de elección de mejora. Todo el HUD está en upgrade_selector.tscn:
## un título y una fila donde se instancia una CARTA por cada opción
## (upgrade_card.tscn, o la carta propia de la mejora si tiene una).
## Se elige con click o con las teclas 1, 2 y 3. Pausa el juego mientras está abierta.
##
## Animaciones de cada carta: "entrada" (al aparecer), "seleccion" (cursor encima)
## y "salida" (las cartas no elegidas, al elegir una).

signal upgrade_chosen(upgrade: Upgrade)
## El jugador pidió cambiar las opciones (reroll). Quien lo escucha vuelve a llamar a offer().
signal reroll_requested

## Carta que se usa si la mejora no trae una propia
@export var default_card_scene: PackedScene
## Segundos de diferencia entre la entrada de una carta y la siguiente
@export var enter_stagger: float = 0.12
## true = pausa el juego mientras está abierto (en red se desactiva: los demás siguen conectados)
var pause_game: bool = true

var _options: Array = []
var _cards: Array = []
var _choosing: bool = false
var _reroll_button: Button

@onready var _root: Control = $Root
@onready var _title: Label = $Root/Center/Box/Title
@onready var _row: HBoxContainer = $Root/Center/Box/Row


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root.hide()
	_reroll_button = Button.new()
	_reroll_button.focus_mode = Control.FOCUS_NONE
	_reroll_button.custom_minimum_size = Vector2(220, 44)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.pressed.connect(_on_reroll_pressed)
	$Root/Center/Box.add_child(_reroll_button)
	_reroll_button.hide()


func is_open() -> bool:
	return _root.visible


## `title` vacío = título por defecto. `rerolls_left` > 0 muestra el botón de reroll (tecla Q).
func offer(options: Array, round_number: int, rerolls_left: int = 0, title: String = "") -> void:
	_options = options
	_choosing = false
	_clear_cards()
	_title.text = title if not title.is_empty() else "Ronda %d — elegí una mejora" % round_number
	_reroll_button.visible = rerolls_left > 0
	_reroll_button.text = "Reroll (Q) — quedan %d" % rerolls_left
	for i in options.size():
		var upgrade: Upgrade = options[i]
		var scene: PackedScene = upgrade.card_scene if upgrade.card_scene != null else default_card_scene
		var card = scene.instantiate()
		_row.add_child(card)
		card.setup(upgrade, i)
		card.chosen.connect(_choose.bind(i))
		_cards.append(card)
	_root.show()
	if pause_game:
		get_tree().paused = true
	for i in _cards.size():
		_cards[i].play_enter(i * enter_stagger)


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q and _reroll_button.visible:
			_on_reroll_pressed()
			return
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < _options.size():
			_choose(index)


func _on_reroll_pressed() -> void:
	if not _root.visible or _choosing:
		return
	reroll_requested.emit()


func _choose(index: int) -> void:
	if not _root.visible or _choosing:
		return
	_choosing = true
	var upgrade: Upgrade = _options[index]
	# La elegida se queda; las demás hacen su animación de salida
	var wait := 0.0
	for i in _cards.size():
		if i == index:
			_cards[i].play_selected()
		else:
			wait = maxf(wait, _cards[i].play_exit())
	await get_tree().create_timer(wait + 0.15).timeout
	_root.hide()
	_clear_cards()
	if pause_game:
		get_tree().paused = false
	upgrade_chosen.emit(upgrade)


func _clear_cards() -> void:
	for card in _cards:
		if is_instance_valid(card):
			_row.remove_child(card)
			card.queue_free()
	_cards.clear()
