class_name ShopItem
extends RefCounted
## Un artículo a la venta en la tienda (ver shop_pool.gd para el catálogo).

enum Kind { UPGRADE, CARD, OBJECT }

var kind: Kind
var title: String
var description: String
var icon: Texture2D
## Precio en puntos del jugador
var price: int
var sold: bool = false

## Solo UPGRADE: la mejora que se aplica al comprar
var upgrade: Upgrade = null
## CARD y OBJECT: escena del consumible que va al bolsillo
var scene: PackedScene = null
## Solo OBJECT sin escena: efecto que se aplica al comprar. Recibe al jugador y devuelve
## el mensaje que se muestra ("" = el de siempre: "Compraste: ...").
var on_buy: Callable = Callable()
## Solo OBJECT: si es mayor que 0, al comprarlo se abre el selector de mejoras (el mismo que
## aparece al pasar de ronda) con esta cantidad de opciones para elegir.
var upgrade_choices: int = 0
## Solo CARD: cara de CartaTarot.CARDS que tiene la carta
var card_index: int = -1


func kind_name() -> String:
	match kind:
		Kind.UPGRADE:
			return "MEJORA · %s" % upgrade.category_name() if upgrade != null else "MEJORA"
		Kind.CARD:
			return "CARTA"
	return "OBJETO"
