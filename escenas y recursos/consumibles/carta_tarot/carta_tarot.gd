class_name CartaTarot
extends Consumable
## Carta de tarot. En el mapa siempre se ve con el sprite "carta"; al aparecer elige AL AZAR
## una de las caras de CARDS. Esa cara es la que se ve en el bolsillo del HUD y la que da el efecto.
##
## Cada cara es un diccionario:
##   "name":            nombre que se ve en el HUD
##   "duration":        segundos que dura el efecto
##   "icon":            sprite que se ve en el HUD
##   "invincibility":   (opcional) true = invencible mientras dura
##   "weapon_multiply": (opcional) { stat del arma: multiplicador }   ej: {"bullet_scale": 1.5}
##   "weapon_add":      (opcional) { stat del arma: suma }            ej: {"damage": 2.0}
##   "player_add":      (opcional) { variable del jugador: suma }     ej: {"max_speed": 1.0}
## Al terminar el efecto, los stats vuelven exactamente a como estaban (aunque hayas
## agarrado mejoras mientras tanto).
## Para agregar una carta nueva, sumá otro diccionario a la lista.

const CARDS := [
	{
		"name": "The Moon",
		"duration": 2.0,
		"icon": preload("res://sprites/recolectables/tarot/the_moon.png"),
		"invincibility": true,
	},
	{
		"name": "The Emperor",
		"duration": 5.0,
		"icon": preload("res://sprites/recolectables/tarot/the_emperor.png"),
		"weapon_multiply": {"bullet_scale": 1.5},
	},
	{
		"name": "The Empress",
		"duration": 10.0,
		"icon": preload("res://sprites/recolectables/tarot/the_empress.png"),
		"weapon_add": {"damage": 2.0},
		"player_add": {"max_speed": 1.0},
	},
]

## Qué cara de CARDS tiene esta carta (-1 = todavía no se eligió)
var card_index: int = -1

var _stats: WeaponStats = null


func _setup() -> void:
	if LanNetwork.in_lobby:
		# En red elige el host y avisa a todos, así la cara es la misma en todas las PCs
		if GameSession.started:
			_host_pick_card()
		else:
			GameSession.match_started.connect(_host_pick_card, CONNECT_ONE_SHOT)
	else:
		set_card(randi() % CARDS.size())


func _host_pick_card() -> void:
	if multiplayer.is_server():
		_net_set_card.rpc(randi() % CARDS.size())


@rpc("authority", "call_local", "reliable")
func _net_set_card(index: int) -> void:
	set_card(index)


## Pone la cara de la carta (nombre, imagen del HUD y duración).
func set_card(index: int) -> void:
	card_index = clampi(index, 0, CARDS.size() - 1)
	var card: Dictionary = CARDS[card_index]
	display_name = card["name"]
	hud_icon = card["icon"]
	duration = card["duration"]


func _apply_effect(player: Node) -> void:
	if card_index < 0:
		return
	var card: Dictionary = CARDS[card_index]
	if card.get("invincibility", false):
		player.grant_invincibility(duration)
	var weapon = player.get_weapon()
	_stats = weapon.stats if weapon != null else null
	if _stats != null:
		for stat in card.get("weapon_multiply", {}):
			_stats.set(stat, _stats.get(stat) * card["weapon_multiply"][stat])
		for stat in card.get("weapon_add", {}):
			_stats.set(stat, _stats.get(stat) + card["weapon_add"][stat])
	for variable in card.get("player_add", {}):
		player.set(variable, player.get(variable) + card["player_add"][variable])


func _remove_effect(player: Node) -> void:
	if card_index < 0:
		return
	var card: Dictionary = CARDS[card_index]
	if _stats != null:
		for stat in card.get("weapon_multiply", {}):
			_stats.set(stat, _stats.get(stat) / card["weapon_multiply"][stat])
		for stat in card.get("weapon_add", {}):
			_stats.set(stat, _stats.get(stat) - card["weapon_add"][stat])
	for variable in card.get("player_add", {}):
		player.set(variable, player.get(variable) - card["player_add"][variable])
