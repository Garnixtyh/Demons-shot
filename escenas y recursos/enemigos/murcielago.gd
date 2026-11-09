class_name Murcielago
extends EnemyBase
## Murciélago: enemigo volador. Flota en su lugar hasta que ve al jugador; entonces se acerca
## describiendo un arco y hace daño por contacto. Después de pegar se aleja un instante y
## vuelve a atacar curvando para el otro lado.

enum State { IDLE, TRACK, RETREAT }

@export var detect_range: float = 520.0
@export var approach_speed: float = 240.0
## Qué tanto se curva la trayectoria (radianes, cuando está lejos)
@export var arc_angle: float = 1.0
## Segundos que se aleja después de pegar
@export var retreat_time: float = 0.9
@export var retreat_speed: float = 260.0
## Altura (px) de lo que flota en reposo
@export var hover_amplitude: float = 10.0
## A qué altura del jugador apunta (negativo = más arriba de sus pies)
@export var aim_offset: Vector2 = Vector2(0, -60)

var _state: State = State.IDLE
var _arc_sign: float = 1.0
var _timer: float = 0.0
var _time: float = 0.0
var _home: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	uses_gravity = false
	_home = global_position
	_play_loop(&"fly")


func _ai(delta: float, player: Node2D) -> void:
	_time += delta
	match _state:
		State.IDLE:
			var target_y := _home.y + sin(_time * 2.0) * hover_amplitude
			velocity = Vector2(0.0, (target_y - global_position.y) * 4.0)
			if player != null and global_position.distance_to(player.global_position) < detect_range:
				_arc_sign = 1.0 if randf() < 0.5 else -1.0
				_state = State.TRACK
		State.TRACK:
			if player == null or global_position.distance_to(player.global_position) > detect_range * 1.8:
				_home = global_position
				_state = State.IDLE
				return
			var to_target := player.global_position + aim_offset - global_position
			var dist := to_target.length()
			# Lejos curva mucho, cerca va derecho: describe un arco hacia el jugador
			var dir := to_target.normalized().rotated(_arc_sign * arc_angle * clampf(dist / detect_range, 0.0, 1.0))
			velocity = velocity.lerp(dir * approach_speed, 1.0 - exp(-6.0 * delta))
			face(velocity.x)
		State.RETREAT:
			_timer -= delta
			var away := Vector2.ZERO
			if player != null:
				away = (global_position - player.global_position).normalized()
			away = (away + Vector2(0.0, -0.7)).normalized()
			velocity = velocity.lerp(away * retreat_speed, 1.0 - exp(-5.0 * delta))
			face(velocity.x)
			if _timer <= 0.0:
				_arc_sign = -_arc_sign
				_state = State.TRACK


func _on_contact_hit(_player: Node) -> void:
	_state = State.RETREAT
	_timer = retreat_time
