class_name Shopkeeper
extends Area2D
## El vendedor de la tienda. Cuando el jugador se acerca aparece el aviso y, al apretar la
## tecla de interactuar (F), se abre el menú de la tienda (shop_menu.gd).
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

## Frases del NPC cuando pasa algo en la tienda (reemplazan al texto que salía abajo).
## Cada evento tiene una lista; sale una al azar. "{item}" se reemplaza por el nombre del artículo.
## Eventos: buy (compraste algo), no_money (no alcanzan los puntos), pocket_full (no se pudo guardar el objeto),
## reroll_ok (el reroll renovó todo), reroll_fail (el reroll no salió), drink_chosen (elegiste la mejora del trago),
## reroll_jam (el frasco se atascó), reroll_jammed (intentás usar el frasco ya atascado).
const NPC_LINES := {
	"buy": [
		"Un placer hacer negocios con vos.",
		"{item}, buena elección. No hay devoluciones.",
		"Pagá y callá, así me gusta.",
		"Ese me lo pedían todos... bueno, nadie. Es tuyo.",
	],
	"no_money": [
		"Con esos puntos no me alcanza ni para un caramelo.",
		"Volvé cuando tengas más puntos, che.",
		"No fío. Ni a mi madre le fío.",
		"Mirá que la plata no crece en los árboles.",
	],
	"pocket_full": [
		"Uy, no pude guardártelo. Probá de nuevo.",
		"Algo salió mal con el bolsillo, flaco.",
	],
	"reroll_ok": [
		"¡Todo nuevo! Dicen que la suerte es redonda.",
		"Mirá vos, hoy estás de suerte.",
		"Mercadería fresca recién salida del horno.",
	],
	"reroll_fail": [
		"Ups, no hubo suerte. Los puntos se quedan acá.",
		"Sigue todo igual... y tus puntos conmigo.",
		"Casi... no, mentira, ni cerca.",
	],
	"reroll_jam": [
		"eh ya se lleno todo amego, pero si queres podes darme un monedita por debajo de la mesa viste",
	],
	"reroll_jammed": [
		"eh ya eta loco no hay mas",
	],
	"drink_chosen": [
		"Elegiste {item}. Salud.",
		"{item}... te va a sentar bien el trago.",
		"Buen trago, mejor elección.",
	],
}

@export_group("Stock")
## Cantidad de artículos a la venta
@export var stock_size: int = 5
## Máximo de mejoras (o tragos misteriosos) entre los artículos
@export var max_upgrades: int = 2
## Probabilidad de que haya solo 1 mejora en vez del máximo
@export_range(0.0, 1.0) var single_upgrade_chance: float = 0.3
## Probabilidad de que una de las mejoras sea un trago misterioso (máximo uno por tienda)
@export_range(0.0, 1.0) var mystery_drink_chance: float = 0.3
@export_group("")
@export_group("Aspecto")
## Posición de la tienda: desplazamiento desde el CENTRO de la pantalla (negativo = a la izquierda)
@export var shop_position: Vector2 = Vector2(-220, 0)
## Imagen de fondo de la tienda (vacío = el icono de Godot de placeholder)
@export var shop_background: Texture2D
@export_group("Reroll")
## Puntos que gasta cada vez que se aprieta el botón de reroll
@export var reroll_cost: int = 1
## Cuánto sube el precio del reroll cada vez que se usa
@export var reroll_cost_increase: int = 1
## Probabilidad de que el frasco se atasque en cada reroll (0.05 = 5%)
@export_range(0.0, 1.0) var jam_chance: float = 0.05
## Cuánto suma esa probabilidad cada vez que los artículos cambian (0.01 = 1%)
@export_range(0.0, 1.0) var jam_chance_increase: float = 0.01
## Probabilidad de que el reroll renueve todos los artículos (0.2 = 1 de cada 5)
@export_range(0.0, 1.0) var reroll_chance: float = 0.2
## Sprite del botón de reroll (placeholder: cambialo por el tuyo)
@export var reroll_icon: Texture2D
## Posición del reroll: desplazamiento desde el CENTRO de la pantalla hasta el centro de su sprite
## (negativo en x = a la izquierda). Es independiente del fondo de la tienda.
@export var reroll_position: Vector2 = Vector2(-480, 0)
@export_group("NPC")
## Segundos que se ve la frase del NPC
@export var dialog_time: float = 3.0
## Sprite del NPC (placeholder: cambialo por el tuyo)
@export var npc_icon: Texture2D
## El sprite del NPC es una hoja de frames: columnas y filas (igual que Hframes y Vframes de Sprite2D)
@export var npc_hframes: int = 7
@export var npc_vframes: int = 1
## Velocidad de la animación del NPC, en frames por segundo (0 = quieto en el primer frame)
@export var npc_fps: float = 8.0
## Tamaño del sprite del NPC en el menú (en píxeles de pantalla)
@export var npc_size: Vector2 = Vector2(160, 160)
## Posición del NPC en el menú: desplazamiento desde el CENTRO de la pantalla hasta el centro de su sprite
## (x positivo = a la derecha, y positivo = hacia abajo)
@export var npc_position: Vector2 = Vector2(400, 120)

var _stock: Array = []
var _stocked: bool = false
## Mejoras que todavía pueden salir. Las que se ofrecen (aunque después se renueven con un
## reroll) se sacan de acá y no vuelven a aparecer en toda la run.
var _upgrade_pool: Array = []
var _player: Node = null
var _menu: ShopMenu = null

@onready var _prompt: Label = $Aviso


func _ready() -> void:
	_prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_menu = ShopMenu.new()
	_menu.shop_position = shop_position
	_menu.shop_background = shop_background
	_menu.reroll_position = reroll_position
	_menu.reroll_cost = reroll_cost
	_menu.reroll_cost_increase = reroll_cost_increase
	_menu.jam_chance = jam_chance
	_menu.jam_chance_increase = jam_chance_increase
	_menu.reroll_chance = reroll_chance
	_menu.reroll_icon = reroll_icon
	_menu.npc_icon = npc_icon
	_menu.npc_hframes = npc_hframes
	_menu.npc_vframes = npc_vframes
	_menu.npc_fps = npc_fps
	_menu.npc_size = npc_size
	_menu.npc_position = npc_position
	_menu.npc_dialogs = NPC_DIALOGS
	_menu.npc_lines = NPC_LINES
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


## Sortea los artículos: hasta `max_upgrades` mejoras (a veces 1; una puede ser un trago
## misterioso) y el resto cartas/objetos hasta completar `stock_size`.
func _make_stock() -> Array:
	if not _stocked:
		_upgrade_pool = ShopPool.upgrade_pool()
	var items: Array = []
	var slots := 1 if randf() < single_upgrade_chance else max_upgrades
	var has_drink := false
	for i in slots:
		if not has_drink and randf() < mystery_drink_chance:
			has_drink = true
			items.append(ShopPool.mystery_drink())
		elif not _upgrade_pool.is_empty():
			# Sale de la pool: no se repite nunca más
			var upgrade: Upgrade = _upgrade_pool.pop_at(randi() % _upgrade_pool.size())
			items.append(ShopPool.upgrade_item(upgrade))
	# El resto: cartas y objetos (si no alcanzan para llenar, se repiten)
	var guard := 0
	while items.size() < stock_size and guard < 10:
		guard += 1
		var others: Array = ShopPool.cards() + ShopPool.objects()
		others.shuffle()
		items.append_array(others.slice(0, stock_size - items.size()))
	return items


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
