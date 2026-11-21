extends CharacterBody2D
## Movimiento de plataformas: coyote time, jump buffer,
## altura de salto variable y gravedad distinta al subir / caer.
## También maneja la vida, la muerte y la reaparición.

signal health_changed(current: float, maximum: float)
signal died
signal respawned
signal dashed
## Un parry (un jugador) frenó a un enemigo o devolvió un proyectil
signal parried
## Cambió lo que hay en el bolsillo de consumibles (null = vacío)
signal pocket_changed(item: Consumable)
## Cambió la cantidad de puntos (los que se gastan en la tienda)
signal points_changed(points: int)

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
## Qué hace el botón Shift: 0 = Dash, 1 = Parry. Online siempre es Dash (el parry no se replica)
@export_enum("Dash", "Parry") var shift_ability: int = 1

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
## En UN JUGADOR el botón de esquive (Shift) es un PARRY en vez de un dash: usa las mismas
## poses (band_pose1, band_pose2...), pero se queda en el lugar. Mientras dura es invulnerable; los
## enemigos que lo toquen o estén cerca quedan aturdidos y salen empujados, y los proyectiles
## (la vela del velador) se devuelven. En partida online el dash sigue igual.
@export_group("Parry (un jugador)")
## Cuánto dura la ventana del parry (s)
@export var parry_duration: float = 0.28
## Espera hasta poder volver a usarlo (s). Si el parry acierta se acorta a `parry_success_cooldown`
@export var parry_cooldown: float = 0.7
@export var parry_success_cooldown: float = 0.15
## Alcance alrededor del jugador (px) para frenar enemigos y devolver proyectiles
@export var parry_radius: float = 120.0
## Segundos que queda aturdido el enemigo parreado
@export var parry_stun_time: float = 1.5
## Empuje que recibe el enemigo (px/s)
@export var parry_knockback: float = 380.0
## Invulnerabilidad extra (s) cuando el parry acierta. Es SIN escudo visible (no usa la burbuja de protección)
@export var parry_success_protection: float = 0.5
## Color del destello del parry
@export var parry_flash_color: Color = Color(1.0, 0.85, 0.3)
## Tamaño de la imagen de pose del parry. 0.245 es la escala del esqueleto del personaje (las poses
## están dibujadas a la misma resolución), así que la pose queda del mismo tamaño que el cuerpo.
@export var parry_pose_scale: Vector2 = Vector2(0.245, 0.245)
## Altura de los pies del personaje (dentro de Visuals): la pose se apoya ahí, sin importar cuánto mida
@export var parry_pose_feet_y: float = 22.0
## Ajuste fino de la posición de la pose (se suma a la alineación automática por los pies)
@export var parry_pose_offset: Vector2 = Vector2.ZERO
## Cuánto se congela todo el juego (s, tiempo real) al usar el parry. 0 = sin congelado
@export var parry_hitstop: float = 0.08
@export_group("Dash (online)")
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

@export_group("Esquive: estela")
## Deja copias del personaje que se desvanecen mientras dura el esquive
@export var dash_ghosts_enabled: bool = true
## Segundos entre copia y copia
@export var dash_ghost_interval: float = 0.03
## Segundos que tarda cada copia en desvanecerse por completo
@export var dash_ghost_fade_time: float = 0.35
## Color (y transparencia inicial) de las copias
@export var dash_ghost_color: Color = Color(0.75, 0.85, 1.0, 0.6)

## HUD del bolsillo de consumibles (se crea como hijo del jugador)
const CONSUMABLES_HUD := preload("res://escenas y recursos/consumibles/consumables_hud.tscn")

const STUN_TEXT_COLOR := Color(1.0, 0.9, 0.15)
const STUN_TEXT_RISE := 50.0
const STUN_TEXT_TIME := 0.9

## Carta Justice: sangrado que reciben los enemigos que te dañan (daño por tick, segundos, cada cuánto)
const JUSTICE_BLEED_DAMAGE := 4.0
const JUSTICE_BLEED_TIME := 3.0
const JUSTICE_BLEED_INTERVAL := 0.5
## Si no se sabe quién te pegó, busca el enemigo más cercano dentro de este radio (px)
const JUSTICE_SEARCH_RADIUS := 160.0

## HUD de habilidades (pava y golpe melee), se crea como hijo del jugador
const ABILITIES_HUD := preload("res://escenas y recursos/hud/abilities_hud.gd")

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
## true si quien lo crea ya le puso su personaje (copias de red). Si no, en una partida en red
## el jugador del mapa usa el personaje que elegiste en la sala de espera.
var character_assigned: bool = false
## Carpeta donde está cada personaje (uno por subcarpeta)
@export_dir var characters_folder: String = "res://escenas y recursos/personajes"

@export_group("Melee (clic derecho)")
## Daño del golpe
@export var melee_damage: float = 15.0
## Segundos que dura el golpe: durante ese tiempo solo puede caminar y saltar
@export var melee_duration: float = 0.3
## Segundos desde que empieza un golpe hasta poder dar otro
@export var melee_cooldown: float = 0.5
## Momento del golpe (segundos desde que empieza) en que hace daño
@export var melee_hit_start: float = 0.08
@export var melee_hit_end: float = 0.2
## Zona que golpea (tamaño y posición delante del jugador, mirando a la derecha; se espeja sola)
@export var melee_hitbox_size: Vector2 = Vector2(50, 44)
@export var melee_hitbox_offset: Vector2 = Vector2(35, 0)
@export var melee_fx_color: Color = Color(1, 1, 1, 0.9)
@export_group("Habilidad especial (E)")
## OPCIONAL: fuerza una habilidad concreta (script que extienda abilities/ability.gd)
## ignorando la del personaje. Dejalo vacío para usar la del personaje.
## Si el jugador tiene un nodo hijo llamado "Ability", se usa ese.
@export_file("*.gd") var ability_script_path: String = ""

