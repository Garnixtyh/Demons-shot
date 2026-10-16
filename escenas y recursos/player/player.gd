extends CharacterBody2D
## Movimiento de plataformas: coyote time, jump buffer,
## altura de salto variable y gravedad distinta al subir / caer.
## También maneja la vida, la muerte y la reaparición.

signal health_changed(current: float, maximum: float)
signal died
signal respawned

@export_group("Movimiento horizontal")
@export var max_speed: float = 260.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
## Multiplicador de aceleración/fricción en el aire (1.0 = igual que en el suelo)
@export_range(0.0, 1.0) var air_control: float = 0.6

@export_group("Salto")
## Velocidad inicial del salto (negativa = hacia arriba)
@export var jump_velocity: float = -520.0
@export var gravity_rise: float = 1400.0
@export var gravity_fall: float = 2400.0
## Gravedad extra al soltar el botón mientras se sube (salto corto)
@export var jump_cut_multiplier: float = 3.0
@export var max_fall_speed: float = 900.0
## Tiempo (s) que todavía se puede saltar tras dejar el borde
@export var coyote_time: float = 0.1
## Tiempo (s) que se recuerda un salto presionado antes de tocar el suelo
@export var jump_buffer_time: float = 0.1

@export_group("Vida")
@export var max_health: float = 100.0
## Segundos entre la muerte y la reaparición
@export var respawn_time: float = 2.0
## Si el jugador cae por debajo de esta altura, muere
@export var fall_death_y: float = 1500.0
## Segundos de invulnerabilidad tras reaparecer
@export var spawn_protection: float = 0.75

@export_group("Protección de reaparición")
## Sprite semitransparente que aparece sobre el jugador mientras dura la
## protección (placeholder: icon.svg; cambialo por tu propio sprite)
@export var protection_texture: Texture2D = preload("res://icon.svg")
@export_range(0.0, 1.0) var protection_alpha: float = 0.5
@export var protection_scale: Vector2 = Vector2(0.6, 0.6)
## Posición del sprite respecto del jugador
@export var protection_offset: Vector2 = Vector2(0, -12)

@export_group("Equipo")
## 0 = rojo, 1 = azul. Lo asigna el CTFManager al empezar.
@export_enum("Rojo", "Azul") var team: int = 0

var health: float
var is_dead: bool = false
## Punto de reaparición. Por defecto es donde empieza el jugador;
## más adelante se asigna a la base de cada equipo.
var spawn_position: Vector2
## Bandera enemiga que lleva en este momento (null si no lleva ninguna)
var carried_flag: Node = null

var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0
var _protection_timer: float = 0.0
var _protection_sprite: Sprite2D

@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: CanvasItem = $Visuals
@onready var _health_bar: ProgressBar = $HealthBar
@onready var _weapon: Weapon = $Visuals/Weapon
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("players")
	_ensure_input_actions()
	_create_protection_sprite()
	spawn_position = global_position
	health = max_health
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_protection_timer = maxf(_protection_timer - delta, 0.0)
	_protection_sprite.visible = _protection_timer > 0.0
	if global_position.y > fall_death_y:
		die()
		return
	_handle_horizontal(delta)
	_handle_jump(delta)
	_apply_gravity(delta)
	move_and_slide()


func _handle_horizontal(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var rate := acceleration if dir != 0.0 else friction
	if not is_on_floor():
		rate *= air_control
	velocity.x = move_toward(velocity.x, dir * max_speed, rate * delta)


func _handle_jump(delta: float) -> void:
	# Coyote time: se renueva en el suelo y decae en el aire
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	# Jump buffer: se recuerda el último salto presionado
	if Input.is_action_just_pressed("jump"):
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer -= delta

	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_buffer_timer = 0.0
		_coyote_timer = 0.0


func _apply_gravity(delta: float) -> void:
	var g := gravity_rise if velocity.y < 0.0 else gravity_fall
	# Altura variable: si se suelta el botón mientras sube, cae antes
	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		g *= jump_cut_multiplier
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func take_damage(amount: float) -> void:
	if is_dead or _protection_timer > 0.0:
		return
	health = maxf(health - amount, 0.0)
	_update_health_bar()
	health_changed.emit(health, max_health)
	_flash()
	if health <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	velocity = Vector2.ZERO
	# Si llevaba una bandera, la suelta donde murió
	if carried_flag != null:
		carried_flag.drop()
	_body_shape.set_deferred("disabled", true)
	_visual.hide()
	_health_bar.hide()
	_protection_timer = 0.0
	_protection_sprite.hide()
	_weapon.hide()
	_weapon.set_process(false)
	_update_health_bar()
	health_changed.emit(health, max_health)
	died.emit()
	await get_tree().create_timer(respawn_time).timeout
	respawn()


func respawn() -> void:
	# 1. Con el cuerpo todavía invisible y sin colisión, se lo lleva al spawn.
	global_position = spawn_position
	velocity = Vector2.ZERO
	reset_physics_interpolation()
	_camera.reset_smoothing()

	# 2. Se espera a que el motor de física registre la nueva posición,
	#    para que nada (zonas de daño, balas) lo vea en el lugar donde murió.
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 3. Recién ahora vuelve a existir, con unos instantes de protección.
	_coyote_timer = 0.0
	_buffer_timer = 0.0
	health = max_health
	_protection_timer = spawn_protection
	_body_shape.set_deferred("disabled", false)
	_visual.show()
	_health_bar.show()
	_protection_sprite.visible = spawn_protection > 0.0
	_weapon.show()
	_weapon.set_process(true)
	_weapon.reset()
	_update_health_bar()
	is_dead = false
	health_changed.emit(health, max_health)
	respawned.emit()


## Crea por código el sprite que se muestra mientras dura la protección.
func _create_protection_sprite() -> void:
	_protection_sprite = Sprite2D.new()
	_protection_sprite.texture = protection_texture
	_protection_sprite.modulate.a = protection_alpha
	_protection_sprite.scale = protection_scale
	_protection_sprite.position = protection_offset
	_protection_sprite.z_index = 10
	_protection_sprite.visible = false
	add_child(_protection_sprite)


func get_weapon() -> Weapon:
	return _weapon


## Sube la vida máxima y cura esa misma cantidad (lo usan las mejoras).
func add_max_health(amount: float) -> void:
	max_health += amount
	health += amount
	_update_health_bar()
	health_changed.emit(health, max_health)


func _update_health_bar() -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health


func _flash() -> void:
	_visual.modulate = Color(3, 3, 3)
	await get_tree().create_timer(0.06).timeout
	_visual.modulate = Color.WHITE


## Crea las acciones de input por código si no existen en el Mapa de Entrada,
## así el script funciona sin configurar nada en Project Settings.
func _ensure_input_actions() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])


func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
