extends Node
## Autoload "LanNetwork". Maneja todo lo de red LAN del menú:
##  - Descubrimiento: el host anuncia su lobby por UDP broadcast cada segundo y los demás lo escuchan.
##  - Conexión: ENet (puerto GAME_PORT). El host es el servidor y manda el estado de la sala a todos.
##  - Sala de espera: jugadores (nombre + equipo) sincronizados, cambio de equipo y de nombre.
##  - Inicio: el host dice "empezar" y todos cargan el mapa.
##
## Puertos a permitir en el firewall (UDP): 47777 (descubrimiento) y 47778 (juego).

signal lobbies_updated(lobbies: Array)  # lobbies encontrados en la red
signal lobby_joined                      # el host aceptó y ya llegó la config de la sala
signal join_failed(reason: String)
signal players_changed
signal left_lobby(reason: String)        # el host cerró el lobby o se cayó la conexión
signal game_starting(map_path: String)

const DISCOVERY_PORT := 47777
const GAME_PORT := 47778
const BROADCAST_INTERVAL := 1.0
const LOBBY_TIMEOUT_MSEC := 3500
const GAME_ID := "demonios_de_la_brecha"
const PROTOCOL_VERSION := 2

## peer_id -> {"name": String, "team": int, "character": String}   (team 0 = rojo, 1 = azul). El host siempre es el id 1.
var players: Dictionary = {}
var in_lobby: bool = false
var game_started: bool = false
## Mensaje para mostrar en la lista de lobbies al volver (ej: "El host cerró el lobby.")
var last_notice: String = ""

var _broadcaster: PacketPeerUDP
var _listener: PacketPeerUDP
var _broadcast_timer: float = 0.0
var _found: Dictionary = {}  # "ip:puerto" -> entrada del lobby
var _seen: Dictionary = {}   # "ip:puerto" -> último momento en que se vio (ms)
var _joining: bool = false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Diferido para no depender del orden de los autoloads
	call_deferred("_connect_profile")


func _connect_profile() -> void:
	PlayerProfile.name_changed.connect(_on_local_name_changed)


func _process(delta: float) -> void:
	if _broadcaster != null:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = BROADCAST_INTERVAL
			_send_broadcast()
	if _listener != null:
		_poll_listener()


# ---------------------------------------------------------------- Descubrimiento

func start_discovery() -> Error:
	stop_discovery()
	_found.clear()
	_seen.clear()
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("LanNetwork: no se pudo escuchar el puerto %d (error %d)." % [DISCOVERY_PORT, err])
		_listener = null
		return err
	lobbies_updated.emit([])
	return OK


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null


func _poll_listener() -> void:
	var changed := false
	var now := Time.get_ticks_msec()
	while _listener.get_available_packet_count() > 0:
		var raw := _listener.get_packet()
		var ip := _listener.get_packet_ip().trim_prefix("::ffff:")
		var data = JSON.parse_string(raw.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			continue
		if str(data.get("game", "")) != GAME_ID or int(data.get("version", 0)) != PROTOCOL_VERSION:
			continue
		var entry := {
			"name": str(data.get("name", "?")),
			"host": str(data.get("host", "?")),
			"players": int(data.get("players", 0)),
			"max_players": int(data.get("max_players", 0)),
			"team_size": int(data.get("team_size", 1)),
			"map": str(data.get("map", "")),
			"ip": ip,
			"port": int(data.get("port", GAME_PORT)),
		}
		var key := "%s:%d" % [ip, entry["port"]]
		if not _found.has(key) or _found[key].hash() != entry.hash():
			changed = true
		_found[key] = entry
		_seen[key] = now
	for key in _seen.keys():
		if now - int(_seen[key]) > LOBBY_TIMEOUT_MSEC:
			_seen.erase(key)
			_found.erase(key)
			changed = true
	if changed:
		lobbies_updated.emit(_found.values())


func _send_broadcast() -> void:
	var config := LobbyConfig.current
	if config == null or players.is_empty():
		return
	var packet := JSON.stringify({
		"game": GAME_ID,
		"version": PROTOCOL_VERSION,
		"name": config.lobby_name,
		"host": str(players[1]["name"]),
		"players": players.size(),
		"max_players": config.max_players(),
		"team_size": config.team_size,
		"map": config.map_name,
		"port": GAME_PORT,
	}).to_utf8_buffer()
	_broadcaster.put_packet(packet)


# ---------------------------------------------------------------- Host / unirse / salir

func host_lobby(config: LobbyConfig) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, config.max_players() - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	LobbyConfig.current = config
	players = {1: {"name": PlayerProfile.player_name, "team": 0, "character": PlayerProfile.character}}
	in_lobby = true
	game_started = false
	stop_discovery()
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcast_timer = 0.0
	players_changed.emit()
	return OK


func join_lobby(ip: String, port: int = GAME_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), port)
	if err != OK:
		join_failed.emit("No se pudo iniciar la conexión (dirección inválida).")
		return err
	multiplayer.multiplayer_peer = peer
	_joining = true
	return OK


func leave() -> void:
	_cleanup()


func _cleanup() -> void:
	in_lobby = false
	game_started = false
	_joining = false
	players.clear()
	_broadcaster = null
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null


# ---------------------------------------------------------------- Eventos de conexión

func _on_peer_disconnected(id: int) -> void:
	if not in_lobby or not multiplayer.is_server():
		return
	if players.erase(id):
		_broadcast_state()


func _on_connected_to_server() -> void:
	_server_register.rpc_id(1, PlayerProfile.player_name, PlayerProfile.character)


