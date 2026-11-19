class_name PhaseModifiers
extends RefCounted
## Modificadores de la última fase (la 3). Al empezar la fase se sortea uno y dura hasta que se completa.
## Para agregar uno nuevo: sumá un diccionario a LIST y manejá su "id" en apply_to_player /
## remove_from_player (efectos sobre el jugador) y/o apply_to_enemy (efectos sobre cada enemigo que aparece).

## Placeholder de los íconos (cambialos por los sprites definitivos)
const ICON_PLACEHOLDER := preload("res://icon.svg")

const LIST: Array[Dictionary] = [
	{
		"id": "david_goliat",
		"name": "David vs. Goliat",
		"description": "Los enemigos son más grandes y tú eres más pequeño.",
		"icon": ICON_PLACEHOLDER,
	},
	{
		"id": "cuchillos",
		"name": "Pelea con cuchillos",
		"description": "Los enemigos cuerpo a cuerpo tienen cuchillos y te hacen sangrar.",
		"icon": ICON_PLACEHOLDER,
	},
	{
		"id": "precisos",
		"name": "Enemigos precisos",
		"description": "No puedes usar el parry en esta fase.",
		"icon": ICON_PLACEHOLDER,
	},
]

# David vs. Goliat
const PLAYER_SCALE := 1.4
const PLAYER_NORMAL_SCALE := 2.0
const PLAYER_DAMAGE_FACTOR := 0.5
const ENEMY_SCALE_FACTOR := 1.3
const ENEMY_EXTRA_DAMAGE := 10.0
# Pelea con cuchillos
const KNIFE_SCALE := Vector2(0.1, 0.1)
const KNIFE_OFFSET := Vector2(18.0, 4.0)


static func pick(rng: RandomNumberGenerator) -> Dictionary:
	return LIST[rng.randi() % LIST.size()]


static func apply_to_player(player: Node, id: String) -> void:
	match id:
		"david_goliat":
			player.set_body_scale(PLAYER_SCALE)
			var weapon = player.get_weapon()
			if weapon != null and weapon.stats != null:
				weapon.stats.damage *= PLAYER_DAMAGE_FACTOR
			player.melee_damage *= PLAYER_DAMAGE_FACTOR
			player.incoming_damage_bonus += ENEMY_EXTRA_DAMAGE
		"precisos":
			player.parry_blocked = true


static func remove_from_player(player: Node, id: String) -> void:
	if not is_instance_valid(player):
		return
	match id:
		"david_goliat":
			player.set_body_scale(PLAYER_NORMAL_SCALE)
			var weapon = player.get_weapon()
			if weapon != null and weapon.stats != null:
				weapon.stats.damage /= PLAYER_DAMAGE_FACTOR
			player.melee_damage /= PLAYER_DAMAGE_FACTOR
			player.incoming_damage_bonus -= ENEMY_EXTRA_DAMAGE
		"precisos":
			player.parry_blocked = false


## Se llama con cada enemigo ya agregado a la sala
static func apply_to_enemy(enemy: Node, id: String) -> void:
	match id:
		"david_goliat":
			if enemy is Node2D:
				(enemy as Node2D).scale *= ENEMY_SCALE_FACTOR
		"cuchillos":
			# Solo los que dañan por contacto (cuerpo a cuerpo)
			if enemy.get_node_or_null("Contacto") == null:
				return
			enemy.set("knife_bleed", true)
			var parent: Node = enemy.get("_visual") as Node
			if parent == null:
				parent = enemy
			var knife := Sprite2D.new()
			knife.name = "Cuchillo"
			knife.texture = ICON_PLACEHOLDER
			knife.scale = KNIFE_SCALE
			knife.position = KNIFE_OFFSET
			parent.add_child(knife)
