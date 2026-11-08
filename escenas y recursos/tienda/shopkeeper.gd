class_name Shopkeeper
extends Area2D
## El vendedor de la tienda. Cuando el jugador se acerca aparece el aviso y, al apretar la
## tecla de interactuar (R), se abre el menú de la tienda (shop_menu.gd).
##
## El stock se sortea UNA vez, la primera vez que se abre, y se conserva mientras dure la run
## (lo vendido queda como "VENDIDO"). Los precios y lo que puede vender están en shop_pool.gd.
## Cambiale el sprite al nodo "Sprite2D" de la escena.

## Frases del NPC que aparece al abrir la tienda: al hacerle click con el mouse dice una al azar.
## Para sumar o cambiar frases, editá esta lista.
const NPC_DIALOGS: Array[String] = [
	"Psst... ¿viste esa carta de la luna? Dicen que trae suerte.",
	"Yo solo vine a mirar. Los precios me dan miedo.",
	"Un reroll por punto... y la suerte no siempre acompaña.",
	"El vendedor no me deja tocar nada, che.",
	"¿Vos también escuchás pasos en la sala del tesoro?",
	"Ayer vi una mejora que hacía las balas gigantes. Tremenda.",
	"Si te sobran puntos, comprá cartas. Si no, rezá.",
	"No me mires así, no estoy en venta.",
]

## Cuántas mejoras / cartas / objetos tiene a la venta
@export var upgrades_in_stock: int = 3
@export var cards_in_stock: int = 2
@export var objects_in_stock: int = 2
@export_group("Reroll")
## Puntos que gasta cada vez que se aprieta el botón de reroll
@export var reroll_cost: int = 1
## Probabilidad de que el reroll renueve todos los artículos (0.2 = 1 de cada 5)
@export_range(0.0, 1.0) var reroll_chance: float = 0.2
## Sprite del botón de reroll (placeholder: cambialo por el tuyo)
@export var reroll_icon: Texture2D
@export_group("NPC")
## Segundos que se ve la frase del NPC
@export var dialog_time: float = 3.0
## Sprite del NPC (placeholder: cambialo por el tuyo)
@export var npc_icon: Texture2D

var _stock: Array = []
var _stocked: bool = false
var _player: Node = null
var _menu: ShopMenu = null

@onready var _prompt: Label = $Aviso


func _ready() -> void:
	_prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_menu = ShopMenu.new()
	_menu.reroll_cost = reroll_cost
	_menu.reroll_chance = reroll_chance
	_menu.reroll_icon = reroll_icon
	_menu.npc_icon = npc_icon
	_menu.npc_dialogs = NPC_DIALOGS
	_menu.dialog_time = dialog_time
	_menu.closed.connect(_on_menu_closed)
	_menu.reroll_succeeded.connect(_on_reroll_succeeded)
	add_child(_menu)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _menu.is_open() or not InputMap.has_action("interact"):
		return
	if event.is_action_pressed("interact"):
		_open_shop()
		get_viewport().set_input_as_handled()


func _make_stock() -> Array:
	return ShopPool.pick(ShopPool.upgrades(_player), upgrades_in_stock) \
			+ ShopPool.pick(ShopPool.cards(), cards_in_stock) \
			+ ShopPool.pick(ShopPool.objects(), objects_in_stock)


## Reroll exitoso: se sortean artículos nuevos (todo lo vendido vuelve a estar disponible)
func _on_reroll_succeeded() -> void:
	_stock = _make_stock()
	_menu.set_items(_stock)


func _open_shop() -> void:
	if not _stocked:
		_stock = _make_stock()
		_stocked = true
	_prompt.hide()
	_menu.open(_player, _stock)


func _on_menu_closed() -> void:
	_prompt.visible = _player != null


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		_player = body
		_prompt.show()


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		_prompt.hide()
