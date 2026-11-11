class_name CartaTarot
extends Consumable
## Carta de tarot. En el mapa siempre se ve con el sprite "carta"; al aparecer elige AL AZAR
## una de las caras de CARDS. Esa cara es la que se ve en el bolsillo del HUD y la que da el efecto.
##
## Cada cara es un diccionario:
##   "name":            nombre que se ve en el HUD
##   "duration":        segundos que dura el efecto
##   "icon":            sprite que se ve en el HUD
##   "description":     texto que se ve en la tienda
##   "invincibility":   (opcional) true = invencible mientras dura
##   "weapon_multiply": (opcional) { stat del arma: multiplicador }   ej: {"bullet_scale": 1.5}
##   "weapon_add":      (opcional) { stat del arma: suma }            ej: {"damage": 2.0}
##   "player_add":      (opcional) { variable del jugador: suma }     ej: {"max_speed": 1.0}
##   "effect":          (opcional) efecto especial hecho en código (ver _run_effect / _end_effect)
## Al terminar el efecto, los stats vuelven exactamente a como estaban (aunque hayas
## agarrado mejoras mientras tanto).
## Para agregar una carta nueva, sumá otro diccionario a la lista.

const PanchuScene := preload("res://escenas y recursos/personajes/band/panchu.tscn")
const BarrelScene := preload("res://recursos mapas/barril_explosivo.tscn")
const RebeccaPassive := preload("res://escenas y recursos/personajes/rebecca/rebecca_passive.gd")
## Escena de esta misma carta (se carga al usarla para no hacer un preload circular)
const CARD_SCENE_PATH := "res://escenas y recursos/consumibles/carta_tarot/carta_tarot.tscn"
const SelectorScene := preload("res://escenas y recursos/rounds/upgrade_selector.tscn")

## The Hierophant: orbes de fuego que genera
const HIEROPHANT_ORBS := 5
## The Magician: segundos que acorta las recargas
const MAGICIAN_SECONDS := 10.0
## The Hermit: cuánto suma al "xN" del combo
const HERMIT_BONUS := 1
## The World: segundos que congela el combo
const WORLD_FREEZE := 1.9
## The Death: daño a cada enemigo de la sala
const DEATH_DAMAGE := 20.0
## The Devil: vida que quita (fracción de la vida MÁXIMA, se resta de la vida actual) y puntos que da
const DEVIL_LIFE_LOSS := 0.5
const DEVIL_POINTS := 20
## The Sun: balas que dispara y ángulo entre una y otra (grados)
const SUN_BULLETS := 5
const SUN_FAN_DEGREES := 8.0
## Strength: escala del jugador mientras dura (pequeño), escala normal a la que vuelve, y bonus de velocidad (0.5 = +50%)
const STRENGTH_SCALE := 1.0
const NORMAL_SCALE := 2.0
const STRENGTH_SPEED_BONUS := 0.5
## The Hanged Man: lo que suma la escopeta (igual que la mejora "Escopeta" de Band)
const SHOTGUN_EXTRA_BULLETS := 4
const SHOTGUN_FAN_DEGREES := 7.0
const SHOTGUN_EXTRA_SPREAD := 4.0
const SHOTGUN_FIRE_RATE_MULT := 0.5
const SHOTGUN_LIFETIME_DIV := 1.5
## Wheel of Fortune: chances (suman 1.0): nada, otro consumible, carta del tarot y trago misterioso
const WHEEL_NOTHING := 0.4
const WHEEL_CONSUMABLE := 0.3
const WHEEL_CARD := 0.2
const WHEEL_DRINK := 0.1