func _on_connection_failed() -> void:
	_cleanup()
	join_failed.emit("No se pudo conectar al lobby.")


func _on_server_disconnected() -> void:
	if _joining:
		_cleanup()
		join_failed.emit("Se perdió la conexión con el host.")
	elif in_lobby:
		_cleanup()
		last_notice = "El host cerró el lobby."
		left_lobby.emit(last_notice)


# ---------------------------------------------------------------- RPC: registro y rechazo

@rpc("any_peer", "call_remote", "reliable")
func _server_register(player_name: String, character: String = "") -> void:
	if not multiplayer.is_server() or not in_lobby:
		return
	var id := multiplayer.get_remote_sender_id()
	var config := LobbyConfig.current
	if game_started or players.size() >= config.max_players():
		_client_rejected.rpc_id(id, "El lobby está lleno o la partida ya empezó.")
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
		return
	players[id] = {"name": _clean_name(player_name, id), "team": _pick_team(), "character": CharacterRoster.clean(character)}
	_broadcast_state()


@rpc("authority", "call_remote", "reliable")
func _client_rejected(reason: String) -> void:
	_cleanup()
	join_failed.emit(reason)


# ---------------------------------------------------------------- RPC: estado de la sala

func _broadcast_state() -> void:
	players_changed.emit()
	var config_dict := LobbyConfig.current.to_dict()
	for id in players.keys():
		if id != 1:
			_client_sync.rpc_id(id, config_dict, players)


@rpc("authority", "call_remote", "reliable")
func _client_sync(config_dict: Dictionary, new_players: Dictionary) -> void:
	LobbyConfig.current = LobbyConfig.from_dict(config_dict)
	players = new_players
	if _joining:
		_joining = false
		in_lobby = true
		lobby_joined.emit()
	players_changed.emit()


# ---------------------------------------------------------------- Nombre y equipo

## Personaje elegido por cada jugador (peer_id). Si falta, el de por defecto.
func character_of(id: int) -> String:
	if players.has(id):
		return CharacterRoster.clean(str(players[id].get("character", "")))
	return CharacterRoster.DEFAULT_ID


## Cambia tu personaje en la sala (cada jugador elige el suyo). No se puede con la partida empezada.
func request_set_character(character: String) -> void:
	if not in_lobby or game_started:
		return
	character = CharacterRoster.clean(character)
	if multiplayer.is_server():
		players[1]["character"] = character
		_broadcast_state()
	else:
		_server_set_character.rpc_id(1, character)


@rpc("any_peer", "call_remote", "reliable")
func _server_set_character(character: String) -> void:
	if not multiplayer.is_server() or game_started:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	players[id]["character"] = CharacterRoster.clean(character)
	_broadcast_state()


func _on_local_name_changed(new_name: String) -> void:
	if not in_lobby:
		return
	if multiplayer.is_server():
		players[1]["name"] = _clean_name(new_name, 1)
		_broadcast_state()
	else:
		_server_rename.rpc_id(1, new_name)


@rpc("any_peer", "call_remote", "reliable")
func _server_rename(new_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	players[id]["name"] = _clean_name(new_name, id)
	_broadcast_state()


func request_switch_team() -> void:
	if not in_lobby:
		return
	if multiplayer.is_server():
		_apply_switch(1)
	else:
		_server_switch_team.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _server_switch_team() -> void:
	if not multiplayer.is_server():
		return
	_apply_switch(multiplayer.get_remote_sender_id())


func _apply_switch(id: int) -> void:
	if game_started or not players.has(id):
		return
	var target := 1 - int(players[id]["team"])
	var count := 0
	for p in players.values():
		if int(p["team"]) == target:
			count += 1
	if count >= LobbyConfig.current.team_size:
		return  # el otro equipo está completo
	players[id]["team"] = target
	_broadcast_state()


func _pick_team() -> int:
	var counts := [0, 0]
	for p in players.values():
		counts[int(p["team"])] += 1
	return 0 if counts[0] <= counts[1] else 1


func _clean_name(raw: String, exclude_id: int) -> String:
	var base := raw.strip_edges().left(PlayerProfile.MAX_LENGTH)
	if base.is_empty():
		base = "Jugador"
	var candidate := base
	var n := 2
	while _name_taken(candidate, exclude_id):
		candidate = "%s (%d)" % [base, n]
		n += 1
	return candidate


func _name_taken(candidate: String, exclude_id: int) -> bool:
	for id in players.keys():
		if id != exclude_id and str(players[id]["name"]) == candidate:
			return true
	return false


# ---------------------------------------------------------------- Empezar la partida

## Solo el host. Devuelve ERR_FILE_NOT_FOUND si el mapa no existe.
func start_game() -> Error:
	if not in_lobby or not multiplayer.is_server():
		return ERR_UNAUTHORIZED
	var path := LobbyConfig.current.map_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		return ERR_FILE_NOT_FOUND
	game_started = true
	_broadcaster = null  # deja de anunciar el lobby
	_client_start.rpc(path)
	return OK


@rpc("authority", "call_local", "reliable")
func _client_start(map_path: String) -> void:
	game_started = true
	game_starting.emit(map_path)
	get_tree().change_scene_to_file(map_path)


# ---------------------------------------------------------------- Utilidades

## IP local del host (para conexión directa si el descubrimiento no funciona).
func get_lan_ip() -> String:
	var fallback := ""
	for address in IP.get_local_addresses():
		if address.count(".") != 3 or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("192.168."):
			return address
		if fallback.is_empty():
			fallback = address
	return fallback
