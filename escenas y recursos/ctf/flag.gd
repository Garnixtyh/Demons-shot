extends Area2D
## Bandera de un equipo. Funciona igual para la roja y la azul.
##
## - Un jugador del equipo CONTRARIO que la toca la lleva: la bandera lo sigue.
## - Si el portador muere, la suelta donde cayó.
## - Si nadie la recoge en `return_time` segundos, vuelve a su base.
## - Si el portador la lleva a su propia base, suma un punto (lo detecta Base).

signal picked_up(flag: Area2D, carrier: Node2D)
signal dropped(flag: Area2D)
signal returned(flag: Area2D)
signal captured(flag: Area2D, scoring_team: int)

enum State { AT_BASE, CARRIED, DROPPED }

const TEAM_COLORS := [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95)]

## Equipo dueño de la bandera
@export_enum("Rojo", "Azul") var team: int = 0
## Segundos que espera en el suelo antes de volver a su base
@export var return_time: float = 5.0
## Dónde queda respecto del portador
@export var carry_offset: Vector2 = Vector2(0, -90)
## Qué tan rápido sigue al portador (más alto = más pegada)
@export var follow_speed: float = 5.0

var state: State = State.AT_BASE
var carrier: Node2D = null
var home_position: Vector2

var _drop_timer: float = 0.0
var _landed: bool = false
var _fall_velocity: float = 0.0
## Se copian del jugador al soltarse, para caer con sus mismas físicas
var _gravity: float = 2400.0
var _max_fall_speed: float = 900.0
var _fall_limit: float = 1500.0
var _exclude: Array[RID] = []

@onready var _triangle: Polygon2D = $Triangle


func _ready() -> void:
	add_to_group("flags")
	home_position = global_position
	_triangle.color = TEAM_COLORS[team]


func _physics_process(delta: float) -> void:
	match state:
		State.CARRIED:
			_follow_carrier(delta)
		State.DROPPED:
			_drop_timer -= delta
			if _drop_timer <= 0.0:
				return_to_base()
				return
			if not _landed:
				_fall(delta)
				if state != State.DROPPED:
					return
			_try_pick_up()
		State.AT_BASE:
			_try_pick_up()


## Un jugador la toma.
func pick_up(player: Node2D) -> void:
	state = State.CARRIED
	carrier = player
	player.carried_flag = self
	modulate.a = 1.0
	picked_up.emit(self, player)


## El portador la suelta (la llama el jugador al morir).
func drop() -> void:
	if state != State.CARRIED or carrier == null:
		return
	# Cae con las mismas físicas que el jugador
	_gravity = carrier.gravity_fall
	_max_fall_speed = carrier.max_fall_speed
	_fall_limit = carrier.fall_death_y
	_exclude = _players_rids()
	_fall_velocity = 0.0
	_landed = false
	_release_carrier()
	state = State.DROPPED
	_drop_timer = return_time
	modulate.a = 0.7
	dropped.emit(self)


## Vuelve sola a su base (sin dar puntos).
func return_to_base() -> void:
	_reset_to_base()
	returned.emit(self)


## El portador llegó a la base contraria: punto y la bandera vuelve a su base.
func capture() -> void:
	if state != State.CARRIED or carrier == null:
		return
	var scoring_team: int = carrier.team
	_reset_to_base()
	captured.emit(self, scoring_team)


func _reset_to_base() -> void:
	_release_carrier()
	state = State.AT_BASE
	_landed = false
	global_position = home_position
	modulate.a = 1.0


func _release_carrier() -> void:
	if is_instance_valid(carrier) and carrier.carried_flag == self:
		carrier.carried_flag = null
	carrier = null


func _follow_carrier(delta: float) -> void:
	if not is_instance_valid(carrier):
		return_to_base()
		return
	var target := carrier.global_position + carry_offset
	global_position = global_position.lerp(target, 1.0 - exp(-follow_speed * delta))


func _try_pick_up() -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("players"):
			continue
		if body.is_dead or body.team == team or body.carried_flag != null:
			continue
		pick_up(body)
		return


## Cae con gravedad hasta tocar el suelo. Si pasa el límite de caída, vuelve a su base.
func _fall(delta: float) -> void:
	_fall_velocity = minf(_fall_velocity + _gravity * delta, _max_fall_speed)
	var from := global_position
	var to := from + Vector2(0, _fall_velocity * delta)
	var hit := _raycast(from, to + Vector2(0, 1))
	if not hit.is_empty():
		global_position = hit.position
		_fall_velocity = 0.0
		_landed = true
		return
	global_position = to
	if to.y > _fall_limit:
		return_to_base()


func _raycast(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = _exclude
	return get_world_2d().direct_space_state.intersect_ray(query)


## La bandera no se apoya sobre los jugadores, solo sobre el escenario.
func _players_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for player in get_tree().get_nodes_in_group("players"):
		rids.append(player.get_rid())
	return rids