@export_group("Vida")
@export var max_health: float = 100.0
## Segundos entre la muerte y la reaparición
@export var respawn_time: float = 2.0
## false = al morir NO reaparece solo (modo un jugador: el RunManager muestra la pantalla de muerte)
@export var auto_respawn: bool = true
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
@export_group("Daño recibido")
## Segundos que parpadea el personaje al recibir daño
@export var hurt_blink_time: float = 0.6
## Retroceso al recibir un golpe con origen conocido (enemigos): velocidad horizontal y salto hacia arriba
@export var knockback_speed: float = 420.0
@export var knockback_up: float = -220.0
## Segundos que dura el retroceso (no se puede controlar el movimiento horizontal)
@export var knockback_time: float = 0.18
@export_group("")

## Consumible guardado en el bolsillo (null = vacío). Se usa con la Q. Cabe uno solo.
var pocket: Consumable = null
## Puntos para gastar en la tienda del modo un jugador
@export var points: int = 0

var _knockback_timer: float = 0.0
var _blink_tween: Tween
## Combo de kills (ver combo/combo_tracker.gd)
var _combo: ComboTracker = null
## Sonidos del esquive: rota entre ellos sin repetir el último (bus "Efectos")
const DASH_SOUNDS: Array[String] = [
	"res://sonido/sfx/dash1.ogg",
	"res://sonido/sfx/dash2.ogg",
]
var _dash_sfx: SfxPlayer = null

var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0
var _protection_timer: float = 0.0
## Sangrado de los cuchillos (modificador de la fase 3)
const KNIFE_BLEED_DAMAGE := 3.0
const KNIFE_BLEED_TIME := 3.0
const KNIFE_BLEED_INTERVAL := 0.5
## Daño extra que reciben los golpes de enemigos (lo usa el modificador David vs. Goliat)
var incoming_damage_bonus: float = 0.0
## true = no se puede usar el parry (modificador Enemigos precisos)
var parry_blocked: bool = false
## Mejoras que agarró el jugador (para el menú de pausa): { "title", "description", "icon_path", "count" }
var collected_items: Array[Dictionary] = []
## Invulnerabilidad corta tras un parry acertado (sin burbuja de escudo)
var _parry_grace_timer: float = 0.0
var _protection_sprite: Sprite2D
var _is_dashing: bool = false
var _is_parrying: bool = false
var _parry_timer: float = 0.0
## Enemigos/proyectiles ya parreados en este parry (cada uno una sola vez)
var _parry_hits: Dictionary = {}
## Poses del personaje para el parry (band_pose1, band_pose2...) y los nodos ocultos mientras se muestra una
var _parry_poses: Array[Texture2D] = []
var _parry_pose_sprite: Sprite2D = null
var _parry_hidden: Array[CanvasItem] = []
## Momento (ms, tiempo real) en que termina el congelado del parry; 0 = no hay congelado activo
var _hitstop_end_msec: int = 0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0
var _flash_material: ShaderMaterial
var _flash_tween: Tween
var _ghost_timer: float = 0.0
var _ability: Node = null
## Pasiva del personaje (nodo hijo "Passive"), si tiene
var _passive: Node = null
## Segundos que le quedan al escudo (invencible, sin poder atacar). Ver start_shield()
var _shield_timer: float = 0.0
var _drop_timer: float = 0.0
var _stun_timer: float = 0.0
var _justice_timer: float = 0.0
var _scale_tween: Tween
## Datos del personaje cargado (ver personajes/character_stats.gd)
var _character_data: RefCounted = null
## Personaje cuyo aspecto (arma y bala) está aplicado ahora. En las copias de red cambia cuando llega el `character` real.
var _look_character: String = ""
## Nombre sobre el jugador y estado de muerte ya aplicado (solo jugadores remotos)
var _name_label: Label
var _remote_dead_applied: bool = false
## Si está apoyado en el piso. Se replica para que las otras PCs elijan la animación.
var net_on_floor: bool = true
## true = quieto e invulnerable (elección de mejoras entre rondas en red)
var net_frozen: bool = false
## true mientras una transición de sala lo mueve solo: sin control, pero con animación de caminar.
## transition_dir = hacia dónde mira (-1 izquierda, 1 derecha, 0 = no cambia)
var transition_walk: bool = false
var transition_dir: float = 0.0
## true mientras hace el golpe melee (el AnimationManager reproduce "melee" si existe)
var melee_active: bool = false
## Hacia dónde pegó el último golpe (1 derecha, -1 izquierda)
var melee_dir: float = 1.0
var _melee_time: float = 0.0
var _melee_cooldown_timer: float = 0.0
var _melee_hit: Dictionary = {}
var _melee_area: Area2D
var _melee_fx: Node2D
var _melee_tween: Tween
## true mientras tiene el escudo de protección (se replica para que los demás lo vean)
var net_protected: bool = false
## true mientras hace el esquive (se replica: los demás ven la estela y su pose)
var net_dashing: bool = false
## Índice de la pose de esquive que tocó (de las poses del personaje). La elige al azar el dueño y se replica.
var net_dash_variant: int = 0
## Pose de esquive que se está mostrando en esta PC (copias de red); -2 = ninguna
var _remote_pose_shown: int = -2

@onready var _animator := get_node_or_null("AnimationPlayer") as AnimationManager
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
	_create_melee()
	add_child(CONSUMABLES_HUD.instantiate())
	add_child(ABILITIES_HUD.new())
	_combo = ComboTracker.new()
	add_child(_combo)
	_dash_sfx = SfxPlayer.new()
	_dash_sfx.load_paths(DASH_SOUNDS)
	add_child(_dash_sfx)
	_load_character()
	_setup_ability()
	_setup_passive()
	spawn_position = global_position
	health = max_health
	_update_health_bar()
	# Diferido: así los límites del mapa ya están en la escena
	_apply_camera_bounds.call_deferred()


## DEBUG: con la tecla 7 se usa el efecto de The Death (daño a todos los enemigos de la sala)
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_7:
		var damage: float = CartaTarot.DEATH_DAMAGE
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
				continue
			if "dead" in enemy and enemy.dead:
				continue
			enemy.combo_silent = true
			enemy.take_damage(damage)
			if is_instance_valid(enemy):
				enemy.combo_silent = false


