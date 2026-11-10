class_name ShopPool
extends RefCounted
## Catálogo de lo que puede vender la tienda. De acá el Shopkeeper sortea su stock.
##  - Mejoras: las de UpgradePool (genéricas) + las del personaje del jugador.
##  - Cartas: cada cara de CartaTarot.CARDS (nombre, icono y descripción salen de ahí).
##  - Objetos: consumibles con escena propia; se agregan a OBJECTS.

## Precios en puntos (cambialos a gusto)
const UPGRADE_PRICE := 10
const UNIQUE_UPGRADE_PRICE := 15
const CARD_PRICE := 8
const MYSTERY_DRINK_PRICE := 20
## Cuántas mejoras se ofrecen al abrir el trago misterioso
const MYSTERY_DRINK_CHOICES := 3
## Icono del trago misterioso (si el archivo no existe usa el icon.svg de placeholder)
const MYSTERY_DRINK_ICON := "res://sprites/mejoras/iconos/caja.png"

const CARD_SCENE := preload("res://escenas y recursos/consumibles/carta_tarot/carta_tarot.tscn")
const FALLBACK_ICON := preload("res://icon.svg")

## Objetos extra (consumibles con su propia escena, hijos de Consumable). Cada uno es:
##   {"scene": PackedScene, "price": int, "name": String, "description": String, "icon": Texture2D}
## El "Trago misterioso" ya viene incluido (ver mystery_drink()), no hace falta ponerlo acá.
const OBJECTS: Array[Dictionary] = []


## Mejoras que puede vender la tienda: SOLO las genéricas. Las de cada personaje salen
## únicamente en el trago misterioso (ver upgrade_options).
## El Shopkeeper guarda esta lista durante la run y va sacando las que ya se ofrecieron.
static func upgrade_pool() -> Array:
	return UpgradePool.create_all()


## Artículo de tienda para una mejora
static func upgrade_item(upgrade: Upgrade) -> ShopItem:
	var item := ShopItem.new()
	item.kind = ShopItem.Kind.UPGRADE
	item.upgrade = upgrade
	item.title = upgrade.title
	item.description = upgrade.description.strip_edges()
	item.price = UNIQUE_UPGRADE_PRICE if upgrade.unique else UPGRADE_PRICE
	item.icon = _load_icon(upgrade.icon_path)
	return item


static func cards() -> Array:
	var result: Array = []
	for i in CartaTarot.CARDS.size():
		var card: Dictionary = CartaTarot.CARDS[i]
		var item := ShopItem.new()
		item.kind = ShopItem.Kind.CARD
		item.scene = CARD_SCENE
		item.card_index = i
		item.title = card["name"]
		item.description = card.get("description", "Dura %s segundos." % card["duration"])
		item.price = card.get("price", CARD_PRICE)
		item.icon = card["icon"]
		result.append(item)
	return result


static func objects() -> Array:
	var result: Array = []
	for entry in OBJECTS:
		var item := ShopItem.new()
		item.kind = ShopItem.Kind.OBJECT
		item.scene = entry["scene"]
		item.title = entry["name"]
		item.description = entry.get("description", "")
		item.price = entry["price"]
		item.icon = entry.get("icon", FALLBACK_ICON)
		result.append(item)
	return result


## Trago misterioso: al comprarlo se abre el selector de mejoras (como al pasar de ronda) y se elige
## una entre MYSTERY_DRINK_CHOICES al azar (genéricas + las del personaje). No va al bolsillo.
static func mystery_drink() -> ShopItem:
	var item := ShopItem.new()
	item.kind = ShopItem.Kind.OBJECT
	item.title = "Trago misterioso"
	item.description = "Al tomarlo elegís una mejora entre %d, como al pasar de ronda." % MYSTERY_DRINK_CHOICES
	item.price = MYSTERY_DRINK_PRICE
	item.icon = _load_icon(MYSTERY_DRINK_ICON)
	item.upgrade_choices = MYSTERY_DRINK_CHOICES
	return item


## `count` mejoras al azar (sin repetir) para el selector del trago: genéricas + las del personaje
static func upgrade_options(player: Node, count: int) -> Array:
	var all: Array = UpgradePool.create_all()
	if player != null and player.has_method("get_character_upgrades"):
		all.append_array(player.get_character_upgrades())
	return pick(all, count)


## `count` artículos al azar sin repetir
static func pick(items: Array, count: int) -> Array:
	var copy := items.duplicate()
	copy.shuffle()
	return copy.slice(0, maxi(count, 0))


static func _load_icon(path: String) -> Texture2D:
	if not path.is_empty() and ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			return texture
	return FALLBACK_ICON
