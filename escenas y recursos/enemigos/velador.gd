class_name Velador
extends EnemyBase
## Velador: enemigo a distancia. Se queda en su lugar mirando al jugador y le lanza su vela en
## arco. La vela hace daño al impactar y deja tres fuegos en el piso que dañan un tiempo
## (vela_proyectil.gd y fuego.gd). Usa las animaciones "idle" y "shot" de su escena.

enum State { IDLE, THROW }

## Distancia máxima a la que lanza
@export var throw_range: float = 800.0
@export var throw_cooldown: float = 2.5
## Segundos desde que empieza la animación "shot" hasta que suelta la vela
@export var throw_delay: float = 0.35
## Velocidad aproximada de la vela (define cuánto tarda en llegar)
@export var throw_speed: float = 600.0
@export var candle_gravity: float = 900.0
@export var candle_damage: float = 15.0
@export_group("Fuego")
@export var fire_count: int = 3
## Separación horizontal entre los fuegos
@export var fire_spacing: float = 45.0
@export var fire_damage: float = 6.0
@export var fire_tick: float = 0.7
@export var fire_duration: float = 4.0
## Sprite del fuego (hoja de frames en horizontal). Vacío = sprites/enemigos/velador/fuego.png
@export var fire_texture: Texture2D
@export var fire_hframes: int = 4
## Tamaño del sprite del fuego (y de su zona de daño)
@export var fire_scale: Vector2 = Vector2(1, 1)
@export_group("")
## Si el jugador se acerca más que esto, retrocede
@export var keep_distance: float = 110.0
@export var retreat_speed: float = 90.0

const DEFAULT_FIRE := "res://sprites/enemigos/velador/fuego.png"
const DEFAULT_CANDLE := "res://sprites/enemigos/velador/vela.png"

var _state: State = State.IDLE
var _timer: float = 0.0
var _cooldown: float = 1.0
var _thrown: bool = false
var _hand_candle: Node2D = null


func _ready() -> void:
	super._ready()
	if _visual != null:
		_hand_candle = _visual.get_node_or_null("Vela") as Node2D
	if fire_texture == null and ResourceLoader.exists(DEFAULT_FIRE):
		fire_texture = load(DEFAULT_FIRE)
	_play_loop(&"idle")


func _ai(delta: float, player: Node2D) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	match _state:
		State.IDLE:
			velocity.x = 0.0
			if player == null:
				return
			face(player.global_position.x - global_position.x)
			var dist := global_position.distance_to(player.global_position)
			if dist < keep_distance:
				velocity.x = -facing * retreat_speed
			if _cooldown <= 0.0 and dist < throw_range:
				_start_throw()
		State.THROW:
			velocity.x = 0.0
			_timer += delta
			if not _thrown and _timer >= throw_delay:
				_thrown = true
				if player != null:
					_throw_at(player)
			var shot_length := _anim.get_animation(&"shot").length if _anim != null and _anim.has_animation(&"shot") else 0.6
			if _timer >= maxf(shot_length, throw_delay + 0.1):
				_end_throw()


func _start_throw() -> void:
	_state = State.THROW
	_timer = 0.0
	_thrown = false
	if _anim != null and _anim.has_animation(&"shot"):
		_anim.speed_scale = 1.0
		_anim.play(&"shot")


func _end_throw() -> void:
	_state = State.IDLE
	_cooldown = throw_cooldown
	# Vuelve a tener una vela en la mano
	if _hand_candle != null:
		_hand_candle.show()
	_play_loop(&"idle")


## Lanza la vela en arco para que caiga sobre la posición actual del jugador
func _throw_at(player: Node2D) -> void:
	var start := global_position + Vector2(facing * 27.0, -45.0)
	var texture: Texture2D = null
	var candle_scale := _visual.scale if _visual != null else Vector2.ONE
	if _hand_candle != null:
		start = _hand_candle.global_position
		candle_scale = _hand_candle.global_scale.abs()
		if _hand_candle is Sprite2D:
			texture = (_hand_candle as Sprite2D).texture
		_hand_candle.hide()
	if texture == null and ResourceLoader.exists(DEFAULT_CANDLE):
		texture = load(DEFAULT_CANDLE)
	var target := player.global_position + Vector2(0.0, -40.0)
	var flight := clampf(start.distance_to(target) / throw_speed, 0.45, 1.5)
	# Trayectoria balística: llega al objetivo en `flight` segundos
	var vel := Vector2((target.x - start.x) / flight,
			(target.y - start.y - 0.5 * candle_gravity * flight * flight) / flight)

	var candle := CandleProjectile.new()
	candle.thrower = self
	candle.velocity = vel
	candle.fall_gravity = candle_gravity
	candle.damage = candle_damage
	candle.texture = texture
	candle.sprite_scale = candle_scale
	candle.fire_count = fire_count
	candle.fire_spacing = fire_spacing
	candle.fire_damage = fire_damage
	candle.fire_tick = fire_tick
	candle.fire_duration = fire_duration
	candle.fire_texture = fire_texture
	candle.fire_hframes = fire_hframes
	candle.fire_scale = fire_scale
	get_parent().add_child(candle)
	candle.global_position = start


func _on_died() -> void:
	if _hand_candle != null:
		_hand_candle.show()