func _physics_process(delta: float) -> void:
	# En red, los jugadores de los demás se mueven solos por el MultiplayerSynchronizer
	if not is_multiplayer_authority():
		_remote_update()
		return
	if is_dead:
		return
	if net_frozen:
		velocity = Vector2.ZERO
		return
	_protection_timer = maxf(_protection_timer - delta, 0.0)
	_parry_grace_timer = maxf(_parry_grace_timer - delta, 0.0)
	_shield_timer = maxf(_shield_timer - delta, 0.0)
	_justice_timer = maxf(_justice_timer - delta, 0.0)
	_protection_sprite.visible = _protection_timer > 0.0
	net_protected = _protection_timer > 0.0
	if global_position.y > fall_death_y:
		die()
		return
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	if _update_stun(delta):
		return
	_update_melee(delta)
	_handle_drop_input(delta)
	_handle_dash_input()
	_handle_melee_input()
	if _is_dashing:
		_update_dash(delta)
	elif _is_parrying:
		_update_parry(delta)
	else:
		if _knockback_timer > 0.0:
			# Retroceso: durante un instante no se pisa la velocidad horizontal
			_knockback_timer -= delta
		else:
			_handle_horizontal(delta)
		_handle_jump(delta)
		_apply_gravity(delta)
	# Mientras golpea solo puede caminar y saltar
	if not melee_active:
		_handle_ability_input()
		_handle_consumable_input()
		_handle_push_input(delta)
	move_and_slide()
	net_on_floor = is_on_floor()


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


## `from_position`: de dónde viene el golpe (si se indica, el jugador retrocede alejándose de ahí).
## `knockback_scale` multiplica el retroceso (1 = normal; el cangrejo usa más).
## `source`: quién te pegó (si se sabe); la carta Justice le pone sangrado.
func take_damage(amount: float, from_position: Vector2 = Vector2.INF, knockback_scale: float = 1.0, source: Node = null) -> void:
	if not is_multiplayer_authority():
		# Este jugador es de otra PC: el daño lo aplica su dueño
		_net_take_damage.rpc_id(get_multiplayer_authority(), amount)
		return
	if is_dead or net_frozen or _protection_timer > 0.0 or _parry_grace_timer > 0.0:
		return
	if _is_parrying:
		# Parry: el golpe no entra y quien te pegó queda aturdido
		_parry_enemy(source)
		return
	if _is_dashing and dash_invulnerable:
		return
	var dealt := amount
	if from_position != Vector2.INF:
		dealt += incoming_damage_bonus
	health = maxf(health - dealt, 0.0)
	_update_health_bar()
	health_changed.emit(health, max_health)
	_flash()
	_start_hurt(from_position, knockback_scale)
	_apply_justice(from_position, source)
	if source != null and is_instance_valid(source) and source.get("knife_bleed") == true:
		apply_bleed(KNIFE_BLEED_DAMAGE, KNIFE_BLEED_TIME, KNIFE_BLEED_INTERVAL)
	if health <= 0.0:
		die()


## Anota una mejora agarrada (si ya la tenía, suma 1 a su contador).
func register_item(upgrade: Object) -> void:
	for item in collected_items:
		if item["title"] == upgrade.title:
			item["count"] += 1
			return
	collected_items.append({
		"title": upgrade.title,
		"description": upgrade.description,
		"icon_path": upgrade.icon_path,
		"count": 1,
	})


## Cuántas copias de una mejora tiene (0 si no la agarró)
func get_item_count(title: String) -> int:
	for item in collected_items:
		if item["title"] == title:
			return int(item["count"])
	return 0


## Sangrado (cuchillos de los enemigos): daño cada `interval` s durante `duration` s.
func apply_bleed(damage: float, duration: float, interval: float) -> void:
	if is_dead:
		return
	var effect = get_node_or_null("BleedEffect")
	if effect == null:
		var script := load("res://escenas y recursos/weapon/bleed_effect.gd")
		effect = script.new()
		effect.name = "BleedEffect"
		effect.refresh(damage, duration, interval)
		add_child.call_deferred(effect)
	else:
		effect.refresh(damage, duration, interval)


## Parpadeo y retroceso al recibir daño. Además rompe el combo de kills.
func _start_hurt(from_position: Vector2, knockback_scale: float = 1.0) -> void:
	if _combo != null:
		_combo.on_player_hit()
	if from_position != Vector2.INF and not _is_dashing:
		var dir := signf(global_position.x - from_position.x)
		if dir == 0.0:
			dir = 1.0
		velocity = Vector2(dir * knockback_speed * knockback_scale, knockback_up)
		# Un retroceso más fuerte también dura más
		_knockback_timer = knockback_time * lerpf(1.0, maxf(knockback_scale, 1.0), 0.5)
	if hurt_blink_time <= 0.0:
		return
	if _blink_tween != null:
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.tween_interval(0.07)  # después del destello blanco
	var cycles := maxi(roundi(hurt_blink_time / 0.1), 1)
	for i in cycles:
		_blink_tween.tween_property(_visual, "modulate:a", 0.2, 0.05)
		_blink_tween.tween_property(_visual, "modulate:a", 1.0, 0.05)


func _stop_blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
	_visual.modulate.a = 1.0


## Un enemigo murió: suma a tu combo (solo en la PC dueña del jugador).
func register_kill(_enemy: Node = null) -> void:
	if _combo != null and is_multiplayer_authority() and not is_dead:
		# Un kill de la carta The Death cuenta pero no alarga el combo
		_combo.register_kill(not (_enemy != null and "combo_silent" in _enemy and _enemy.combo_silent))


## Golpeaste a un enemigo (sin matarlo necesariamente): alarga el combo.
func register_hit(_enemy: Node = null) -> void:
	if _enemy != null and "combo_silent" in _enemy and _enemy.combo_silent:
		return
	if _combo != null and is_multiplayer_authority() and not is_dead:
		_combo.register_hit()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	_stop_blink()
	_knockback_timer = 0.0
	if _combo != null:
		_combo.break_combo()
	health = 0.0
	velocity = Vector2.ZERO
	# Si llevaba una bandera, la suelta donde murió (en red, las banderas las maneja el host)
	if carried_flag != null:
		carried_flag.drop()
	elif LanNetwork.in_lobby and not multiplayer.is_server():
		_server_drop_flag.rpc_id(1)
	_reset_dash_state()
	_cancel_melee()
	_stun_timer = 0.0
	_shield_timer = 0.0
	_weapon.enabled = true
	_drop_timer = 0.0
	set_collision_mask_value(PLATFORM_LAYER, true)
	_body_shape.set_deferred("disabled", true)
	_visual.hide()
	_health_bar.hide()
	_protection_timer = 0.0
	_protection_sprite.hide()
	net_protected = false
	_weapon.hide()
	if _name_label != null:
		_name_label.hide()
	_weapon.set_process(false)
	_update_health_bar()
	health_changed.emit(health, max_health)
	died.emit()
	if not auto_respawn:
		return
	await get_tree().create_timer(respawn_time).timeout
	respawn()


