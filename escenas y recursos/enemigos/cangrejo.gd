class_name Cangrejo
extends EnemyBase
## Cangrejo: patrulla; al detectar al jugador lo persigue, se prepara (tiembla) y lo
## embiste. La embestida hace daño y empuja MUCHO más que el resto de los enemigos. Si se
## estrella contra una pared queda aturdido un rato (buen momento para pegarle).

enum State { PATROL, CHASE, WINDUP, CHARGE, RECOVER }

@export var walk_speed: float = 60.0
@export var chase_speed: float = 200.0
@export var charge_speed: float = 750.0
## Distancia a la que ve al jugador (largo del RayCast2D "Vision")
@export var detect_range: float = 650.0
## Segundos sin ver al jugador (algo en medio) antes de dejar de perseguirlo
@export var lose_sight_time: float = 1.0
## Distancia a la que deja de perseguir y se prepara para embestir
@export var charge_range: float = 380.0
## Segundos que se "carga" antes de embestir (se puede esquivar)
@export var windup_time: float = 0.6
## Segundos máximos de embestida
@export var charge_time: float = 0.8
## Segundos de recuperación después de embestir
@export var recover_time: float = 1.2
## Segundos de aturdimiento si choca con una pared embistiendo
@export var wall_stun_time: float = 2.0
@export var charge_damage: float = 25.0
## Retroceso del jugador al ser embestido (1 = el de los otros enemigos)
@export var charge_knockback_scale: float = 3.0
## Segundos que queda aturdido el jugador (sin moverse ni atacar) al ser embestido
@export var charge_stun_time: float = 1.2

## Cuánto tiembla (px) al prepararse para embestir
const WINDUP_SHAKE := 3.0

var _state: State = State.PATROL
var _timer: float = 0.0
var _charge_dir: float = 1.0
var _charge_hit: bool = false
var _turn_cooldown: float = 0.0
var _vision: RayCast2D
var _sight_lost_timer: float = 0.0
var _visual_base_pos: Vector2 = Vector2.ZERO
var _passing_through: Array[Node] = []


func _ready() -> void:
	super._ready()
	_setup_vision()
	# El sprite del cangrejo mira a la izquierda; si el tuyo mira a la derecha, cambialo en el Inspector
	face(1.0 if randf() < 0.5 else -1.0)
	if _visual != null:
		_visual_base_pos = _visual.position
	_play_loop(&"run", 0.6)


func _ai(delta: float, player: Node2D) -> void:
	_turn_cooldown = maxf(_turn_cooldown - delta, 0.0)
	match _state:
		State.PATROL:
			if _turn_cooldown <= 0.0 and is_on_wall():
				face(-facing)
				_turn_cooldown = 0.3
			velocity.x = facing * walk_speed
			_play_loop(&"run", 0.6)
			# Solo ve hacia donde mira (el rayo no atraviesa paredes)
			if _can_see(facing):
				_sight_lost_timer = 0.0
				_state = State.CHASE
		State.CHASE:
			# Si algo se interpone mucho rato (o se aleja demasiado), deja de perseguir
			if player == null or global_position.distance_to(player.global_position) > detect_range * 1.5:
				_state = State.PATROL
				return
			if _can_see(signf(player.global_position.x - global_position.x)):
				_sight_lost_timer = 0.0
			else:
				_sight_lost_timer += delta
				if _sight_lost_timer >= lose_sight_time:
					_state = State.PATROL
					return
			face(player.global_position.x - global_position.x)
			velocity.x = facing * chase_speed
			_play_loop(&"run", 1.6)
			if absf(player.global_position.x - global_position.x) < charge_range:
				_start_windup()
		State.WINDUP:
			velocity.x = 0.0
			_timer -= delta
			# Tiembla para avisar la embestida (sin cambiar de color)
			if _visual != null:
				_visual.position = _visual_base_pos + Vector2(randf_range(-WINDUP_SHAKE, WINDUP_SHAKE), 0.0)
			if _timer <= 0.0:
				_start_charge()
		State.CHARGE:
			velocity.x = _charge_dir * charge_speed
			_timer -= delta
			_charge_check()
			if is_on_wall():
				_start_recover(wall_stun_time)
			elif _timer <= 0.0:
				_start_recover(recover_time)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 2500.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_state = State.PATROL


