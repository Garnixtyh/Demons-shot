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
## false = el arma no responde (por ejemplo, jugador aturdido)
var enabled: bool = true
## Dirección global hacia el mouse (la usan las balas)
var aim_direction: Vector2 = Vector2.RIGHT
var _cooldown: float = 0.0
var _reloading: bool = false
var _base_muzzle_position: Vector2
var _shotgun_visual: ColorRect


func _ready() -> void:
	_ensure_input_actions()
	if stats == null:
		stats = WeaponStats.new()
	else:
		# Copia propia, para que las mejoras no afecten a otros jugadores
		stats = stats.duplicate()
	ammo = stats.magazine_size
	_base_muzzle_position = muzzle.position
	refresh_visuals()


func _process(delta: float) -> void:
	_aim_at_mouse()
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not enabled:
		return

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
	refresh_visuals()
	ammo_changed.emit(ammo, stats.magazine_size)


## Dispara todas las balas del disparo (1, 3, un abanico de perdigones...).
func _spawn_bullet() -> void:
	var shooter := _find_shooter()
	var count := maxi(stats.bullets_per_shot, 1)
	for i in count:
		# Con varias balas se reparten en abanico, centradas en la puntería
		var fan_offset := (i - (count - 1) / 2.0) * stats.fan_angle_degrees
		var jitter := randf_range(-stats.spread_degrees, stats.spread_degrees)
		_spawn_one_bullet(shooter, deg_to_rad(fan_offset + jitter))


func _spawn_one_bullet(shooter: Node, angle_offset: float) -> void:
	var bullet := bullet_scene.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = aim_direction.angle() + angle_offset
	bullet.scale = Vector2.ONE * stats.bullet_scale
	bullet.damage = stats.damage
	bullet.speed = stats.bullet_speed
	bullet.lifetime = stats.bullet_lifetime
	bullet.shooter = shooter
	if stats.poison_ratio > 0.0:
		bullet.poison_damage = stats.damage * stats.poison_ratio
		bullet.poison_duration = stats.poison_duration
		bullet.poison_interval = stats.poison_interval
	if stats.explosive_bullets:
		bullet.explosion_radius = stats.explosion_radius
		bullet.explosion_damage = stats.damage * stats.explosion_damage_ratio


## El dueño del arma: el primer ancestro del grupo "players" (las balas no lo dañan).
func _find_shooter() -> Node:
	var node := get_parent()
	while node != null and not node.is_in_group("players"):
		node = node.get_parent()
	return node if node != null else get_parent()


## Muestra el dibujo que corresponde al arma actual (stats.weapon_style).
## La escopeta es un placeholder (rectángulo): se puede cambiar por un sprite.
func refresh_visuals() -> void:
	var is_shotgun := stats.weapon_style == &"escopeta"
	if is_shotgun and _shotgun_visual == null:
		_shotgun_visual = ColorRect.new()
		_shotgun_visual.color = Color(0.4, 0.25, 0.12)
		_shotgun_visual.position = Vector2(2, -11)
		_shotgun_visual.size = Vector2(44, 6)
		add_child(_shotgun_visual)
		move_child(_shotgun_visual, 0)  # detrás de la mano
	if _shotgun_visual != null:
		_shotgun_visual.visible = is_shotgun
	muzzle.position = _base_muzzle_position + (Vector2(24, 0) if is_shotgun else Vector2.ZERO)


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