## Congela o libera al jugador (entre rondas). Al liberarlo tiene unos instantes de protección,
## salvo que se pase give_protection = false (por ejemplo, al cambiar de sala o cerrar la tienda).
func set_net_frozen(value: bool, give_protection: bool = true) -> void:
	net_frozen = value
	_weapon.enabled = not value
	if value:
		velocity = Vector2.ZERO
		_reset_dash_state()
		_cancel_melee()
	elif give_protection:
		_protection_timer = spawn_protection


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
	net_protected = spawn_protection > 0.0
	_weapon.show()
	if _name_label != null:
		_name_label.show()
	_weapon.set_process(true)
	_weapon.reset()
	_update_health_bar()
	is_dead = false
	health_changed.emit(health, max_health)
	respawned.emit()


func _handle_dash_input() -> void:
	if _is_dashing or _is_parrying or _dash_cooldown_timer > 0.0 or melee_active:
		return
	var use_parry := uses_parry()
	if parry_blocked and use_parry:
		return
	if Input.is_action_just_pressed("dash"):
		if use_parry:
			_start_parry()
		else:
			_start_dash()


func _start_dash() -> void:
	# Hacia donde se mueve; si está quieto, hacia donde apunta el mouse
	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0.0:
		direction = 1.0 if get_aim_target().x >= global_position.x else -1.0
	_dash_direction = signf(direction)
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	velocity.y = 0.0
	# Pose de esquive al azar (igual que el parry); sin poses queda solo la estela
	net_dash_variant = randi() % _parry_poses.size() if not _parry_poses.is_empty() else 0
	net_dashing = true
	if not _parry_poses.is_empty():
		_show_parry_pose(_parry_poses[net_dash_variant])
	_ghost_timer = dash_ghost_interval
	_spawn_dash_ghost()
	_play_dash_flash()
	_dash_sfx.play()
	dashed.emit()


func _update_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity.x = _dash_direction * dash_speed
	velocity.y = 0.0
	_tick_dash_ghosts(delta)
	if _dash_timer <= 0.0:
		_is_dashing = false
		net_dashing = false
		_hide_parry_pose()
		# Al terminar conserva algo de impulso, sin salir disparado
		velocity.x = _dash_direction * minf(max_speed, dash_speed)


func _reset_dash_state() -> void:
	_is_dashing = false
	_is_parrying = false
	net_dashing = false
	_hide_parry_pose()
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


# ---------------------------------------------------------------- Parry (un jugador)

func _start_parry() -> void:
	_is_parrying = true
	_parry_timer = parry_duration
	_dash_cooldown_timer = parry_cooldown
	_parry_hits.clear()
	if not _parry_poses.is_empty():
		_show_parry_pose(_parry_poses.pick_random())
	# Sin gravedad mientras dura: se frena en el aire, tanto si estaba saltando como cayendo
	velocity.y = 0.0
	_play_parry_flash()
	_dash_sfx.play()
	_start_hitstop()
	_parry_scan()


## Congela todo el juego un instante (Engine.time_scale = 0). Se descuenta en tiempo REAL desde _process,
## porque con el tiempo del juego frenado los timers normales no avanzan.
func _start_hitstop() -> void:
	if parry_hitstop <= 0.0:
		return
	Engine.time_scale = 0.0
	_hitstop_end_msec = Time.get_ticks_msec() + int(parry_hitstop * 1000.0)


func _process(_delta: float) -> void:
	if _hitstop_end_msec > 0 and Time.get_ticks_msec() >= _hitstop_end_msec:
		_end_hitstop()


func _end_hitstop() -> void:
	_hitstop_end_msec = 0
	Engine.time_scale = 1.0


func _update_parry(delta: float) -> void:
	_parry_timer -= delta
	# Se planta: frena el movimiento horizontal y cancela la gravedad (no se aplica en este estado)
	velocity.x = move_toward(velocity.x, 0.0, 4000.0 * delta)
	velocity.y = 0.0
	_parry_scan()
	if _parry_timer <= 0.0:
		_is_parrying = false
		net_dashing = false
		_hide_parry_pose()


## Oculta todos los sprites del personaje (cuerpo, arma...) y muestra una sola imagen de pose.
## Sigue el giro del personaje porque va dentro de Visuals.
func _show_parry_pose(texture: Texture2D) -> void:
	if _parry_pose_sprite == null:
		_parry_pose_sprite = Sprite2D.new()
		_parry_pose_sprite.name = "PoseParry"
		_parry_pose_sprite.use_parent_material = true
		_visual.add_child(_parry_pose_sprite)
	_parry_hidden.clear()
	for child in _visual.get_children():
		if child is CanvasItem and child != _parry_pose_sprite and child.visible:
			_parry_hidden.append(child)
			child.visible = false
	_parry_pose_sprite.texture = texture
	_parry_pose_sprite.scale = parry_pose_scale
	# Apoyada en los pies: cada pose puede medir distinto y siempre queda a la misma altura del piso
	_parry_pose_sprite.position = Vector2(0.0, parry_pose_feet_y - texture.get_height() * parry_pose_scale.y * 0.5) \
			+ parry_pose_offset
	_parry_pose_sprite.visible = true
	# El arma también se oculta (aunque no esté dentro de Visuals)
	if _weapon.visible and not _parry_hidden.has(_weapon):
		_parry_hidden.append(_weapon)
		_weapon.visible = false
	# Con el arma oculta tampoco se dispara
	_weapon.enabled = false


## Vuelve a mostrar el personaje normal (no hace nada si no había una pose puesta)
func _hide_parry_pose() -> void:
	if _parry_pose_sprite == null or not _parry_pose_sprite.visible:
		return
	_parry_pose_sprite.visible = false
	for item in _parry_hidden:
		if is_instance_valid(item):
			item.visible = true
	_parry_hidden.clear()
	# En una copia de red el arma queda siempre apagada (la maneja su dueño)
	if is_multiplayer_authority():
		_weapon.enabled = not net_frozen and not is_dead