const CARDS := [
	{
		"name": "The Moon",
		"duration": 2.0,
		"icon": preload("res://sprites/recolectables/tarot/the_moon.png"),
		"description": "Invencibilidad durante 2 segundos.",
		"invincibility": true,
	},
	{
		"name": "The Emperor",
		"duration": 35.0,
		"icon": preload("res://sprites/recolectables/tarot/the_emperor.png"),
		"description": "Balas un 50% más grandes durante 35 segundos.",
		"weapon_multiply": {"bullet_scale": 1.5},
	},
	{
		"name": "The Empress",
		"duration": 30.0,
		"icon": preload("res://sprites/recolectables/tarot/the_empress.png"),
		"description": "+2 de daño y +1 de velocidad durante 10 segundos.",
		"weapon_add": {"damage": 2.0},
		"player_add": {"max_speed": 100.0},
	},
	{
		"name": "The Lovers",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_lovers.png"),
		"description": "Cura el 30 puntos de salud.",
		"player_add": {"health": 30.0}
	},
	{
		"name": "The Fool",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_fool.png"),
		"description": "Cobra ya los puntos actuales del combo (el combo sigue).",
		"effect": "fool",
	},
	{
		"name": "The Magician",
		"duration": 10.0,
		"icon": preload("res://sprites/recolectables/tarot/the_magician.png"),
		"description": "Reduce 10 segundos la recarga de todas tus habilidades.",
		"effect": "magician",
	},
	{
		"name": "The Hierophant",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_hierophant.png"),
		"description": "Genera 5 orbes de fuego de Rebecca a tu alrededor.",
		"effect": "hierophant",
	},
	{
		"name": "The Chariot",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_chariot.png"),
		"description": "Invoca a Panchu para que ataque a un enemigo.",
		"effect": "chariot",
	},
	{
		"name": "Justice",
		"duration": 10.0,
		"icon": preload("res://sprites/recolectables/tarot/justice.png"),
		"description": "Durante 10 segundos, los enemigos que te toquen sangran.",
		"effect": "justice",
	},
	{
		"name": "The Hermit",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_hermit.png"),
		"description": "+1x al combo actual.",
		"effect": "hermit",
	},
	{
		"name": "Wheel of Fortune",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/wheel_of_fortune.png"),
		"description": "40% nada, 30% otro consumible, 20% una carta del tarot, 10% un trago misterioso.",
		"effect": "wheel",
	},
	{
		"name": "Strength",
		"duration": 10.0,
		"icon": preload("res://sprites/recolectables/tarot/strength.png"),
		"description": "Durante 10 segundos sos un 50% más pequeño y un 50% más rápido.",
		"effect": "strength",
	},
	{
		"name": "The Hanged Man",
		"duration": 5.0,
		"icon": preload("res://sprites/recolectables/tarot/the_hanged_man.png"),
		"description": "Durante 5 segundos tu arma es la escopeta (se acumula).",
		"effect": "hanged_man",
	},
	{
		"name": "The World",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_world.png"),
		"description": "Congela el combo durante 1,9 segundos.",
		"effect": "world",
	},
	{
		"name": "The Death",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_death.png"),
		"description": "20 de daño a todos los enemigos de la sala.",
		"effect": "death",
	},
	{
		"name": "The Devil",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_devil.png"),
		"description": "Perdés vida (50% de tu vida máxima) a cambio de 20 puntos.",
		"effect": "devil",
	},
	{
		"name": "The Tower",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_tower.png"),
		"description": "Invoca el poder de 2 tanques de gas a tus lados.",
		"effect": "tower",
	},
	{
		"name": "The Sun",
		"duration": 0.0,
		"icon": preload("res://sprites/recolectables/tarot/the_sun.png"),
		"description": "Dispara 5 balas de tu arma de golpe.",
		"effect": "sun",
	},
]

## Qué cara de CARDS tiene esta carta (-1 = todavía no se eligió)
var card_index: int = -1

var _stats: WeaponStats = null


func _setup() -> void:
	# Si ya tiene cara (por ejemplo, comprada en la tienda), no se vuelve a elegir
	if card_index >= 0:
		return
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
	_run_effect(card.get("effect", ""), player)


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
	_end_effect(card.get("effect", ""), player)


# ---------------------------------------------------------------- Efectos especiales

## Cambio de velocidad que aplicó Strength (para sacarlo exacto al terminar)
var _speed_delta: float = 0.0


func _run_effect(effect: String, player: Node) -> void:
	match effect:

		"fool":
			var combo = player.get_combo()
			if combo != null:
				combo.cash_out()
		"magician":
			player.reduce_cooldowns(MAGICIAN_SECONDS)
		"hierophant":
			_spawn_fire_orbs(player)
		"chariot":
			_summon_panchu(player)
		"justice":
			player.grant_justice(duration)
		"hermit":
			var combo = player.get_combo()
			if combo != null:
				combo.add_multiplier(HERMIT_BONUS)
		"wheel":
			_spin_wheel(player)
		"strength":
			_speed_delta = player.max_speed * STRENGTH_SPEED_BONUS
			player.max_speed += _speed_delta
			_stack_meta(player, "strength_stacks", 1)
			player.set_body_scale(STRENGTH_SCALE)
		"hanged_man":
			_shotgun_on(player)
		"world":
			var combo = player.get_combo()
			if combo != null:
				combo.freeze(WORLD_FREEZE)
		"death":
			_smite_enemies()
		"devil":
			player.lose_health(player.max_health * DEVIL_LIFE_LOSS)
			player.add_points(DEVIL_POINTS)
		"tower":
			_summon_tanks(player)
		"sun":
			var weapon = player.get_weapon()
			if weapon != null:
				weapon.fire_extra_bullets(SUN_BULLETS, SUN_FAN_DEGREES)


