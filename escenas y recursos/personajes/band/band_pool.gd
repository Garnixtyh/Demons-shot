extends RefCounted
## Pool de mejoras propias de Band (se suman a las genéricas de UpgradePool).

const PanchuAbility := preload("panchu_ability.gd")


func create_upgrades() -> Array:
	var C := Upgrade.Category
	return [
		Upgrade.new("Escopeta", "Reemplaza el revólver: 5 perdigones (daño total +150%), -50% de cadencia, menos alcance", C.WEAPON,
			func(w: WeaponStats, _p):
				w.weapon_style = &"escopeta"
				w.bullets_per_shot += 4
				w.fan_angle_degrees = 7.0
				w.spread_degrees += 4.0
				w.damage *= 0.5
				w.fire_rate *= 0.5
				w.bullet_lifetime *= 0.6).once(),

		Upgrade.new("Pólvora", "Las balas explotan al impactar (50% del daño en el área)", C.BULLET,
			func(w: WeaponStats, _p):
				if w.explosive_bullets:
					w.explosion_radius *= 1.25
					w.explosion_damage_ratio += 0.15
				else:
					w.explosive_bullets = true
					w.explosion_radius = 80.0
					w.explosion_damage_ratio = 0.5),

		Upgrade.new("Panchu", "Reemplaza tu E: Panchu persigue enemigos, cabecea (daño y 0,5 s de aturdimiento). 10 s de cooldown", C.ABILITY,
			func(_w, p): p.set_ability_script(PanchuAbility)).once(),
	]
