class_name Cangrejo
extends EnemyBase
## Cangrejo: patrulla; al detectar al jugador lo persigue, se prepara (se pone amarillo) y lo
## embiste. La embestida hace daño y empuja MUCHO más que el resto de los enemigos. Si se
## estrella contra una pared queda aturdido un rato (buen momento para pegarle).

enum State { PATROL, CHASE, WINDUP, CHARGE, RECOVER }

@export var walk_speed: float = 60.0
@export var chase_speed: float = 200.0
@export var charge_speed: float = 750.0
## Distancia a la que ve al jugador
@export var detect_range: float = 650.0
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

const WINDUP_TINT := Color(1.5, 1.25, 0.5)

var _state: State = State.PATROL
var _timer: float = 0.0
var _charge_dir: float = 1.0
var _charge_hit: bool = false
var _turn_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	# El sprite del cangrejo mira a la izquierda; si el tuyo mira a la derecha, cambialo en el Inspector
	face(1.0 if randf() < 0.5 else -1.0)
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
			if _sees(player):
				_state = State.CHASE
		State.CHASE:
			if player == null or global_position.distance_to(player.global_position) > detect_range * 1.5:
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


func _sees(player: Node2D) -> bool:
	return player != null and global_position.distance_to(player.global_position) < detect_range \
			and absf(player.global_position.y - global_position.y) < 260.0


func _start_windup() -> void:
	_state = State.WINDUP
	_timer = windup_time
	velocity.x = 0.0
	_pause_anim()
	if _visual != null:
		_visual.modulate = WINDUP_TINT


func _start_charge() -> void:
	_state = State.CHARGE
	_timer = charge_time
	_charge_dir = facing
	_charge_hit = false
	if _visual != null:
		_visual.modulate = Color.WHITE
	_play_loop(&"run", 3.0)


func _start_recover(time: float) -> void:
	_state = State.RECOVER
	_timer = time
	_pause_anim()


## Durante la embestida, si toca al jugador lo daña y lo empuja fuerte (una vez por embestida)
func _charge_check() -> void:
	if _charge_hit or _contact_area == null:
		return
	for body in _contact_area.get_overlapping_bodies():
		if body.is_in_group("players"):
			hurt_player(body, charge_damage, charge_knockback_scale)
			_charge_hit = true
			break


func _on_hurt() -> void:
	# Un golpe cancela la preparación (la embestida ya empezada sigue)
	if _state == State.WINDUP:
		if _visual != null:
			_visual.modulate = Color.WHITE
		_state = State.CHASE