## Frena a los enemigos y devuelve los proyectiles que estén dentro del alcance del parry
func _parry_scan() -> void:
	var center := global_position + Vector2(0.0, -40.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and center.distance_to(enemy.global_position + Vector2(0.0, -30.0)) <= parry_radius:
			_parry_enemy(enemy)
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(projectile) and center.distance_to(projectile.global_position) <= parry_radius * 1.3 \
				and not _parry_hits.has(projectile) and projectile.has_method("deflect"):
			_parry_hits[projectile] = true
			projectile.deflect()
			_parry_success()


## Aturde y empuja a un enemigo (una vez por parry). Si `enemy` es null solo se bloquea el golpe.
func _parry_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or _parry_hits.has(enemy):
		return
	if "dead" in enemy and enemy.dead:
		return
	_parry_hits[enemy] = true
	if enemy.has_method("apply_stun"):
		var dir := signf(enemy.global_position.x - global_position.x)
		if dir == 0.0:
			dir = _facing_sign()
		enemy.apply_stun(parry_stun_time, Vector2(dir * parry_knockback, -parry_knockback * 0.35))
	_parry_success()


## Parry acertado: protección extra, el parry se puede repetir enseguida y el combo se renueva
func _parry_success() -> void:
	_parry_grace_timer = maxf(_parry_grace_timer, parry_success_protection)
	_dash_cooldown_timer = minf(_dash_cooldown_timer, parry_success_cooldown)
	if _combo != null:
		_combo.register_hit()
	_play_parry_flash()
	parried.emit()


func _facing_sign() -> float:
	return 1.0 if get_aim_target().x >= global_position.x else -1.0


## Destello de color mientras dura la ventana del parry
func _play_parry_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_material.set_shader_parameter("flash_color", parry_flash_color)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, 0.0, dash_flash_strength, dash_flash_fade_in)
	_flash_tween.tween_interval(maxf(parry_duration - dash_flash_fade_in, 0.0))
	_flash_tween.tween_method(_set_flash_amount, dash_flash_strength, 0.0, dash_flash_fade_out)
	_flash_tween.tween_callback(func() -> void:
		_flash_material.set_shader_parameter("flash_color", dash_flash_color))


func _set_flash_amount(value: float) -> void:
	_flash_material.set_shader_parameter("amount", value)


## Cada `dash_ghost_interval` segundos deja una copia mientras dura el esquive.
func _tick_dash_ghosts(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = dash_ghost_interval
		_spawn_dash_ghost()


## Copia los sprites del personaje en su pose actual y los desvanece.
## Solo copia los Sprite2D (no el arma como nodo), así no se duplican scripts.
func _spawn_dash_ghost() -> void:
	if not dash_ghosts_enabled:
		return
	var parent := get_parent()
	if parent == null:
		return
	var ghost := Node2D.new()
	ghost.modulate = dash_ghost_color
	# Justo antes del jugador en el árbol: se dibuja detrás de él pero delante del escenario
	parent.add_child(ghost)
	parent.move_child(ghost, get_index())
	ghost.global_transform = Transform2D.IDENTITY
	ghost.z_index = z_index
	for sprite: Sprite2D in _visual.find_children("*", "Sprite2D", true, false):
		if sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var copy := Sprite2D.new()
		copy.texture = sprite.texture
		copy.hframes = sprite.hframes
		copy.vframes = sprite.vframes
		copy.frame = sprite.frame
		copy.centered = sprite.centered
		copy.offset = sprite.offset
		copy.flip_h = sprite.flip_h
		copy.flip_v = sprite.flip_v
		copy.region_enabled = sprite.region_enabled
		copy.region_rect = sprite.region_rect
		copy.self_modulate = sprite.self_modulate
		ghost.add_child(copy)
		copy.global_transform = sprite.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, dash_ghost_fade_time)
	tween.tween_callback(ghost.queue_free)


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


# ---------------------------------------------------------------- Melee (clic derecho)

func _create_melee() -> void:
	_melee_area = Area2D.new()
	_melee_area.collision_layer = 0
	_melee_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = melee_hitbox_size
	shape.shape = rect
	_melee_area.add_child(shape)
	add_child(_melee_area)
	# Tajo blanco (placeholder visual)
	_melee_fx = Node2D.new()
	_melee_fx.z_index = 5
	_melee_fx.visible = false
	var radius := melee_hitbox_offset.x + melee_hitbox_size.x * 0.5
	var color := melee_fx_color
	_melee_fx.draw.connect(func() -> void:
		_melee_fx.draw_arc(Vector2.ZERO, radius, -0.8, 0.8, 16, color, 6.0))
	add_child(_melee_fx)


func _handle_melee_input() -> void:
	if melee_active or _is_dashing or _is_parrying or _melee_cooldown_timer > 0.0:
		return
	if Input.is_action_just_pressed("melee"):
		_start_melee()


func _start_melee() -> void:
	melee_active = true
	_melee_time = 0.0
	_melee_cooldown_timer = melee_cooldown
	_melee_hit.clear()
	# Pega hacia donde apunta el mouse
	var side := get_aim_target().x - global_position.x
	melee_dir = 1.0 if side >= 0.0 else -1.0
	_weapon.enabled = false
	_melee_area.position = Vector2(melee_hitbox_offset.x * melee_dir, melee_hitbox_offset.y)
	_play_melee_fx()


func _update_melee(delta: float) -> void:
	_melee_cooldown_timer = maxf(_melee_cooldown_timer - delta, 0.0)
	if not melee_active:
		return
	_melee_time += delta
	if _melee_time >= melee_hit_start and _melee_time <= melee_hit_end:
		_melee_hit_check()
	if _melee_time >= melee_duration:
		melee_active = false
		_melee_fx.visible = false


## Daña a los enemigos que estén dentro de la zona del golpe (una vez por golpe cada uno)
func _melee_hit_check() -> void:
	for body in _melee_area.get_overlapping_bodies():
		if body == self or _melee_hit.has(body) or not body.is_in_group("enemies"):
			continue
		if body.has_method("take_damage"):
			_melee_hit[body] = true
			body.take_damage(melee_damage)


