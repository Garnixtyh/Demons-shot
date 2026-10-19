extends "../character_stats.gd"
## Band: el personaje base. Stats base + habilidad (E).

const TermoAbility := preload("termo_ability.gd")


func _init() -> void:
	display_name = "Band"
	# Sin cambios de stats: usa los valores del player.tscn y del arma.
	# (Ver player_overrides / weapon_overrides en character_stats.gd)
	ability_script = TermoAbility
