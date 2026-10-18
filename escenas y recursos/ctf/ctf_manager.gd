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
	for flag in get_tree().get_nodes_in_group("flags"):
		flag.picked_up.connect(_on_flag_picked_up)
		flag.dropped.connect(_on_flag_dropped)
		flag.returned.connect(_on_flag_returned)
		flag.captured.connect(_on_flag_captured)

	_event_label.modulate.a = 0.0
	_update_score_label()
	# Diferido: así los jugadores ya terminaron su propio _ready
	_assign_initial_teams.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_team_switch:
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


func _on_flag_picked_up(flag: Area2D, _carrier: Node2D) -> void:
	_show_event("¡Bandera %s tomada!" % FLAG_NAMES[flag.team])


func _on_flag_dropped(flag: Area2D) -> void:
	_show_event("Bandera %s caída: vuelve a su base en %d s" % [FLAG_NAMES[flag.team], int(flag.return_time)])


func _on_flag_returned(flag: Area2D) -> void:
	_show_event("La bandera %s volvió a su base" % FLAG_NAMES[flag.team])


func _on_flag_captured(flag: Area2D, scoring_team: int) -> void:
	scores[scoring_team] += 1
	score_changed.emit(scoring_team, scores[scoring_team])
	_update_score_label()
	_show_event("¡Punto para el equipo %s! (bandera %s)" % [TEAM_NAMES[scoring_team], FLAG_NAMES[flag.team]])


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
