extends "../character_stats.gd"
## Band: el personaje base. Stats base + habilidad (E).

const TermoAbility := preload("termo_ability.gd")


func _init() -> void:
	display_name = "Band"
	# Sin cambios de stats: usa los valores del player.tscn y del arma.
	# (Ver player_overrides / weapon_overrides en character_stats.gd)
	
	ability_script = TermoAbility
	weapon_look = {"texture": preload("res://sprites/band/mano2.png"), "scale": Vector2(0.2, 0.2),
	"reload_icon_texture": preload("res://sprites/band/band_recarga.png"),
	"position": Vector2(11, -4), "rotation_degrees": -90.0, "muzzle_position": Vector2(23, -8)}
