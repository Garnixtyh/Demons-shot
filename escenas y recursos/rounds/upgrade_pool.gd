class_name UpgradePool
extends RefCounted
## Catálogo de todas las mejoras posibles. Para agregar una nueva,
## sumá una línea a la lista: título, descripción, categoría y efecto.
## Con .with_icon("archivo.png") le ponés el icono que se ve en su carta
## (se busca en ICON_DIR; si el archivo no existe se usa un icono de reemplazo).
## Todas se pueden acumular (elegirlas varias veces).

## Carpeta de los iconos de las mejoras (PNG)
const ICON_DIR := "res://sprites/mejoras/iconos/"


static func create_all() -> Array:
	var C := Upgrade.Category
	return [
	
	# mejoras stackeables 
	Upgrade.new("Balas pesadas", " tengo las balas pesadas de lo digo claude +10% de daño", C.BULLET,
		func(w: WeaponStats, _p): w.damage *= 1.10).with_icon(ICON_DIR + "bala_daño.png"),
	
	Upgrade.new("A TODA GARCHA", " ejem digo marcha.... +30% de alcance", C.BULLET,
		func(w: WeaponStats, _p): w.bullet_lifetime *= 1.3).with_icon(ICON_DIR + "largo_alcance.png"),
	
	Upgrade.new("apura el tramite", "-15% de tiempo de recarga", C.WEAPON,
		func(w: WeaponStats, _p): w.reload_time *= 0.15).with_icon(ICON_DIR + "tramite.png"),
	
	Upgrade.new("Balas que Sobraron", "+2 de capacidad del cargador", C.WEAPON,
		func(w: WeaponStats, _p): w.magazine_size = ceili(w.magazine_size + 2)).with_icon(ICON_DIR + "sobras.png"),
	
	Upgrade.new("RA TA TATATATA", "+10% de cadencia de disparo", C.WEAPON,
		func(w: WeaponStats, _p): w.fire_rate *= 1.10).with_icon(ICON_DIR + "cadencia_alta.png"),
	
	Upgrade.new("Corazon grande", "+25 de vida máxima", C.PLAYER,
		func(_w, p): p.add_max_health(25.0)).with_icon(ICON_DIR + "vitalidad.png"),
	
	Upgrade.new("Piernas veloces", "+25% de velocidad", C.PLAYER,
		func(_w, p): p.max_speed *= 1.25).with_icon(ICON_DIR + "velocidad.png"),
	
	Upgrade.new("El tamaño si importa", "Balas más grandes", C.BULLET,
		func(w: WeaponStats, _p):
			w.bullet_scale *= 1.8
			w.magazine_size = maxi(1, roundi(w.magazine_size * 0.7))).with_icon(ICON_DIR + "bala_ancha.png"),
	

	# --- NO STACKEABLE ---
	Upgrade.new("bala por bala vida por vida", "+50% de vida maxima, -70% de daño", C.BULLET,
		func(w: WeaponStats, p):
			w.damage *= 0.5
			p.add_max_health(+p.max_health * 1.7)).with_icon(ICON_DIR + "bala_porvida.png"),

	Upgrade.new("Bala de cristal", "+50% de daño, -70% de vida máxima", C.BULLET,
		func(w: WeaponStats, p):
			w.damage *= 1.5
			p.add_max_health(-p.max_health * 0.7)).with_icon(ICON_DIR + "bala_cristal.png"),

	Upgrade.new("Veneno", "el ataque basico inflige veneno.", C.BULLET,
		func(w: WeaponStats, _p):
			w.poison_ratio += 0.10).with_icon(ICON_DIR + "veneno.png"),

	Upgrade.new("Tercer_ojo", "Disparás 3 balas a la vez, -40% de cadencia", C.WEAPON,
		func(w: WeaponStats, _p):
			w.bullets_per_shot += 2
			w.fire_rate *= 0.6).with_icon(ICON_DIR + "ojo_alpiojo.png"),

	Upgrade.new("Saluda a mi amiguito", "+15 de cargador, +50% de cadencia, -40% de daño", C.WEAPON,
		func(w: WeaponStats, _p):
			w.magazine_size += 15
			w.fire_rate *= 1.5
			w.damage *= 0.6).with_icon(ICON_DIR + "metralleta.png"),
	
	]
