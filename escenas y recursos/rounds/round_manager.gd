class_name RoundManager
extends Node
## Maneja las rondas: al empezar cada una ofrece mejoras al jugador y aplica la elegida.
##
## Sin red (modo de pruebas): igual que siempre, una ronda con una mejora a elegir.
##
## En red (LAN): el HOST manda. Cada ronda tiene estas fases:
##   1. ELEGIR: todos quedan quietos y cada uno elige sus mejoras
##      (cantidad y rerolls según la config del lobby).
##   2. PELEAR: cuando todos terminaron, el host manda pelear.
##   3. Termina cuando un equipo llega a los puntos para ganar la ronda.
##      Cuando un equipo gana las rondas necesarias, termina la partida.

signal round_started(round_number: int)
signal upgrade_applied(upgrade: Upgrade)

enum Phase { IDLE, SELECTING, FIGHTING, ENDED }

const TEAM_NAMES := ["ROJO", "AZUL"]
## Segundos entre que termina una ronda y empieza la elección de mejoras
const ROUND_END_DELAY := 3.0
## Segundos que se muestra el ganador antes de volver a la lista de lobbys
const MATCH_END_DELAY := 6.0

@export var player_path: NodePath
@export var selector_path: NodePath
@export var options_per_round: int = 3

var round_number: int = 0

var player: CharacterBody2D
var selector: UpgradeSelector

var _pool: Array = []

# --- Red ---
var _net: bool = false
var _phase: Phase = Phase.IDLE
var _wins: Array[int] = [0, 0]
## Host: peers que todavía no terminaron de elegir
var _waiting: Dictionary = {}
var _picks_left: int = 0
var _pick_number: int = 0
var _picks_total: int = 1
var _rerolls_left: int = 0
var _ctf: Node = null
var _banner: Label
var _info: Label
var _banner_tween: Tween


func _ready() -> void:
	player = _find_node(player_path, "Player") as CharacterBody2D
	selector = _find_node(selector_path, "UpgradeSelector") as UpgradeSelector
	if player == null or selector == null:
		push_error("RoundManager: no encontré al jugador o al UpgradeSelector. "
				+ "Revisá que el nodo UpgradeSelector tenga asignado upgrade_selector.gd.")
		return
	# Mejoras genéricas + las propias del personaje elegido
	_pool = UpgradePool.create_all()
	if player.has_method("get_character_upgrades"):
		_pool.append_array(player.get_character_upgrades())
	selector.upgrade_chosen.connect(_on_upgrade_chosen)
	if LanNetwork.in_lobby:
		# En red no se arranca sola: GameSession llama a net_begin() cuando todos cargaron
		_net = true
		selector.pause_game = false
		selector.reroll_requested.connect(_on_reroll_requested)
		_create_hud()
		return
	# Diferido para que el resto de la escena termine de conectarse antes de la ronda 1
	start_round.call_deferred()


## Empieza una ronda nueva y ofrece las mejoras para elegir (modo sin red).
func start_round() -> void:
	if selector.is_open():
		return
	round_number += 1
	selector.offer(_random_options(), round_number)


func _random_options() -> Array:
	var options: Array = _pool.duplicate()
	options.shuffle()
	return options.slice(0, options_per_round)


## Busca el nodo por la ruta exportada; si no sirve, lo busca por nombre entre los hermanos.
func _find_node(path: NodePath, node_name: String) -> Node:
	if not path.is_empty() and has_node(path):
		return get_node(path)
	return get_parent().find_child(node_name, true, false)


func _on_upgrade_chosen(upgrade: Upgrade) -> void:
	var weapon := player.get_weapon() as Weapon
	upgrade.apply(weapon.stats, player)
	if upgrade.unique:
		_pool.erase(upgrade)
	weapon.reset()
	upgrade_applied.emit(upgrade)
	if _net:
		_after_pick()
	else:
		round_started.emit(round_number)


# ------------------------------------------------------------------ Red: arranque

## La llama GameSession en todas las PCs cuando la partida empieza.
func net_begin() -> void:
	if not _net or player == null:
		return
	_ctf = _find_ctf()
	if multiplayer.is_server():
		if _ctf != null and not _ctf.score_changed.is_connected(_on_score_changed):
			_ctf.score_changed.connect(_on_score_changed)
		if not LanNetwork.players_changed.is_connected(_on_players_changed):
			LanNetwork.players_changed.connect(_on_players_changed)
		_host_start_round()


func _find_ctf() -> Node:
	for node in get_tree().current_scene.find_children("*", "", true, false):
		if node.has_signal("score_changed") and node.has_method("reset_scores"):
			return node
	return null


# ------------------------------------------------------------------ Red: host

func _host_start_round() -> void:
	round_number += 1
	_phase = Phase.SELECTING
	_waiting.clear()
	for id in LanNetwork.players.keys():
		_waiting[id] = true
	_net_select.rpc(round_number, _wins[0], _wins[1])


