class_name Upgrade
extends RefCounted
## Una mejora de ronda: un nombre, una descripción y un efecto que se aplica
## a los atributos del arma (WeaponStats) y/o del jugador.

enum Category { BULLET, WEAPON, PLAYER }

var title: String
var description: String
var category: Category
var _effect: Callable


func _init(p_title: String, p_description: String, p_category: Category, p_effect: Callable) -> void:
	title = p_title
	description = p_description
	category = p_category
	_effect = p_effect


func apply(stats: WeaponStats, player: Node) -> void:
	_effect.call(stats, player)


func category_name() -> String:
	match category:
		Category.BULLET:
			return "BALA"
		Category.WEAPON:
			return "ARMA"
		_:
			return "JUGADOR"