## Usa el RayCast2D "Vision" (hijo del cangrejo; si no existe lo crea). Mueve el nodo en la
## escena para cambiar desde dónde mira.
func _setup_vision() -> void:
	_vision = get_node_or_null("Vision") as RayCast2D
	if _vision == null:
		_vision = RayCast2D.new()
		_vision.name = "Vision"
		_vision.position = Vector2(0.0, -45.0)
		add_child(_vision)
	_vision.enabled = true
	_vision.collision_mask = 1
	_vision.hit_from_inside = false


## true si el rayo horizontal (hacia `direction`: -1 izquierda, 1 derecha) llega hasta el jugador
## sin que haya una pared en medio. Como el rayo es recto a la altura del cuerpo, NO lo ve si
## está encima de él (más arriba que el rayo). Los otros enemigos no tapan la vista.
func _can_see(direction: float) -> bool:
	if _vision == null or is_zero_approx(direction):
		return false
	_vision.target_position = Vector2(signf(direction) * detect_range, 0.0)
	var excluded: Array[Object] = []
	var result := false
	for i in 6:
		_vision.force_raycast_update()
		if not _vision.is_colliding():
			break
		var collider := _vision.get_collider() as Node
		if collider != null and collider.is_in_group("enemies"):
			_vision.add_exception(collider)
			excluded.append(collider)
			continue
		result = collider != null and collider.is_in_group("players")
		break
	for node in excluded:
		_vision.remove_exception(node)
	return result


func _start_windup() -> void:
	_state = State.WINDUP
	_timer = windup_time
	velocity.x = 0.0
	_pause_anim()


func _start_charge() -> void:
	_state = State.CHARGE
	_timer = charge_time
	_charge_dir = facing
	_charge_hit = false
	_reset_visual_pos()
	_ignore_other_enemies(true)
	_play_loop(&"run", 3.0)


func _start_recover(time: float) -> void:
	_state = State.RECOVER
	_timer = time
	_ignore_other_enemies(false)
	_pause_anim()


func _reset_visual_pos() -> void:
	if _visual != null:
		_visual.position = _visual_base_pos


## Mientras embiste atraviesa a los demás enemigos (ellos tampoco lo frenan a él)
func _ignore_other_enemies(value: bool) -> void:
	if value:
		for node in get_tree().get_nodes_in_group("enemies"):
			if node != self and node is PhysicsBody2D:
				add_collision_exception_with(node)
				node.add_collision_exception_with(self)
				_passing_through.append(node)
	else:
		for node in _passing_through:
			if is_instance_valid(node):
				remove_collision_exception_with(node)
				node.remove_collision_exception_with(self)
		_passing_through.clear()


## Durante la embestida, si toca al jugador lo daña y lo empuja fuerte (una vez por embestida)
func _charge_check() -> void:
	if _charge_hit or _contact_area == null:
		return
	for body in _contact_area.get_overlapping_bodies():
		if body.is_in_group("players"):
			hurt_player(body, charge_damage, charge_knockback_scale)
			if body.has_method("stun"):
				body.stun(charge_stun_time)
			_charge_hit = true
			break


## Si le pegan por la espalda se da vuelta hacia el jugador (no interrumpe la preparación ni la embestida)
func _on_hurt() -> void:
	if _state == State.WINDUP or _state == State.CHARGE:
		return
	var player := _find_player()
	if player == null:
		return
	var dx := player.global_position.x - global_position.x
	if signf(dx) == -facing:
		face(dx)


func _on_died() -> void:
	_reset_visual_pos()
	_ignore_other_enemies(false)
