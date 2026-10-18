extends CharacterBody2D
## Panchu, el perro de Band (placeholder: dibujado por código).
## Persigue al enemigo vivo más cercano; al tocarlo le da un cabezazo
## (daño + aturdimiento). Desaparece al pasar `duration` o si muere su dueño.

## Quién lo soltó (no ataca a su equipo)
var owner_player: Node2D
var damage: float = 40.0
var stun_time: float = 0.5
var duration: float = 8.0
var speed: float = 420.0
var jump_velocity: float = -700.0
var gravity: float = 2200.0
## Qué tan cerca del enemigo tiene que estar para cabecear (horizontal / vertical)
var hit_range: Vector2 = Vector2(60.0, 85.0)
## Segundos hasta poder cabecear de nuevo al mismo enemigo
var rehit_delay: float = 1.5

var _time_left: float = 0.0
var _facing: float = 1.0
var _lunge: float = 0.0
var _hit_timers: Dictionary = {}


func _ready() -> void:
	collision_layer = 0  # no bloquea a nadie
	collision_mask = 1 | 4  # piso y plataformas
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 28)
	shape.shape = rect
	add_child(shape)
	z_index = 5
	_time_left = duration


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0 or not is_instance_valid(owner_player) or owner_player.is_dead:
		queue_free()
		return
	_lunge = maxf(_lunge - delta, 0.0)
	for enemy in _hit_timers.keys():
		_hit_timers[enemy] -= delta
		if _hit_timers[enemy] <= 0.0:
			_hit_timers.erase(enemy)

	var target := _find_target()
	var direction := 0.0
	if target != null:
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 8.0:
			direction = signf(dx)
	elif absf(owner_player.global_position.x - global_position.x) > 160.0:
		# Sin enemigos: se queda cerca de su dueño
		direction = signf(owner_player.global_position.x - global_position.x)

	velocity.x = move_toward(velocity.x, direction * speed, 3500.0 * delta)
	if direction != 0.0:
		_facing = direction
	# Salta los obstáculos o hacia un enemigo que está más arriba
	if is_on_floor():
		var target_above := target != null and target.global_position.y < global_position.y - 90.0
		if is_on_wall() or (target_above and absf(target.global_position.x - global_position.x) < 140.0):
			velocity.y = jump_velocity
	velocity.y += gravity * delta
	if global_position.y > 3000.0:
		queue_free()
		return
	move_and_slide()

	if target != null and not _hit_timers.has(target):
		var offset := target.global_position - global_position
		if absf(offset.x) <= hit_range.x and absf(offset.y) <= hit_range.y:
			_headbutt(target)
	queue_redraw()


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		if player == owner_player or player.is_dead or player.team == owner_player.team:
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


func _headbutt(target: Node2D) -> void:
	_hit_timers[target] = rehit_delay
	_lunge = 0.2
	velocity.x = _facing * speed * 1.4
	target.take_damage(damage)
	if target.has_method("stun"):
		target.stun(stun_time)


func _draw() -> void:
	var lunge_offset := _facing * 10.0 * (_lunge / 0.2)
	var brown := Color(0.6, 0.4, 0.2)
	draw_rect(Rect2(-22, -14, 44, 28), brown)  # cuerpo
	draw_circle(Vector2(_facing * 24.0 + lunge_offset, -8.0), 13.0, brown.darkened(0.2))  # cabeza
	draw_circle(Vector2(_facing * 28.0 + lunge_offset, -11.0), 3.0, Color.WHITE)  # ojo
	draw_rect(Rect2(-_facing * 22.0 - 4.0, -20.0, 8.0, 8.0), brown.darkened(0.3))  # cola
