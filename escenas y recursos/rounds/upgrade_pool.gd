class_name UpgradePool
extends RefCounted
## Catálogo de todas las mejoras posibles. Para agregar una nueva,
## sumá una línea a la lista: título, descripción, categoría y efecto.
## Todas se pueden acumular (elegirlas varias veces).


static func create_all() -> Array:
	var C := Upgrade.Category
	return [
		# --- Balas ---
		Upgrade.new("Balas pesadas", "+25% de daño", C.BULLET,
			func(w: WeaponStats, _p): w.damage *= 1.25)
	]