func _cancel_melee() -> void:
	melee_active = false
	if _melee_fx != null:
		_melee_fx.visible = false


func _play_melee_fx() -> void:
	if _melee_tween != null:
		_melee_tween.kill()
	_melee_fx.visible = true
	_melee_fx.scale = Vector2(melee_dir, 1.0)
	_melee_fx.position = Vector2(0.0, melee_hitbox_offset.y)
	_melee_fx.modulate.a = 1.0
	_melee_fx.rotation = -0.6 * melee_dir
	_melee_tween = create_tween().set_parallel(true)
	_melee_tween.tween_property(_melee_fx, "rotation", 0.6 * melee_dir, melee_duration)
	_melee_tween.tween_property(_melee_fx, "modulate:a", 0.0, melee_duration)


# ---------------------------------------------------------------- Consumibles (bolsillo, Q)

func _handle_consumable_input() -> void:
	if pocket == null:
		return
	if Input.is_action_just_pressed("consumable"):
		use_consumable()
	elif Input.is_action_just_pressed("drop_consumable") and is_on_floor() and absf(velocity.x) < 10.0 and not LanNetwork.in_lobby:
		# Quieto + Control: tira el consumible del bolsillo al piso (sin usarlo)
		_drop_pocket(Vector2(_aim_side() * 60.0, -160.0))
		pocket_changed.emit(null)


## true si el bolsillo está libre para guardar un consumible.
func can_take_consumable() -> bool:
	return pocket == null and not is_dead


## true si puede agarrar un consumible del suelo. Sin red, con el bolsillo ocupado también puede
## (suelta el que tiene y se lleva el nuevo). En red (LAN) solo con el bolsillo libre.
func can_pickup_consumable() -> bool:
	if is_dead:
		return false
	return pocket == null or not LanNetwork.in_lobby


## Guarda el consumible en el bolsillo (sale del mapa). Devuelve false si no pudo.
## Con `swap` = true y el bolsillo ocupado, suelta antes el que tenía en el mapa.
func add_to_pocket(item: Consumable, swap: bool = false) -> bool:
	if pocket != null and swap and not is_dead:
		_drop_pocket()
	if not can_take_consumable():
		return false
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	pocket = item
	pocket_changed.emit(item)
	return true


## Suelta en el mapa el consumible del bolsillo (sale despedido hacia un costado)
## `toss` = impulso con el que sale (por defecto, hacia un costado al azar)
func _drop_pocket(toss: Vector2 = Vector2.INF) -> void:
	var old := pocket
	pocket = null
	if old == null or not is_instance_valid(old):
		return
	if toss == Vector2.INF:
		toss = Vector2((-1.0 if randf() < 0.5 else 1.0) * 140.0, -280.0)
	old.drop(get_parent(), global_position + Vector2(0.0, -30.0), toss)


## Punto al que apunta: el mouse o, si usa las flechas, un punto en esa dirección
func get_aim_target() -> Vector2:
	return _weapon.get_aim_target()


## Hacia dónde mira el jugador (1 derecha, -1 izquierda), según el mouse o las flechas
func _aim_side() -> float:
	return 1.0 if get_aim_target().x >= global_position.x else -1.0


## Usa el consumible del bolsillo (tecla Q): aplica su efecto y deja el bolsillo libre.
func use_consumable() -> void:
	if pocket == null or is_dead or net_frozen:
		return
	var item := pocket
	pocket = null
	pocket_changed.emit(null)
	item.use(self)


## Invencible (con el sprite de protección) por `duration` segundos, pudiendo seguir disparando.
## A diferencia de start_shield(), no impide atacar.
func grant_invincibility(duration: float) -> void:
	_protection_timer = maxf(_protection_timer, duration)


# ---------------------------------------------------------------- Efectos de cartas

## Justice: durante `duration` segundos, los enemigos que te dañen reciben sangrado.
func grant_justice(duration: float) -> void:
	_justice_timer = maxf(_justice_timer, duration)


## Si Justice está activa, le pone sangrado a quien te pegó. Si no se sabe quién fue (proyectiles),
## busca el enemigo más cercano al punto del golpe.
func _apply_justice(from_position: Vector2, source: Node) -> void:
	if _justice_timer <= 0.0:
		return
	var attacker: Node = source
	if attacker == null or not is_instance_valid(attacker):
		attacker = null
		var best := JUSTICE_SEARCH_RADIUS
		var origin := global_position if from_position == Vector2.INF else from_position
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var distance: float = origin.distance_to(enemy.global_position)
			if distance < best:
				best = distance
				attacker = enemy
	if attacker != null and attacker.has_method("apply_bleed"):
		attacker.apply_bleed(JUSTICE_BLEED_DAMAGE, JUSTICE_BLEED_TIME, JUSTICE_BLEED_INTERVAL)


## The Magician: acorta `seconds` segundos la recarga de la habilidad especial y del golpe melee.
func reduce_cooldowns(seconds: float) -> void:
	if _ability != null and is_instance_valid(_ability) and _ability.has_method("reduce_cooldown"):
		_ability.reduce_cooldown(seconds)
	_melee_cooldown_timer = maxf(_melee_cooldown_timer - seconds, 0.0)


## Strength: escala del jugador (el valor se pasa tal cual: 1.0 pequeño, 2.0 el tamaño normal del juego).
func set_body_scale(factor: float) -> void:
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween().set_parallel(true)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * factor, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Punto a un costado del jugador (side = -1 izquierda, 1 derecha). Lo usa The Tower para poner los tanques.
func side_position(side: float, distance: float = 70.0) -> Vector2:
	return global_position + Vector2(side * distance, -10.0)


func _exit_tree() -> void:
	# Si la escena cambia en pleno congelado del parry, el juego no puede quedar frenado
	if _hitstop_end_msec > 0:
		_end_hitstop()
	# Un consumible guardado está fuera del árbol: hay que liberarlo a mano
	if pocket != null and is_instance_valid(pocket) and not pocket.is_inside_tree():
		pocket.free()
	pocket = null


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


## Crea la pasiva del personaje (si tiene) como nodo hijo "Passive".
func _setup_passive() -> void:
	if _character_data == null or _character_data.passive_script == null:
		return
	_passive = Node.new()
	_passive.name = "Passive"
	_passive.set_script(_character_data.passive_script)
	add_child(_passive)


