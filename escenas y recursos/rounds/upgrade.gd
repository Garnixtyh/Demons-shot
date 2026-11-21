class_name Upgrade
extends RefCounted
## Una mejora de ronda: un nombre, una descripción y un efecto que se aplica
## a los atributos del arma (WeaponStats) y/o del jugador.

enum Category { BULLET, WEAPON, PLAYER, ABILITY }

var title: String
var description: String
var category: Category
## true = solo se puede elegir una vez (después sale de la pool)
var unique: bool = false
## Cuántas copias se pueden tener como máximo (0 = sin límite). `once()` lo deja en 1.
## Al llegar al límite la mejora ya no sale en la tienda ni en las mejoras aleatorias.
var max_count: int = 0
## Ruta del PNG del icono que se muestra en la carta ("" = icono de reemplazo)
var icon_path: String = ""
## Carta propia (para las mejoras de un personaje). null = la carta por defecto
var card_scene: PackedScene = null
var _effect: Callable


func _init(p_title: String, p_description: String, p_category: Category, p_effect: Callable) -> void:
	title = p_title
	description = p_description
	category = p_category
	_effect = p_effect


## Marca la mejora como única. Se usa así: Upgrade.new(...).once()
func once() -> Upgrade:
	unique = true
	max_count = 1
	return self


## Limita cuántas copias se pueden tener. Se usa así: Upgrade.new(...).with_max(3)
func with_max(count: int) -> Upgrade:
	max_count = count
	return self


## true si el jugador todavía puede agarrar esta mejora (no llegó al límite de copias)
func can_take(player: Node) -> bool:
	if max_count <= 0:
		return true
	if player == null or not player.has_method("get_item_count"):
		return true
	return player.get_item_count(title) < max_count


## Le pone el icono de la carta. Se usa así: Upgrade.new(...).with_icon("res://...png")
func with_icon(path: String) -> Upgrade:
	icon_path = path
	return self


## Le pone una carta propia (escena basada en upgrade_card.tscn)
func with_card(scene: PackedScene) -> Upgrade:
	card_scene = scene
	return self


func apply(stats: WeaponStats, player: Node) -> void:
	_effect.call(stats, player)
	# El jugador anota la mejora (la lista de items del menú de pausa)
	if player != null and player.has_method("register_item"):
		player.register_item(self)


func category_name() -> String:
	match category:
		Category.BULLET:
			return "BALA"
		Category.WEAPON:
			return "ARMA"
		Category.ABILITY:
			return "HABILIDAD"
		_:
			return "JUGADOR"
