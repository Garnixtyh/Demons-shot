extends CharacterBody2D
## Movimiento de plataformas: coyote time, jump buffer,
## altura de salto variable y gravedad distinta al subir / caer.
## También maneja la vida, la muerte y la reaparición.

signal health_changed(current: float, maximum: float)
signal died
signal respawned
signal dashed

## Shader que mezcla los colores del personaje con blanco (efecto del esquive)
const FLASH_SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, amount);
}
"""

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

@export_group("Esquive (Shift)")
@export var dash_speed: float = 700.0
## Segundos que dura el esquive
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.8
## Si es true, no recibe daño mientras dura el esquive
@export var dash_invulnerable: bool = true
## Qué tan blanco se pone el personaje (1 = blanco total, menos = semitransparente)
@export_range(0.0, 1.0) var dash_flash_strength: float = 0.8
@export var dash_flash_color: Color = Color.WHITE
## Segundos del degradado con el que aparece el blanco
@export var dash_flash_fade_in: float = 0.08
## Segundos del degradado con el que se va el blanco
@export var dash_flash_fade_out: float = 0.3

## Capa de colisión (1-32) donde viven las plataformas de un solo sentido
const PLATFORM_LAYER := 3

@export_group("Plataformas y objetos")
## Segundos que ignora las plataformas al bajar con S
@export var drop_through_time: float = 0.3
## Distancia máxima (en píxeles) para empujar objetos con F
@export var push_range: float = 130.0

@export_group("Personaje")
## Personaje elegido. Define qué archivos usa: <carpeta>/<nombre>/<nombre>_stats.gd
## (stats base y habilidad) y <nombre>_pool.gd (su pool de mejoras).
@export var character: String = "band"
## Carpeta donde está cada personaje (uno por subcarpeta)
@export_dir var characters_folder: String = "res://escenas y recursos/personajes"

@export_group("Habilidad especial (E)")
## OPCIONAL: fuerza una habilidad concreta (script que extienda abilities/ability.gd)
## ignorando la del personaje. Dejalo vacío para usar la del personaje.
## Si el jugador tiene un nodo hijo llamado "Ability", se usa ese.
@export_file("*.gd") var ability_script_path: String = ""

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
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0
var _flash_material: ShaderMaterial
var _flash_tween: Tween
var _ability: Node = null
var _drop_timer: float = 0.0
var _stun_timer: float = 0.0
var _stun_label: Label
## Datos del personaje cargado (ver personajes/character_stats.gd)
var _character_data: RefCounted = null

@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: CanvasItem = $Visuals
@onready var _health_bar: ProgressBar = $HealthBar
@onready var _weapon: Weapon = $Visuals/Weapon
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("players")
	# Para poder pisar las plataformas (capa 3)
	set_collision_mask_value(PLATFORM_LAYER, true)
	_ensure_input_actions()
	_create_protection_sprite()
	_setup_flash_material()
	_create_stun_indicator()
	_load_character()
	_setup_ability()
	spawn_position = global_position
	health = max_health
	_update_health_bar()
	# Diferido: así los límites del mapa ya están en la escena
	_apply_camera_bounds.call_deferred()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_protection_timer = maxf(_protection_timer - delta, 0.0)
	_protection_sprite.visible = _protection_timer > 0.0
	if global_position.y > fall_death_y:
		die()
		return
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	if _update_stun(delta):
		return
	_handle_drop_input(delta)
	_handle_dash_input()
	if _is_dashing:
		_update_dash(delta)
	else:
		_handle_horizontal(delta)
		_handle_jump(delta)
		_apply_gravity(delta)
	_handle_ability_input()
	_handle_push_input(delta)
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
	if _is_dashing and dash_invulnerable:
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
	_reset_dash_state()
	_stun_timer = 0.0
	_weapon.enabled = true
	_stun_label.hide()
	_drop_timer = 0.0
	set_collision_mask_value(PLATFORM_LAYER, true)
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


func _handle_dash_input() -> void:
	if _is_dashing or _dash_cooldown_timer > 0.0:
		return
	if Input.is_action_just_pressed("dash"):
		_start_dash()


func _start_dash() -> void:
	# Hacia donde se mueve; si está quieto, hacia donde apunta el mouse
	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0.0:
		direction = 1.0 if get_global_mouse_position().x >= global_position.x else -1.0
	_dash_direction = signf(direction)
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	velocity.y = 0.0
	_play_dash_flash()
	dashed.emit()


func _update_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity.x = _dash_direction * dash_speed
	velocity.y = 0.0
	if _dash_timer <= 0.0:
		_is_dashing = false
		# Al terminar conserva algo de impulso, sin salir disparado
		velocity.x = _dash_direction * minf(max_speed, dash_speed)


func _reset_dash_state() -> void:
	_is_dashing = false
	if _flash_tween != null:
		_flash_tween.kill()
	_set_flash_amount(0.0)


## El blanco aparece con degradado, se mantiene durante el esquive y se desvanece.
func _play_dash_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, 0.0, dash_flash_strength, dash_flash_fade_in)
	_flash_tween.tween_interval(maxf(dash_duration - dash_flash_fade_in, 0.0))
	_flash_tween.tween_method(_set_flash_amount, dash_flash_strength, 0.0, dash_flash_fade_out)


func _set_flash_amount(value: float) -> void:
	_flash_material.set_shader_parameter("amount", value)


## Aplica el shader a todo el personaje (Visuals y todos sus sprites).
func _setup_flash_material() -> void:
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = shader
	_flash_material.set_shader_parameter("flash_color", dash_flash_color)
	_visual.material = _flash_material
	for item in _visual.find_children("*", "CanvasItem", true, false):
		item.use_parent_material = true


func _handle_ability_input() -> void:
	if _ability != null and Input.is_action_just_pressed("ability"):
		_ability.try_activate()


## Busca la habilidad del personaje: un nodo hijo "Ability" o el script indicado.
func _setup_ability() -> void:
	_ability = get_node_or_null("Ability")
	if _ability != null:
		return
	if not ability_script_path.is_empty():
		if ResourceLoader.exists(ability_script_path):
			set_ability_script(load(ability_script_path))
		else:
			push_warning("Player: no encontré la habilidad '%s'. Revisá ability_script_path." % ability_script_path)
		return
	if _character_data != null:
		set_ability_script(_character_data.ability_script)


## Cambia la habilidad de la E por la de este script (lo usan las mejoras de habilidad).
func set_ability_script(script: Script) -> void:
	if script == null:
		return
	if _ability != null and is_instance_valid(_ability):
		_ability.name = "AbilityOld"  # libera el nombre "Ability"
		_ability.queue_free()
	_ability = Node.new()
	_ability.name = "Ability"
	_ability.set_script(script)
	add_child(_ability)


## Carga los stats base del personaje elegido (variable `character`).
func _load_character() -> void:
	var path := "%s/%s/%s_stats.gd" % [characters_folder, character, character]
	if not ResourceLoader.exists(path):
		push_warning("Player: no encontré el personaje '%s' (%s). Revisá character y characters_folder." % [character, path])
		return
	_character_data = load(path).new()
	_character_data.apply(self, _weapon.stats)


## Mejoras propias del personaje (<nombre>_pool.gd). La pide el RoundManager.
func get_character_upgrades() -> Array:
	var path := "%s/%s/%s_pool.gd" % [characters_folder, character, character]
	if not ResourceLoader.exists(path):
		return []
	return load(path).new().create_upgrades()


## Aturde al jugador: no puede moverse, disparar, esquivar ni usar la E.
func stun(duration: float) -> void:
	if is_dead or _protection_timer > 0.0:
		return
	if _is_dashing and dash_invulnerable:
		return
	_reset_dash_state()
	_stun_timer = maxf(_stun_timer, duration)


func is_stunned() -> bool:
	return _stun_timer > 0.0


## Avanza el aturdimiento. Devuelve true si está aturdido (se saltea el control).
func _update_stun(delta: float) -> bool:
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	var stunned := _stun_timer > 0.0
	_weapon.enabled = not stunned
	_stun_label.visible = stunned
	if not stunned:
		return false
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	_apply_gravity(delta)
	move_and_slide()
	return true


func _create_stun_indicator() -> void:
	_stun_label = Label.new()
	_stun_label.text = "¡ATURDIDO!"
	_stun_label.add_theme_font_size_override("font_size", 14)
	_stun_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_stun_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_stun_label.add_theme_constant_override("outline_size", 4)
	_stun_label.position = Vector2(-36, -84)
	_stun_label.z_index = 10
	_stun_label.visible = false
	add_child(_stun_label)


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
	max_health = maxf(max_health + amount, 1.0)
	health = clampf(health + amount, 1.0, max_health)
	_update_health_bar()
	health_changed.emit(health, max_health)


func _update_health_bar() -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health


func _flash() -> void:
	_visual.modulate = Color(3, 3, 3)
	await get_tree().create_timer(0.06).timeout
	_visual.modulate = Color.WHITE


## Limita la cámara al área definida por un nodo "LimitesCamara" del mapa
## (grupo "camera_bounds"). Si no hay ninguno, la cámara queda libre.
func _apply_camera_bounds() -> void:
	var bounds := get_tree().get_first_node_in_group("camera_bounds")
	if bounds == null or not bounds.has_method("get_rect_global"):
		return
	var rect: Rect2 = bounds.get_rect_global()
	_camera.limit_left = roundi(rect.position.x)
	_camera.limit_top = roundi(rect.position.y)
	_camera.limit_right = roundi(rect.end.x)
	_camera.limit_bottom = roundi(rect.end.y)
	_camera.limit_smoothed = true
	_camera.reset_smoothing()


## S: baja a través de la plataforma de un solo sentido donde está parado.
func _handle_drop_input(delta: float) -> void:
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER, true)
		return
	if Input.is_action_just_pressed("move_down") and is_on_floor() and _is_standing_on_platform():
		_drop_timer = drop_through_time
		set_collision_mask_value(PLATFORM_LAYER, false)


func _is_standing_on_platform() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y > -0.5:
			continue
		var collider := collision.get_collider() as CollisionObject2D
		if collider != null and collider.get_collision_layer_value(PLATFORM_LAYER):
			return true
	return false


## F (mantener): empuja los objetos del grupo "pushables" que estén cerca.
func _handle_push_input(delta: float) -> void:
	if not Input.is_action_pressed("push"):
		return
	for node in get_tree().get_nodes_in_group("pushables"):
		if not node.has_method("push"):
			continue
		var offset: Vector2 = node.global_position - global_position
		if offset.length() > push_range:
			continue
		node.push(signf(offset.x), delta)


## Crea las acciones de input por código si no existen en el Mapa de Entrada,
## así el script funciona sin configurar nada en Project Settings.
func _ensure_input_actions() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("dash", [KEY_SHIFT])
	_add_action("ability", [KEY_E])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("push", [KEY_F])


func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
