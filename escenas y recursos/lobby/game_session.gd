extends Node
## Autoload "GameSession". Arma la partida en red cuando el host aprieta "Empezar":
##  1. Espera a que todos hayan cargado el mapa.
##  2. Crea un jugador por cada integrante del lobby, en la base de su equipo.
##     Tu jugador es el "Player" que ya está en el mapa; los demás son copias de player.tscn.
##  3. Activa la sincronización de jugadores y banderas.
## Si no hay lobby (modo práctica, probar el mapa con F6) no hace nada.

signal match_started

const PLAYER_SCENE_PATH := "res://escenas y recursos/player/player.tscn"
const LOBBY_LIST_SCENE := "res://escenas y recursos/menu/lobby_list.tscn"
## Separación horizontal entre jugadores del mismo equipo al aparecer
const SPAWN_SPACING := 60.0

## Tu jugador (el que controlás), disponible cuando empezó la partida
var local_player: Node2D = null
var started: bool = false

var _map_loaded: bool = false
var _ready_peers: Dictionary = {}  # solo lo usa el host


func _ready() -> void:
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	LanNetwork.game_starting.connect(_on_game_starting)
	LanNetwork.players_changed.connect(_on_players_changed)
	LanNetwork.left_lobby.connect(_on_left_lobby)


# ---------------------------------------------------------------- Carga y sincronización de inicio

func _on_game_starting(_map_path: String) -> void:
	started = false
	local_player = null
	_map_loaded = false
	var old_scene := get_tree().current_scene
	# Espera a que se cargue el mapa nuevo y corran sus _ready
	var frames := 0
	while frames < 600:
		var scene := get_tree().current_scene
		if scene != null and scene != old_scene:
			break
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame
	_map_loaded = true
	if multiplayer.is_server():
		_register_ready(1)
	else:
		_server_peer_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _server_peer_ready() -> void:
	if multiplayer.is_server():
		_register_ready(multiplayer.get_remote_sender_id())


## Solo el host: cuando todos terminaron de cargar, manda empezar a la vez.
func _register_ready(peer_id: int) -> void:
	_ready_peers[peer_id] = true
	for id in LanNetwork.players.keys():
		if not _ready_peers.has(id):
			return
	_ready_peers.clear()
	_begin.rpc()


@rpc("authority", "call_local", "reliable")
func _begin() -> void:
	if started or not _map_loaded:
		return
	started = true
	_spawn_players()
	for flag in get_tree().get_nodes_in_group("flags"):
		flag.start_network()

	# Barriles (y cualquier objeto empujable del mapa): el host los simula
	for pushable in get_tree().get_nodes_in_group("pushables"):
		if pushable.has_method("start_network"):
			pushable.start_network()
	# Rondas: el RoundManager del mapa arranca la partida (el host manda las rondas)
	var round_manager := get_tree().current_scene.find_child("RoundManager", true, false)
	if round_manager != null and round_manager.has_method("net_begin"):
		round_manager.net_begin()
	match_started.emit()


# ---------------------------------------------------------------- Jugadores

func _spawn_players() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var map_player := get_tree().get_first_node_in_group("players")
	var root := get_tree().current_scene
	var player_scale := Vector2(2, 2)
	if map_player != null:
		player_scale = map_player.scale

	var bases := {}
	for base in get_tree().get_nodes_in_group("bases"):
		bases[int(base.team)] = base

	var ids: Array = LanNetwork.players.keys()
	ids.sort()
	var per_team: Array = [[], []]
	for id in ids:
		per_team[int(LanNetwork.players[id]["team"])].append(id)

	var my_id := multiplayer.get_unique_id()
	for team in 2:
		var members: Array = per_team[team]
		for i in members.size():
			var id: int = members[i]
			var info: Dictionary = LanNetwork.players[id]
			var spawn := _spawn_point(bases.get(team), i, members.size())

			var player: Node2D
			var adopted := id == my_id and map_player != null
			if adopted:
				player = map_player  # tu "Player" del mapa pasa a ser tu jugador de red
			else:
				player = player_scene.instantiate()
				player.scale = player_scale
				player.position = spawn
				if id != my_id:
					player.get_node("Camera2D").enabled = false  # solo la cámara de tu jugador
			player.name = str(id)
			if not adopted:
				# Antes de agregarlo a la escena: su _ready carga el personaje (stats, texturas, animaciones)
				player.character = LanNetwork.character_of(id)
				player.character_assigned = true
			player.team = team
			player.set_multiplayer_authority(id)
			if not adopted:
				root.add_child(player)
			player.global_position = spawn
			player.spawn_position = spawn
			player.set_display_name(str(info["name"]))
			player.setup_network()
			if id == my_id:
				local_player = player

	# Los jugadores no se chocan entre sí
	var all_players := get_tree().get_nodes_in_group("players")
	for a in all_players:
		for b in all_players:
			if a != b:
				a.add_collision_exception_with(b)


func _spawn_point(base: Node, index: int, count: int) -> Vector2:
	var point := Vector2.ZERO
	if base != null:
		point = base.get_spawn_position()
	point.x += (index - (count - 1) / 2.0) * SPAWN_SPACING
	return point


## Alguien se fue en medio de la partida: se saca su jugador del mapa.
func _on_players_changed() -> void:
	if not started:
		return
	for player in get_tree().get_nodes_in_group("players"):
		var id := int(String(player.name))
		if id != 0 and player != local_player and not LanNetwork.players.has(id):
			player.queue_free()


## El host cerró el lobby en medio de la partida: se vuelve a la lista de lobbies.
func _on_left_lobby(_reason: String) -> void:
	var was_playing := started
	started = false
	local_player = null
	_map_loaded = false
	_ready_peers.clear()
	if was_playing and ResourceLoader.exists(LOBBY_LIST_SCENE):
		get_tree().change_scene_to_file(LOBBY_LIST_SCENE)


## El host termina la partida: cierra el lobby y todos vuelven a la lista.
func end_match() -> void:
	LanNetwork.leave()
	_on_left_lobby("Partida terminada")


## Otra PC tiene a Panchu: se crea una copia que solo se ve (el RPC vive acá porque
## la habilidad de cada jugador puede ser distinta en cada PC).
@rpc("any_peer", "call_remote", "reliable")
func net_spawn_panchu(scene_path: String, panchu_name: String, owner_id: int) -> void:
	if multiplayer.get_remote_sender_id() != owner_id or not ResourceLoader.exists(scene_path):
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var puppet := (load(scene_path) as PackedScene).instantiate() as Node2D
	puppet.name = panchu_name
	puppet.net_puppet = true
	puppet.owner_player = root.get_node_or_null(str(owner_id)) as Node2D
	root.add_child(puppet)
	puppet.start_network(owner_id)


var _object_counter: int = 0

## Id único para objetos que crea el host (termos, etc.)
func next_object_id() -> int:
	_object_counter += 1
	return _object_counter