## La pasiva del personaje (null si no tiene).
func get_passive() -> Node:
	return _passive


## Escudo: invencible (con el sprite de protección) pero sin poder disparar durante `duration` s.
func start_shield(duration: float) -> void:
	_shield_timer = duration
	_protection_timer = maxf(_protection_timer, duration)


func is_shielded() -> bool:
	return _shield_timer > 0.0


## Cura vida (sin pasar del máximo). Lo usan las mejoras de robo de vida.
func heal(amount: float) -> void:
	if is_dead or amount <= 0.0 or not is_multiplayer_authority():
		return
	health = minf(health + amount, max_health)
	_update_health_bar()
	health_changed.emit(health, max_health)


## Carga los stats base del personaje elegido (variable `character`).
func _load_character() -> void:
	if not character_assigned and LanNetwork.in_lobby:
		character = LanNetwork.character_of(multiplayer.get_unique_id())
	var path := "%s/%s/%s_stats.gd" % [characters_folder, character, character]
	if not ResourceLoader.exists(path):
		push_warning("Player: no encontré el personaje '%s' (%s). Revisá character y characters_folder." % [character, path])
		return
	_character_data = load(path).new()
	_character_data.apply(self, _weapon.stats)
	_parry_poses = _character_data.load_parry_poses()
	_apply_character_look(_character_data)
	if _protection_sprite != null:
		_protection_sprite.texture = protection_texture
		_protection_sprite.scale = protection_scale
		_protection_sprite.position = protection_offset
		_protection_sprite.modulate.a = protection_alpha
	


## Aspecto del arma y la bala del personaje.
func _apply_character_look(data: RefCounted) -> void:
	_look_character = character
	_weapon.set_look(data.bullet_scene, data.weapon_look)


## Copia de red: llegó el personaje real del dueño, se le pone su arma y su bala.
func _refresh_remote_look() -> void:
	_look_character = character
	var path := "%s/%s/%s_stats.gd" % [characters_folder, character, character]
	if ResourceLoader.exists(path):
		var data = load(path).new()
		_apply_character_look(data)
		_parry_poses = data.load_parry_poses()


## Datos del personaje elegido (character_stats.gd), o null
func get_character_data() -> RefCounted:
	return _character_data


## Mejoras propias del personaje (<nombre>_pool.gd). La pide el RoundManager.
func get_character_upgrades() -> Array:
	var path := "%s/%s/%s_pool.gd" % [characters_folder, character, character]
	if not ResourceLoader.exists(path):
		return []
	return load(path).new().create_upgrades()


## Aturde al jugador: no puede moverse, disparar, esquivar ni usar la E.
func stun(duration: float) -> void:
	if not is_multiplayer_authority():
		_net_stun.rpc_id(get_multiplayer_authority(), duration)
		return
	if is_dead or net_frozen or _protection_timer > 0.0:
		return
	if (_is_dashing and dash_invulnerable) or _is_parrying:
		return
	_reset_dash_state()
	_cancel_melee()
	if _stun_timer <= 0.0:
		_float_stun_text()
	_stun_timer = maxf(_stun_timer, duration)


func is_stunned() -> bool:
	return _stun_timer > 0.0


## Avanza el aturdimiento. Devuelve true si está aturdido (se saltea el control).
func _update_stun(delta: float) -> bool:
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	var stunned := _stun_timer > 0.0
	_weapon.enabled = not stunned and _shield_timer <= 0.0 and not melee_active and not _is_parrying
	if not stunned:
		return false
	if _knockback_timer > 0.0:
		# Si lo empujaron (por ejemplo, embestida del cangrejo) el retroceso sigue su curso
		_knockback_timer -= delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	_apply_gravity(delta)
	move_and_slide()
	return true


## Texto "¡ATURDIDO!": mismo estilo y animación que los textos flotantes de la tienda
## (sube y se desvanece). Va en la escena, no en el jugador, para que no se voltee con él.
func _float_stun_text() -> void:
	var label := Label.new()
	label.text = "¡ATURDIDO!"
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", STUN_TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	get_tree().current_scene.add_child(label)
	label.reset_size()
	label.global_position = global_position + Vector2(0.0, -70.0) - label.size * 0.5
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - STUN_TEXT_RISE, STUN_TEXT_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, STUN_TEXT_TIME * 0.6).set_delay(STUN_TEXT_TIME * 0.4)
	tween.chain().tween_callback(label.queue_free)


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


## Pierde `amount` de vida (sin matar: nunca baja de 1). Lo usa The Devil.
func lose_health(amount: float) -> void:
	if is_dead or amount <= 0.0 or not is_multiplayer_authority():
		return
	health = maxf(health - amount, 1.0)
	_update_health_bar()
	health_changed.emit(health, max_health)
	_flash()


## El WaveDirector avisa que va a aparecer algún enemigo (true) o ya no queda ninguno por aparecer (false):
## mientras tanto la barra de tiempo del combo no baja.
func set_combo_spawn_hold(value: bool) -> void:
	if _combo != null and is_multiplayer_authority():
		_combo.spawn_hold = value


## El WaveDirector avisa que apareció un enemigo (entra a la lista del full combo).
func register_fc_spawn() -> void:
	if _combo != null and is_multiplayer_authority():
		_combo.register_fc_spawn()


## El WaveDirector avisa que empieza la run con el total de enemigos de todas las fases y oleadas.
func combo_run_started(total_enemies: int) -> void:
	if _combo != null and is_multiplayer_authority():
		_combo.begin_run(total_enemies)


## El WaveDirector avisa que empieza una fase (el full combo sigue de la anterior).
func combo_phase_started() -> void:
	if _combo != null and is_multiplayer_authority():
		_combo.begin_phase()


## El WaveDirector avisa que se mataron todos los enemigos de una oleada.
func combo_wave_cleared(is_phase_end: bool) -> void:
	if _combo != null and is_multiplayer_authority():
		_combo.wave_cleared(is_phase_end)


## El combo de kills del jugador (null si no tiene)
func get_combo() -> ComboTracker:
	return _combo


## La habilidad especial (E) o null si no tiene
func get_ability() -> Node:
	return _ability


