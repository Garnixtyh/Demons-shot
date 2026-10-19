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
	return self


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
