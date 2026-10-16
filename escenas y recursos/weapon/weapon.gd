class_name Weapon
extends Node2D
## Arma que apunta al mouse. Click izquierdo dispara, R recarga.

signal ammo_changed(current: int, maximum: int)
signal reload_started
signal fired

@export var stats: WeaponStats
@export var bullet_scene: PackedScene

@onready var muzzle: Marker2D = $Muzzle

var ammo: int = 0
## Dirección global hacia el mouse (la usan las balas)
var aim_direction: Vector2 = Vector2.RIGHT
var _cooldown: float = 0.0
var _reloading: bool = false


func _ready() -> void:
	_ensure_input_actions()
	if stats == null:
		stats = WeaponStats.new()
	else:
		# Copia propia, para que las mejoras no afecten a otros jugadores
		stats = stats.duplicate()
	ammo = stats.magazine_size


func _process(delta: float) -> void:
	_aim_at_mouse()
	_cooldown = maxf(_cooldown - delta, 0.0)

	if Input.is_action_just_pressed("reload"):
		reload()

	var wants_to_fire := Input.is_action_pressed("shoot") if stats.automatic \
			else Input.is_action_just_pressed("shoot")
	if wants_to_fire:
		try_fire()


func try_fire() -> void:
	if _reloading or _cooldown > 0.0:
		return
	if ammo <= 0:
		reload()
		return
	ammo -= 1
	_cooldown = 1.0 / stats.fire_rate
	_spawn_bullet()
	fired.emit()
	ammo_changed.emit(ammo, stats.magazine_size)
	if ammo == 0:
		reload()


func reload() -> void:
	if _reloading or ammo == stats.magazine_size:
		return
	_reloading = true
	reload_started.emit()
	await get_tree().create_timer(stats.reload_time).timeout
	ammo = stats.magazine_size
	_reloading = false
	ammo_changed.emit(ammo, stats.magazine_size)


## Apunta al mouse. Funciona aunque el arma esté dentro de un nodo dado vuelta
## (scale.x = -1) o rotado: la dirección global se convierte a la local del padre.
func _aim_at_mouse() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 4.0:
		return
	aim_direction = to_mouse.normalized()
	var parent := get_parent() as Node2D
	if parent == null:
		rotation = aim_direction.angle()
		return
	var local_direction := parent.global_transform.affine_inverse().basis_xform(aim_direction)
	rotation = local_direction.angle()


## Deja el arma lista de nuevo (al reaparecer).
func reset() -> void:
	ammo = stats.magazine_size
	_cooldown = 0.0
	_reloading = false
	ammo_changed.emit(ammo, stats.magazine_size)


func _spawn_bullet() -> void:
	var bullet := bullet_scene.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = aim_direction.angle() \
			+ deg_to_rad(randf_range(-stats.spread_degrees, stats.spread_degrees))
	bullet.damage = stats.damage
	bullet.speed = stats.bullet_speed
	bullet.lifetime = stats.bullet_lifetime
	bullet.shooter = get_parent()


## Crea las acciones de input por código si no existen.
func _ensure_input_actions() -> void:
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", click)
	if not InputMap.has_action("reload"):
		InputMap.add_action("reload")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		InputMap.action_add_event("reload", key)