## 0 = golpe melee listo, 1 = recién usado (para el HUD)
func get_melee_cooldown_ratio() -> float:
	if melee_cooldown <= 0.0:
		return 0.0
	return clampf(_melee_cooldown_timer / melee_cooldown, 0.0, 1.0)


## true si Shift hace parry (elegido en el inspector y solo en un jugador); si no, hace dash
func uses_parry() -> bool:
	return shift_ability == 1 and not LanNetwork.in_lobby


## 0 = parry listo, 1 = recién usado (para el HUD; solo si Shift es parry)
func get_parry_cooldown_ratio() -> float:
	if parry_blocked:
		return 1.0
	if parry_cooldown <= 0.0:
		return 0.0
	return clampf(_dash_cooldown_timer / parry_cooldown, 0.0, 1.0)


## Suma (o resta, con un número negativo) puntos. Nunca baja de 0.
func add_points(amount: int) -> void:
	points = maxi(points + amount, 0)
	points_changed.emit(points)


## Gasta puntos. Devuelve false (sin gastar nada) si no alcanzan.
func spend_points(amount: int) -> bool:
	if amount > points:
		return false
	points -= amount
	points_changed.emit(points)
	return true


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


# ---------------------------------------------------------------- Red (LAN)
# Cada jugador es "dueño" de su personaje (autoridad = su peer id): él simula el movimiento,
# la vida y la muerte, y las otras PCs reciben posición, velocidad y vida.

## La llama GameSession al empezar la partida, con la autoridad ya asignada.
func setup_network() -> void:
	var is_local := is_multiplayer_authority()
	_camera.enabled = is_local
	if is_local:
		_camera.make_current()
	else:
		# El arma de un jugador remoto no debe seguir el mouse ni disparar con tus clics
		_weapon.enabled = false
		_weapon.set_process(false)
		_weapon.set_physics_process(false)
		_weapon.set_process_input(false)
		_weapon.set_process_unhandled_input(false)
	if get_node_or_null("NetSync") != null:
		return
	var config := SceneReplicationConfig.new()
	# Posición, velocidad, hacia dónde mira (Visuals) y cómo apunta el arma
	for prop in [":position", ":velocity", "Visuals:scale", "Visuals/Weapon:rotation"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in [":health", ":max_health", ":is_dead", ":net_on_floor", ":net_protected", ":net_dash_variant", ":net_dashing", ":character", ":modulate", "Visuals:modulate"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config
	sync.set_multiplayer_authority(get_multiplayer_authority())
	add_child(sync)


## Nombre que se ve sobre el jugador.
func set_display_name(display_name: String) -> void:
	if _name_label == null:
		_name_label = Label.new()
		_name_label.add_theme_font_size_override("font_size", 12)
		_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_name_label.add_theme_constant_override("outline_size", 4)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.custom_minimum_size = Vector2(120, 0)
		_name_label.position = Vector2(-60, -74)
		_name_label.z_index = 10
		add_child(_name_label)
	_name_label.text = display_name
	_name_label.modulate = Color(1.0, 0.55, 0.55) if team == 0 else Color(0.55, 0.7, 1.0)


## Jugador de otra PC: actualiza la barra de vida y muestra/oculta según esté muerto.
func _remote_update() -> void:
	_update_health_bar()
	if character != _look_character:
		_refresh_remote_look()
	_protection_sprite.visible = net_protected and not is_dead
	# La estela del esquive de otro jugador también se ve en esta PC
	if net_dashing and not is_dead:
		_tick_dash_ghosts(get_physics_process_delta_time())
	_update_remote_dash_pose()
	if is_dead == _remote_dead_applied:
		return
	_remote_dead_applied = is_dead
	_visual.visible = not is_dead
	_health_bar.visible = not is_dead
	if _name_label != null:
		_name_label.visible = not is_dead
	_body_shape.set_deferred("disabled", is_dead)


## Copia de red: muestra la pose de esquive que eligió el dueño mientras dura, y la saca al terminar.
func _update_remote_dash_pose() -> void:
	var wanted := -1
	if net_dashing and not is_dead and not _parry_poses.is_empty():
		wanted = clampi(net_dash_variant, 0, _parry_poses.size() - 1)
	if wanted == _remote_pose_shown:
		return
	_remote_pose_shown = wanted
	if wanted >= 0:
		_show_parry_pose(_parry_poses[wanted])
	else:
		_hide_parry_pose()


@rpc("any_peer", "call_remote", "reliable")
func _net_take_damage(amount: float) -> void:
	if is_multiplayer_authority():
		take_damage(amount)


@rpc("any_peer", "call_remote", "reliable")
func _net_stun(duration: float) -> void:
	if is_multiplayer_authority():
		stun(duration)


## Otro jugador te envenenó: el veneno corre en tu PC (ahí te ponés verde y recibís el daño).
@rpc("any_peer", "call_remote", "reliable")
func net_apply_poison(damage: float, duration: float, interval: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	var effect = get_node_or_null("PoisonEffect")
	if effect == null:
		var script := load("res://escenas y recursos/weapon/poison_effect.gd")
		effect = script.new()
		effect.name = "PoisonEffect"
		effect.refresh(damage, duration, interval)
		add_child.call_deferred(effect)
	else:
		effect.refresh(damage, duration, interval)


## El dueño murió llevando una bandera: le pide al host que la suelte.
@rpc("any_peer", "call_remote", "reliable")
func _server_drop_flag() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if carried_flag != null:
		carried_flag.drop()


## Crea las acciones de input por código si no existen en el Mapa de Entrada,
## así el script funciona sin configurar nada en Project Settings.
func _ensure_input_actions() -> void:
	_add_action("move_left", [KEY_A])
	_add_action("move_right", [KEY_D])
	_add_action("jump", [KEY_SPACE, KEY_W])
	_add_action("dash", [KEY_SHIFT])
	_add_action("ability", [KEY_E])
	_add_action("consumable", [KEY_Q])
	_add_action("drop_consumable", [KEY_CTRL])
	_add_action("move_down", [KEY_S])
	_add_action("push", [KEY_F])
	_add_action("interact", [KEY_F])
	if not InputMap.has_action("melee"):
		InputMap.add_action("melee")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("melee", click)


func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
