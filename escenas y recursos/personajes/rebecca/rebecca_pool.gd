extends RefCounted
## Pool de mejoras propias de Rebecca (se suman a las genéricas de UpgradePool).

const EscudoAbility := preload("escudo_ardiente_ability.gd")
## Carta propia (placeholder: la de Band, hasta que Rebecca tenga la suya)
const RebeccaCard := preload("../band/band_card.tscn")
## Carpeta de los iconos de las mejoras de Rebecca (PNG). Si falta el archivo se usa icon.svg.
const ICON_DIR := "res://sprites/mejoras/rebecca/"


func create_upgrades() -> Array:
	var C := Upgrade.Category
	var upgrades: Array = [
		Upgrade.new("Algo se prende fuego", "Podés tener 2 orbes de fuego más a la vez (5 en total)", C.PLAYER,
			func(_w, p):
				var passive = p.get_passive()
				if passive != null:
					passive.max_orbs += 2).once().with_icon(ICON_DIR + "algo_se_prende_fuego.png"),

		Upgrade.new("Corazón en llamas", "Los orbes roban vida: curan a Rebecca el 50% del daño que hacen", C.PLAYER,
			func(_w, p):
				var passive = p.get_passive()
				if passive != null:
					passive.lifesteal_ratio = 0.5).once().with_icon(ICON_DIR + "corazon_en_llamas.png"),

		Upgrade.new("Protección ardiente", "Tu E pasa a ser un escudo de invencibilidad con más velocidad. No podés atacar mientras dura y al terminar se apagan todos tus orbes", C.ABILITY,
			func(_w, p): p.set_ability_script(EscudoAbility)).once().with_icon(ICON_DIR + "proteccion_ardiente.png"),
	]
	for upgrade in upgrades:
		upgrade.card_scene = RebeccaCard
	return upgrades
