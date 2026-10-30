extends "../character_stats.gd"
## Rebecca: lanza fuego con su libro. Stats base IGUALES a Band (después se ajustan acá).
## Pasiva: cada vez que su básico conecta genera un orbe de fuego que orbita a su alrededor.
## Habilidad (E): lanza todos los orbes en línea recta.

const OrbThrowAbility := preload("lanzar_orbes_ability.gd")
const FirePassive := preload("rebecca_passive.gd")
## Bala de fuego (placeholder: el sprite de la bala de Band teñido de naranja; cambiale el sprite en bala_fuego.tscn)
const FireBullet := preload("bala_fuego.tscn")


func _init() -> void:
	display_name = "Rebecca"
	# Sin cambios de stats (mismos que Band). Para tocarlos:
	#   player_overrides = {"max_health": 90.0}
	weapon_overrides = {"bullet_lifetime": 6.0}
	ability_script = OrbThrowAbility
	passive_script = FirePassive
	bullet_scene = FireBullet
	weapon_look = {"texture": preload("res://sprites/fugo.png"), "scale": Vector2(0.2, 0.2),
		"position": Vector2(11, -4), "rotation_degrees": -90.0, "muzzle_position": Vector2(23, -8)}
