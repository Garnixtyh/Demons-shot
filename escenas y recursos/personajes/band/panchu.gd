extends CharacterBody2D
## Panchu, el perro de Band. Dos estados:
##  - ORBIT: con la habilidad cargada, da vueltas sobre la cabeza de Band.
##  - CHASE: lanzado con la E, persigue al enemigo más cercano (jugadores del
##    otro equipo y muñecos de práctica). Al tocarlo le da un cabezazo
##    (daño + aturdimiento) y DESAPARECE. También desaparece si pasa `duration`.
##
## Usa el mismo AnimationManager que el jugador (animaciones "idle" y "walk").
## Orbitando mira hacia el cursor; persiguiendo mira hacia su objetivo.

enum State { ORBIT, CHASE }

@export_group("Cabezazo")
@export var damage: float = 40.0
## Segundos que aturde
@export var stun_time: float = 0.5
## Qué tan cerca del enemigo tiene que estar (horizontal / vertical)
@export var hit_range: Vector2 = Vector2(60.0, 85.0)

@export_group("Persecución")
## Segundos que persigue antes de desaparecer
@export var duration: float = 8.0
@export var speed: float = 420.0
@export var jump_velocity: float = -700.0
@export var gravity: float = 2200.0

@export_group("Órbita (habilidad cargada)")
## Centro de la órbita respecto de Band (hacia arriba = y negativo)
@export var orbit_offset: Vector2 = Vector2(0.0, -110.0)
## Tamaño de la órbita (ancho, alto)
@export var orbit_radius: Vector2 = Vector2(50.0, 18.0)
## Velocidad de giro (radianes por segundo)
@export var orbit_speed: float = 2.5
## Escala de Panchu mientras orbita
@export var orbit_scale: float = 0.6

## Quién lo tiene (lo asigna la habilidad)
var owner_player: Node2D
var state: State = State.ORBIT
## Los usa el AnimationManager (es el mismo script que el del jugador)
var is_dead: bool = false
var max_speed: float = 420.0

var _time_left: float = 0.0
## 1 = derecha, -1 = izquierda
var _facing: float = 1.0
var _orbit_angle: float = 0.0

@onready var _visuals: Node2D = $Visuals
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _animator := get_node_or_null("AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	max_speed = speed
	# Corre después del AnimationManager, así el lado que mira lo decide Panchu
	process_priority = 10
	_orbit_angle = randf() * TAU
	_enter_orbit()


## La habilidad lo llama al apretar E: sale de la órbita y empieza a perseguir.
func launch() -> void:
	if state != State.ORBIT:
		return
	state = State.CHASE
	_time_left = duration
	scale = Vector2.ONE
	_shape.set_deferred("disabled", false)
	if _animator != null:
		_animator.set_process(true)
	velocity = Vector2(0.0, -250.0)


func _enter_orbit() -> void:
	state = State.ORBIT
	velocity = Vector2.ZERO
	scale = Vector2.ONE * orbit_scale
	_shape.set_deferred("disabled", true)
	# En órbita las animaciones no se manejan solas: queda en idle
	if _animator != null:
		_animator.set_process(false)
		if _animator.has_animation(&"idle"):
			_animator.play(&"idle")


func _process(_delta: float) -> void:
	_visuals.scale.x = _facing


func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	if state == State.ORBIT:
		_update_orbit(delta)
	else:
		_update_chase(delta)


func _update_orbit(delta: float) -> void:
	visible = not owner_player.is_dead
	_orbit_angle += orbit_speed * delta
	var target := owner_player.global_position + orbit_offset \
			+ Vector2(cos(_orbit_angle) * orbit_radius.x, sin(_orbit_angle) * orbit_radius.y)
	global_position = global_position.lerp(target, 1.0 - exp(-12.0 * delta))
	# Orbitando mira hacia el cursor
	var to_cursor := get_global_mouse_position().x - global_position.x
	if absf(to_cursor) > 5.0:
		_facing = signf(to_cursor)


func _update_chase(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0 or owner_player.is_dead:
		queue_free()
		return

	var target := _find_target()
	var direction := 0.0
	if target != null:
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 8.0:
			direction = signf(dx)
			# En el campo de batalla mira hacia su objetivo, no hacia el cursor
			_facing = direction
	elif absf(owner_player.global_position.x - global_position.x) > 160.0:
		# Sin enemigos: se acerca a su dueño y mira hacia donde va
		direction = signf(owner_player.global_position.x - global_position.x)
		_facing = direction

	velocity.x = move_toward(velocity.x, direction * speed, 3500.0 * delta)
	# Salta los obstáculos o hacia un objetivo que está más arriba
	if is_on_floor():
		var target_above := target != null and target.global_position.y < global_position.y - 90.0 \
				and absf(target.global_position.x - global_position.x) < 140.0
		if is_on_wall() or target_above:
			velocity.y = jump_velocity
	velocity.y += gravity * delta
	if global_position.y > 3000.0:
		queue_free()
		return
	move_and_slide()

	if target != null:
		var offset := target.global_position - global_position
		if absf(offset.x) <= hit_range.x and absf(offset.y) <= hit_range.y:
			_headbutt(target)


## Enemigo más cercano: jugadores del otro equipo y objetos del grupo "targets".
func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	var candidates: Array = []
	for player in get_tree().get_nodes_in_group("players"):
		if player != owner_player and not player.is_dead and player.team != owner_player.team:
			candidates.append(player)
	candidates.append_array(get_tree().get_nodes_in_group("targets"))
	for candidate in candidates:
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _headbutt(target: Node2D) -> void:
	target.take_damage(damage)
	if target.has_method("stun"):
		target.stun(stun_time)
	queue_free()  # Panchu desaparece al cabecear
