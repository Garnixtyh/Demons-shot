extends "../character_stats.gd"
## Rebecca: lanza fuego con su libro. Stats base IGUALES a Band (después se ajustan acá).
## Pasiva: cada vez que su básico conecta genera un orbe de fuego que orbita a su alrededor.
## Habilidad (E): lanza todos los orbes en línea recta.

const OrbThrowAbility := preload("lanzar_orbes_ability.gd")
const FirePassive := preload("rebecca_passive.gd")


func _init() -> void:
	display_name = "Rebecca"
	# Sin cambios de stats (mismos que Band). Para tocarlos:
	#   player_overrides = {"max_health": 90.0}
	#   weapon_overrides = {"damage": 18.0}
	ability_script = OrbThrowAbility
	passive_script = FirePassive
