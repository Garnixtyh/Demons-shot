extends Node2D
## Captura la bandera: puntaje, equipos de los jugadores y mensajes en pantalla.

signal score_changed(team: int, score: int)

const FLAG_NAMES := ["roja", "azul"]
const TEAM_NAMES := ["rojo", "azul"]

## Solo para pruebas: la tecla T cambia de equipo al jugador
@export var debug_team_switch: bool = true

var scores: Array[int] = [0, 0]

var _event_tween: Tween

@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _event_label: Label = $HUD/EventLabel



func _ready() -> void:
	_event_label.modulate.a = 0.0
	_update_score_label()
	# Diferido: las banderas pueden estar fuera de este nodo (y más abajo en el árbol),
	# así que todavía no se registraron en su grupo; esperamos a que termine el _ready
	# de toda la escena antes de conectarlas y asignar los equipos.
	_setup.call_deferred()


func _setup() -> void:
	for flag in get_tree().get_nodes_in_group("flags"):
		_connect_flag(flag)
	_assign_initial_teams()


func _connect_flag(flag: Node) -> void:
	if not flag.picked_up.is_connected(_on_flag_picked_up):
		flag.picked_up.connect(_on_flag_picked_up)
	if not flag.dropped.is_connected(_on_flag_dropped):
		flag.dropped.connect(_on_flag_dropped)
	if not flag.returned.is_connected(_on_flag_returned):
		flag.returned.connect(_on_flag_returned)
	if not flag.captured.is_connected(_on_flag_captured):
		flag.captured.connect(_on_flag_captured)


func _unhandled_input(event: InputEvent) -> void:
	# En una partida en red los equipos los define el lobby
	if not debug_team_switch or LanNetwork.in_lobby:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		for player in get_tree().get_nodes_in_group("players"):
			assign_team(player, 1 - player.team)
			_show_event("Ahora sos del equipo %s" % TEAM_NAMES[player.team])


## Asigna un equipo al jugador: define su reaparición en la base y lo lleva ahí.
func assign_team(player: Node, team: int, teleport: bool = true) -> void:
	if player.carried_flag != null:
		player.carried_flag.drop()
	player.team = team
	var base := _get_base(team)
	if base == null:
		push_warning("CTF: no hay una Base para el equipo %d" % team)
		return
	player.spawn_position = base.get_spawn_position()
	if teleport:
		player.global_position = player.spawn_position
		player.velocity = Vector2.ZERO
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.reset_smoothing()


func _assign_initial_teams() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		assign_team(player, player.team)


func _get_base(team: int) -> Node:
	for base in get_tree().get_nodes_in_group("bases"):
		if base.team == team:
			return base
	return null


# En red, las banderas solo emiten estas señales en el host: él lleva el puntaje
# y les manda a los demás el marcador y los mensajes.

func _on_flag_picked_up(flag: Area2D, _carrier: Node2D) -> void:
	_broadcast_event("¡Bandera %s tomada!" % FLAG_NAMES[flag.team])


func _on_flag_dropped(flag: Area2D) -> void:
	_broadcast_event("Bandera %s caída: vuelve a su base en %d s" % [FLAG_NAMES[flag.team], int(flag.return_time)])


func _on_flag_returned(flag: Area2D) -> void:
	_broadcast_event("La bandera %s volvió a su base" % FLAG_NAMES[flag.team])


func _on_flag_captured(flag: Area2D, scoring_team: int) -> void:
	scores[scoring_team] += 1
	score_changed.emit(scoring_team, scores[scoring_team])
	_update_score_label()
	if LanNetwork.in_lobby:
		_net_scores.rpc(scores[0], scores[1])
	_broadcast_event("¡Punto para el equipo %s! (bandera %s)" % [TEAM_NAMES[scoring_team], FLAG_NAMES[flag.team]])


func _broadcast_event(text: String) -> void:
	_show_event(text)
	if LanNetwork.in_lobby:
		_net_event.rpc(text)


## Los clientes reciben el marcador del host.
@rpc("authority", "call_remote", "reliable")
func _net_scores(red: int, blue: int) -> void:
	scores[0] = red
	scores[1] = blue
	_update_score_label()


@rpc("authority", "call_remote", "reliable")
func _net_event(text: String) -> void:
	_show_event(text)


## Pone el marcador de la ronda en 0 (lo llama el RoundManager al empezar cada ronda en red).
func reset_scores() -> void:
	scores = [0, 0]
	_update_score_label()


func _update_score_label() -> void:
	_score_label.text = "ROJO %d  -  %d AZUL" % [scores[0], scores[1]]


func _show_event(text: String) -> void:
	_event_label.text = text
	if _event_tween != null:
		_event_tween.kill()
	_event_label.modulate.a = 1.0
	_event_tween = create_tween()
	_event_tween.tween_interval(2.5)
	_event_tween.tween_property(_event_label, "modulate:a", 0.0, 0.6)
