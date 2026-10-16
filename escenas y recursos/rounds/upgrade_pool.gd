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
			func(w: WeaponStats, _p): w.damage *= 1.25),
		Upgrade.new("Balas veloces", "+30% de velocidad de bala", C.BULLET,
			func(w: WeaponStats, _p): w.bullet_speed *= 1.3),
		Upgrade.new("Largo alcance", "+40% de alcance", C.BULLET,
			func(w: WeaponStats, _p): w.bullet_lifetime *= 1.4),
		Upgrade.new("Puntería fina", "-50% de dispersión", C.BULLET,
			func(w: WeaponStats, _p): w.spread_degrees *= 0.5),

		# --- Arma ---
		Upgrade.new("Recarga rápida", "-25% de tiempo de recarga", C.WEAPON,
			func(w: WeaponStats, _p): w.reload_time *= 0.75),
		Upgrade.new("Cargador ampliado", "+50% de capacidad del cargador", C.WEAPON,
			func(w: WeaponStats, _p): w.magazine_size = ceili(w.magazine_size * 1.5)),
		Upgrade.new("Cadencia alta", "+25% de cadencia de disparo", C.WEAPON,
			func(w: WeaponStats, _p): w.fire_rate *= 1.25),
		Upgrade.new("Francotirador", "+60% de daño, -35% de cadencia", C.WEAPON,
			func(w: WeaponStats, _p):
				w.damage *= 1.6
				w.fire_rate *= 0.65),

		# --- Jugador ---
		Upgrade.new("Vitalidad", "+25 de vida máxima", C.PLAYER,
			func(_w, p): p.add_max_health(25.0)),
		Upgrade.new("Piernas veloces", "+15% de velocidad", C.PLAYER,
			func(_w, p): p.max_speed *= 1.15),
		Upgrade.new("Resortes", "+10% de fuerza de salto", C.PLAYER,
			func(_w, p): p.jump_velocity *= 1.1),
	]
