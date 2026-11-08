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
const MYSTERY_BOX_PRICE := 20
## Cuántas mejoras se ofrecen al abrir la caja misteriosa
const MYSTERY_BOX_CHOICES := 3
## Icono de la caja misteriosa (si el archivo no existe usa el icon.svg de placeholder)
const MYSTERY_BOX_ICON := "res://sprites/mejoras/iconos/caja.png"

const CARD_SCENE := preload("res://escenas y recursos/consumibles/carta_tarot/carta_tarot.tscn")
const FALLBACK_ICON := preload("res://icon.svg")

## Objetos extra (consumibles con su propia escena, hijos de Consumable). Cada uno es:
##   {"scene": PackedScene, "price": int, "name": String, "description": String, "icon": Texture2D}
## La "Caja misteriosa" ya viene incluida (ver mystery_box()), no hace falta ponerla acá.
const OBJECTS: Array[Dictionary] = []


static func upgrades(player: Node) -> Array:
	var all: Array = UpgradePool.create_all()
	if player != null and player.has_method("get_character_upgrades"):
		all.append_array(player.get_character_upgrades())
	var result: Array = []
	for upgrade: Upgrade in all:
		var item := ShopItem.new()
		item.kind = ShopItem.Kind.UPGRADE
		item.upgrade = upgrade
		item.title = upgrade.title
		item.description = upgrade.description.strip_edges()
		item.price = UNIQUE_UPGRADE_PRICE if upgrade.unique else UPGRADE_PRICE
		item.icon = _load_icon(upgrade.icon_path)
		result.append(item)
	return result


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
	var result: Array = [mystery_box()]
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


## Objeto que, al comprarlo, abre el selector de mejoras (como al pasar de ronda): se elige una
## entre MYSTERY_BOX_CHOICES al azar (genéricas + las del personaje). No va al bolsillo.
static func mystery_box() -> ShopItem:
	var item := ShopItem.new()
	item.kind = ShopItem.Kind.OBJECT
	item.title = "Caja misteriosa"
	item.description = "Al comprarla elegís una mejora entre %d, como al pasar de ronda." % MYSTERY_BOX_CHOICES
	item.price = MYSTERY_BOX_PRICE
	item.icon = _load_icon(MYSTERY_BOX_ICON)
	item.upgrade_choices = MYSTERY_BOX_CHOICES
	return item


## `count` mejoras al azar (sin repetir) para el selector de mejoras
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