func _end_effect(effect: String, player: Node) -> void:
	match effect:
		"strength":
			player.max_speed -= _speed_delta
			if _stack_meta(player, "strength_stacks", -1) <= 0:
				player.set_body_scale(NORMAL_SCALE)
		"hanged_man":
			_shotgun_off(player)


## Suma `amount` a un contador guardado en el jugador y devuelve el nuevo valor.
func _stack_meta(holder: Object, key: String, amount: int) -> int:
	var value := int(holder.get_meta(key, 0)) + amount
	holder.set_meta(key, value)
	return value


## The Hierophant: orbes de fuego. Rebecca usa su pasiva; los demás personajes reciben una
## pasiva auxiliar sin generación propia (max_orbs = 0) que solo hace girar estos orbes.
func _spawn_fire_orbs(player: Node) -> void:
	var passive = player.get_passive()
	if passive == null or not passive.has_method("spawn_orbs"):
		passive = player.get_node_or_null("PasivaCarta")
		if passive == null:
			passive = Node.new()
			passive.name = "PasivaCarta"
			passive.set_script(RebeccaPassive)
			passive.max_orbs = 0
			player.add_child(passive)
	passive.spawn_orbs(HIEROPHANT_ORBS)


## The Chariot: Panchu aparece ya lanzado y persigue al enemigo más cercano (igual que su habilidad).
func _summon_panchu(player: Node) -> void:
	var panchu := PanchuScene.instantiate() as Node2D
	panchu.owner_player = player
	var in_net := LanNetwork.in_lobby
	var panchu_name := ""
	if in_net:
		panchu_name = "PanchuCarta_%d_%d" % [multiplayer.get_unique_id(), GameSession.next_object_id()]
		panchu.name = panchu_name
	player.get_tree().current_scene.add_child(panchu)
	panchu.global_position = player.global_position + Vector2(0.0, -60.0)
	panchu.launch()
	if in_net:
		GameSession.net_spawn_panchu.rpc(PanchuScene.resource_path, panchu_name, multiplayer.get_unique_id())
		player.get_tree().create_timer(0.15).timeout.connect(func() -> void:
			if is_instance_valid(panchu):
				panchu.start_network(multiplayer.get_unique_id()))


## The Death: daño a todos los enemigos de la sala SIN alargar el combo (ni el golpe ni el kill).
func _smite_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		if "dead" in enemy and enemy.dead:
			continue
		enemy.combo_silent = true
		enemy.take_damage(DEATH_DAMAGE)
		if is_instance_valid(enemy):
			enemy.combo_silent = false


## The Tower: dos tanques de gas, uno a cada lado. No reaparecen: se borran poco después de explotar.
## (En partida en red no se invocan: los tanques de la tienda de cartas no se sincronizan.)
func _summon_tanks(player: Node) -> void:
	if LanNetwork.in_lobby:
		return
	for side in [-1.0, 1.0]:
		var barrel := BarrelScene.instantiate() as RigidBody2D
		player.get_tree().current_scene.add_child(barrel)
		barrel.global_position = player.side_position(side)
		barrel.exploded.connect(func() -> void:
			barrel.get_tree().create_timer(0.6).timeout.connect(barrel.queue_free))


