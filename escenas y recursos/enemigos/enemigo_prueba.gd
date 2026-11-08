class_name TestEnemy
extends CharacterBody2D
## Enemigo de prueba (placeholder). Patrulla; si ve al jugador lo persigue y, al estar cerca,
## prepara un golpe (se pone amarillo y se ve la zona del ataque) y pega. El golpe daña al jugador,
## lo hace retroceder y le rompe el combo.
## Al morir suma un kill al combo del jugador y, si respawn_time > 0, reaparece donde empezó
## (así se puede probar el combo todas las veces que quieras).

signal died(enemy: TestEnemy)

@export var max_health: float = 40.0
@export var walk_speed: float = 70.0
@export var chase_speed: float = 150.0
## Distancia a la que ve al jugador
@export var detect_range: float = 450.0
## Distancia a la que empieza el golpe
@export var attack_range: float = 70.0
@export var attack_damage: float = 15.0
## Segundos que "carga" el golpe antes de pegar (se puede esquivar)
@export var windup_time: float = 0.45
@export var attack_cooldown: float = 0.9
## Segundos hasta reaparecer (0 = no reaparece)
@export var respawn_time: float = 4.0
@export var gravity: float = 1800.0

enum State { PATROL, CHASE, WINDUP, COOLDOWN, STUNNED, DEAD }

const BASE_COLOR := Color(0.75, 0.15, 0.15)
const WINDUP_COLOR := Color(1.0, 0.85, 0.1)

var health: float = 0.0

var _state: State = State.PATROL
var _facing: float = 1.0
var _timer: float = 0.0
var _patrol_timer: float = 2.0
var _spawn: Vector2 = Vector2.ZERO
var _ignored: Dictionary = {}

@onready var _visual: ColorRect = $Visual
@onready var _attack_zone: Area2D = $AtaqueZona
@onready var _attack_warning: ColorRect = $AtaqueZona/Aviso
@onready var _label: Label = $Label
@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# "targets": Panchu y otras cosas lo persiguen
	add_to_group("targets")
	add_to_group("enemies")
	health = max_health
	_spawn = global_position
	_attack_warning.hide()
	_update_label()


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	velocity.y = minf(velocity.y + gravity * delta, 1200.0)
	var player := _find_player()
	if player != null:
		_ignore_player(player)
	match _state:
		State.PATROL:
			_patrol(delta, player)
		State.CHASE:
			_chase(player)
		State.WINDUP:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_do_attack()
		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_state = State.PATROL
		State.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_state = State.CHASE
	_attack_zone.position.x = _facing * 50.0
	move_and_slide()
	# Si se cae del mapa, vuelve a su lugar
	if global_position.y > _spawn.y + 1500.0:
		global_position = _spawn
		velocity = Vector2.ZERO


func _patrol(delta: float, player: Node2D) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0 or is_on_wall():
		_facing = -_facing
		_patrol_timer = randf_range(1.5, 3.0)
	velocity.x = _facing * walk_speed
	if player != null and absf(player.global_position.x - global_position.x) < detect_range \
			and absf(player.global_position.y - global_position.y) < 200.0:
		_state = State.CHASE


func _chase(player: Node2D) -> void:
	if player == null:
		_state = State.PATROL
		return
	var dx := player.global_position.x - global_position.x
	var dy := player.global_position.y - global_position.y
	if absf(dx) > detect_range * 1.4:
		_state = State.PATROL
		return
	_facing = 1.0 if dx >= 0.0 else -1.0
	if absf(dx) < attack_range and absf(dy) < 90.0:
		_start_windup()
	else:
		velocity.x = _facing * chase_speed


## El golpe se "carga": amarillo + zona visible. Da tiempo para esquivar.
func _start_windup() -> void:
	_state = State.WINDUP
	_timer = windup_time
	velocity.x = 0.0
	_visual.color = WINDUP_COLOR
	_attack_warning.show()


func _do_attack() -> void:
	_visual.color = BASE_COLOR
	_attack_warning.hide()
	for body in _attack_zone.get_overlapping_bodies():
		if body.is_in_group("players") and body.has_method("take_damage"):
			body.take_damage(attack_damage, global_position)
	_state = State.COOLDOWN
	_timer = attack_cooldown


func take_damage(amount: float) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_update_label()
	_flash()
	# Cada golpe alarga el combo del jugador
	get_tree().call_group("players", "register_hit", self)
	if health <= 0.0:
		_die()
		return
	# El golpe lo interrumpe un instante
	_visual.color = BASE_COLOR
	_attack_warning.hide()
	_state = State.STUNNED
	_timer = 0.2


func _die() -> void:
	_state = State.DEAD
	_visual.color = BASE_COLOR
	_attack_warning.hide()
	died.emit(self)
	# Suma un kill al combo del jugador
	get_tree().call_group("players", "register_kill", self)
	hide()
	_body_shape.set_deferred("disabled", true)
	_attack_zone.set_deferred("monitoring", false)
	if respawn_time <= 0.0:
		queue_free()
		return
	await get_tree().create_timer(respawn_time).timeout
	if is_inside_tree():
		_respawn()


func _respawn() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO
	health = max_health
	_state = State.PATROL
	_update_label()
	show()
	_body_shape.set_deferred("disabled", false)
	_attack_zone.set_deferred("monitoring", true)


## Jugador vivo más cercano (modo un jugador: el único)
func _find_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("players") as Node2D
	if player == null or ("is_dead" in player and player.is_dead):
		return null
	return player


## El enemigo y el jugador se atraviesan (no se empujan ni se traban); solo el golpe daña.
func _ignore_player(player: Node2D) -> void:
	if not _ignored.has(player):
		_ignored[player] = true
		add_collision_exception_with(player)


func _update_label() -> void:
	_label.text = "%d / %d" % [maxf(health, 0.0), max_health]


func _flash() -> void:
	_visual.modulate = Color(2, 2, 2)
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(self):
		_visual.modulate = Color.WHITE
