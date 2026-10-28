extends RefCounted
## Pool de mejoras propias de Band (se suman a las genéricas de UpgradePool).

const PanchuAbility := preload("panchu_ability.gd")
## Carta propia de Band (roja)
const BandCard := preload("band_card.tscn")
## Carpeta de los iconos de las mejoras de Band (PNG)
const ICON_DIR := "res://sprites/mejoras/band/"


func create_upgrades() -> Array:
	var C := Upgrade.Category
	var upgrades: Array = [
		Upgrade.new("Escopeta", "Reemplaza el revólver: 5 perdigones (daño total +150%), -50% de cadencia, menos alcance. Cada disparo vacía el cargador y las mejoras de recarga rinden -50% (al revés)", C.WEAPON,
			func(w: WeaponStats, _p):
				w.weapon_style = &"escopeta"
				w.bullets_per_shot += 4
				w.fan_angle_degrees = 7.0
				w.spread_degrees += 4.0
				w.damage *= 0.5
				w.automatic = false
				w.fire_rate *= 0.5
				w.bullet_lifetime /= 1.5
				w.empties_magazine = true
				w.reload_upgrade_multiplier = -0.5).once().with_icon(ICON_DIR + "escopeta.png"),

		Upgrade.new("Pólvora", "Las balas explotan al impactar (50% del daño en el área)", C.BULLET,
			func(w: WeaponStats, _p):
				if w.explosive_bullets:
					w.explosion_radius *= 1.25
					w.explosion_damage_ratio += 0.15
				else:
					w.explosive_bullets = true
					w.explosion_radius = 80.0
					w.explosion_damage_ratio = 0.5).once().with_icon(ICON_DIR + "polvora.png"),

		Upgrade.new("Panchu", "Tu E pasa a ser Panchu:   al lanzarlo, persigue enemigos y stunea  por 0,5s 7seg recarga ", C.ABILITY,
			func(_w, p): p.set_ability_script(PanchuAbility)).once().with_icon(ICON_DIR + "panchu.png"),
	]
	for upgrade in upgrades:
		upgrade.card_scene = BandCard
	return upgrades