## The Hanged Man: el arma pasa a ser la escopeta (mismos cambios que la mejora "Escopeta").
## Cada carta suma sus balas/dispersión/cadencia; al terminar la última vuelve el aspecto de antes.
func _shotgun_on(player: Node) -> void:
	var weapon = player.get_weapon()
	if weapon == null:
		return
	var stats: WeaponStats = weapon.stats
	if _stack_meta(stats, "hanged_stacks", 1) == 1:
		stats.set_meta("hanged_previous", {
			"weapon_style": stats.weapon_style,
			"fan_angle_degrees": stats.fan_angle_degrees,
			"automatic": stats.automatic,
			"empties_magazine": stats.empties_magazine,
			"reload_upgrade_multiplier": stats.reload_upgrade_multiplier,
		})
	stats.weapon_style = &"escopeta"
	stats.bullets_per_shot += SHOTGUN_EXTRA_BULLETS
	stats.fan_angle_degrees = SHOTGUN_FAN_DEGREES
	stats.spread_degrees += SHOTGUN_EXTRA_SPREAD
	stats.automatic = false
	stats.fire_rate *= SHOTGUN_FIRE_RATE_MULT
	stats.bullet_lifetime /= SHOTGUN_LIFETIME_DIV
	stats.empties_magazine = true
	stats.reload_upgrade_multiplier = -0.5
	weapon.refresh_visuals()


func _shotgun_off(player: Node) -> void:
	var weapon = player.get_weapon()
	if weapon == null:
		return
	var stats: WeaponStats = weapon.stats
	stats.bullets_per_shot -= SHOTGUN_EXTRA_BULLETS
	stats.spread_degrees -= SHOTGUN_EXTRA_SPREAD
	stats.fire_rate /= SHOTGUN_FIRE_RATE_MULT
	stats.bullet_lifetime *= SHOTGUN_LIFETIME_DIV
	if _stack_meta(stats, "hanged_stacks", -1) <= 0:
		var previous: Dictionary = stats.get_meta("hanged_previous", {})
		for key in previous:
			stats.set(key, previous[key])
	weapon.refresh_visuals()
	weapon.ammo = mini(weapon.ammo, stats.magazine_size)


## Wheel of Fortune: nada, otro consumible, una carta del tarot o un trago misterioso.
func _spin_wheel(player: Node) -> void:
	var roll := randf()
	if roll < WHEEL_NOTHING:
		_float_text(player, "¡Nada!", Color(0.8, 0.8, 0.85))
	elif roll < WHEEL_NOTHING + WHEEL_CONSUMABLE:
		_drop_consumable(player, _random_other_consumable())
	elif roll < WHEEL_NOTHING + WHEEL_CONSUMABLE + WHEEL_CARD:
		_drop_consumable(player, load(CARD_SCENE_PATH) as PackedScene)
	else:
		_open_mystery_drink(player)


## Un consumible que NO sea carta (de ShopPool.OBJECTS). Si todavía no hay ninguno, sale una carta.
func _random_other_consumable() -> PackedScene:
	var scenes: Array = []
	for entry in ShopPool.OBJECTS:
		scenes.append(entry["scene"])
	if scenes.is_empty():
		return load(CARD_SCENE_PATH) as PackedScene
	return scenes.pick_random()


## Deja un consumible en el piso, delante del jugador, saltando un poco.
func _drop_consumable(player: Node, scene: PackedScene) -> void:
	if scene == null:
		return
	var item := scene.instantiate() as Consumable
	if item == null:
		return
	var side := 1.0 if randf() < 0.5 else -1.0
	item.drop(player.get_tree().current_scene, player.global_position + Vector2(0.0, -60.0),
			Vector2(side * 140.0, -260.0))


## Trago misterioso: abre el selector de mejoras (como el de la tienda) y aplica la que elijas.
func _open_mystery_drink(player: Node) -> void:
	var selector := SelectorScene.instantiate() as UpgradeSelector
	selector.pause_game = not LanNetwork.in_lobby
	player.get_tree().current_scene.add_child(selector)
	selector.upgrade_chosen.connect(func(upgrade: Upgrade) -> void:
		var weapon = player.get_weapon()
		upgrade.apply(weapon.stats, player)
		weapon.reset()
		selector.get_tree().create_timer(1.0, true).timeout.connect(selector.queue_free))
	selector.offer(ShopPool.upgrade_options(player, ShopPool.MYSTERY_DRINK_CHOICES), 0, 0,
			"Trago misterioso — elegí una mejora")


## Texto flotante sobre el jugador (sube y se desvanece, mismo estilo que los de la tienda).
func _float_text(player: Node, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	player.get_tree().current_scene.add_child(label)
	label.reset_size()
	label.global_position = player.global_position + Vector2(0.0, -70.0) - label.size * 0.5
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)