## Cada vez que un equipo suma un punto: ¿llegó a los puntos para ganar la ronda?
func _on_score_changed(team: int, score: int) -> void:
	if _phase != Phase.FIGHTING:
		return
	if score < LobbyConfig.current.points_to_win_round:
		return
	_phase = Phase.ENDED
	_wins[team] += 1
	var match_over: bool = _wins[team] >= LobbyConfig.current.rounds_to_win
	_net_round_end.rpc(team, _wins[0], _wins[1], match_over)
	if match_over:
		await get_tree().create_timer(MATCH_END_DELAY).timeout
		GameSession.end_match()
	else:
		await get_tree().create_timer(ROUND_END_DELAY).timeout
		if _phase == Phase.ENDED and LanNetwork.in_lobby:
			_host_start_round()


func _register_done(peer_id: int) -> void:
	if _phase != Phase.SELECTING:
		return
	_waiting.erase(peer_id)
	_check_all_done()


func _check_all_done() -> void:
	if _phase == Phase.SELECTING and _waiting.is_empty():
		_phase = Phase.FIGHTING
		_net_fight.rpc()


func _on_players_changed() -> void:
	# Alguien se fue: ya no se lo espera
	for id in _waiting.keys():
		if not LanNetwork.players.has(id):
			_waiting.erase(id)
	_check_all_done()


@rpc("any_peer", "call_remote", "reliable")
func _server_done() -> void:
	if multiplayer.is_server():
		_register_done(multiplayer.get_remote_sender_id())


# ------------------------------------------------------------------ Red: todas las PCs

@rpc("authority", "call_local", "reliable")
func _net_select(n: int, wins_red: int, wins_blue: int) -> void:
	round_number = n
	_wins = [wins_red, wins_blue]
	_phase = Phase.SELECTING
	_update_info()
	_show_banner("RONDA %d" % n, 1.5)
	if _ctf != null:
		_ctf.reset_scores()
	# Todos al spawn, con vida completa y quietos hasta que terminen de elegir
	player.set_net_frozen(true)
	player.respawn()
	if multiplayer.is_server():
		for flag in get_tree().get_nodes_in_group("flags"):
			flag._reset_to_base()
	var config := LobbyConfig.current
	_picks_total = maxi(config.upgrades_per_round, 0)
	_picks_left = _picks_total
	_pick_number = 0
	_rerolls_left = config.rerolls
	_offer_next()


@rpc("authority", "call_local", "reliable")
func _net_fight() -> void:
	_phase = Phase.FIGHTING
	player.set_net_frozen(false)
	_show_banner("¡A PELEAR!", 1.2)
	round_started.emit(round_number)


@rpc("authority", "call_local", "reliable")
func _net_round_end(winner: int, wins_red: int, wins_blue: int, match_over: bool) -> void:
	_phase = Phase.ENDED
	_wins = [wins_red, wins_blue]
	_update_info()
	player.set_net_frozen(true)
	if match_over:
		_show_banner("¡EL EQUIPO %s GANÓ LA PARTIDA!\n%d - %d" % [TEAM_NAMES[winner], wins_red, wins_blue], MATCH_END_DELAY)
	else:
		_show_banner("Ronda para el equipo %s\n%d - %d" % [TEAM_NAMES[winner], wins_red, wins_blue], ROUND_END_DELAY)


# ------------------------------------------------------------------ Red: elección de mejoras

func _offer_next() -> void:
	if _picks_left <= 0 or _pool.is_empty():
		_finish_picking()
		return
	_pick_number += 1
	_show_options()


func _show_options() -> void:
	var title := "Ronda %d — mejora %d de %d" % [round_number, _pick_number, _picks_total]
	selector.offer(_random_options(), round_number, _rerolls_left, title)


func _on_reroll_requested() -> void:
	if _rerolls_left <= 0:
		return
	_rerolls_left -= 1
	_show_options()


func _after_pick() -> void:
	_picks_left -= 1
	_offer_next()


## Terminó de elegir: avisa al host y espera a que peleen todos.
func _finish_picking() -> void:
	if multiplayer.is_server():
		_register_done(1)
	else:
		_server_done.rpc_id(1)
	if _phase == Phase.SELECTING:
		_show_banner("Esperando a los demás jugadores...", 30.0)


# ------------------------------------------------------------------ Red: HUD

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_info = Label.new()
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info.offset_top = 44.0
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 18)
	layer.add_child(_info)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = -160.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.modulate.a = 0.0
	layer.add_child(_banner)
	_update_info()


func _update_info() -> void:
	if _info == null:
		return
	var config := LobbyConfig.current
	_info.text = "Ronda %d   ·   Rondas ganadas: ROJO %d - %d AZUL   ·   (%d rondas para ganar, %d puntos por ronda)" % [
			maxi(round_number, 1), _wins[0], _wins[1],
			config.rounds_to_win if config != null else 0,
			config.points_to_win_round if config != null else 0]


func _show_banner(text: String, seconds: float) -> void:
	if _banner == null:
		return
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(maxf(seconds - 0.5, 0.1))
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
