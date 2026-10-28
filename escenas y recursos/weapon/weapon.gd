class_name Weapon
extends Node2D
## Arma que apunta al mouse. Click izquierdo dispara, R recarga.

signal ammo_changed(current: int, maximum: int)
signal reload_started
signal fired

@export var stats: WeaponStats
@export var bullet_scene: PackedScene

@export_group("Escopeta (mejora)")
## Sprite que reemplaza al del arma cuando se elige la mejora Escopeta
## (placeholder: icon.svg; cambialo por tu sprite)
@export var shotgun_texture: Texture2D = preload("res://icon.svg")
@export var shotgun_scale: Vector2 = Vector2(0.35, 0.35)
## Posición del sprite de la escopeta dentro del arma
@export var shotgun_position: Vector2 = Vector2(22, -8)
@export var shotgun_rotation_degrees: float = 0.0
## Cuánto se adelanta la boca del arma con la escopeta
@export var shotgun_muzzle_offset: Vector2 = Vector2(24, 0)

@export_group("Icono de recarga")
## Sprite que gira sobre el jugador mientras recarga (placeholder: icon.svg; cambialo por el tuyo)
@export var reload_icon_texture: Texture2D = preload("res://icon.svg")
@export var reload_icon_scale: Vector2 = Vector2(0.12, 0.12)
## Posición respecto del jugador (hacia arriba = y negativo)
@export var reload_icon_offset: Vector2 = Vector2(0, -105)
## Vueltas por segundo
@export var reload_icon_turns_per_second: float = 1.5

@onready var muzzle: Marker2D = $Muzzle

var ammo: int = 0
## false = el arma no responde (por ejemplo, jugador aturdido)
var enabled: bool = true
## Dirección global hacia el mouse (la usan las balas)
var aim_direction: Vector2 = Vector2.RIGHT
var _cooldown: float = 0.0
var _reload_icon: Sprite2D
var _reloading: bool = false
var _base_muzzle_position: Vector2
## Sprite2D del arma (el de la mano/revólver) y cómo estaba originalmente
var _sprite: Sprite2D
var _base_texture: Texture2D
var _base_sprite_scale: Vector2
var _base_sprite_position: Vector2
var _base_sprite_rotation: float


func _ready() -> void:
	_ensure_input_actions()
	if stats == null:
		stats = WeaponStats.new()
	else:
		# Copia propia, para que las mejoras no afecten a otros jugadores
		stats = stats.duplicate()
	ammo = stats.magazine_size
	_base_muzzle_position = muzzle.position
	var sprites := find_children("*", "Sprite2D", false, false)
	if not sprites.is_empty():
		_sprite = sprites[0] as Sprite2D
		_base_texture = _sprite.texture
		_base_sprite_scale = _sprite.scale
		_base_sprite_position = _sprite.position
		_base_sprite_rotation = _sprite.rotation
	refresh_visuals()


func _process(delta: float) -> void:
	_aim_at_mouse()
	_update_reload_icon(delta)
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
	ammo = 0 if stats.empties_magazine else ammo - 1
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
	_show_reload_icon()
	await get_tree().create_timer(stats.reload_time).timeout
	_hide_reload_icon()
	ammo = stats.magazine_size
	_reloading = false
	ammo_changed.emit(ammo, stats.magazine_size)


## Sprite que gira sobre el jugador mientras dura la recarga.
func _show_reload_icon() -> void:
	_hide_reload_icon()
	var owner_node := _find_shooter() as Node2D
	if owner_node == null or reload_icon_texture == null:
		return
	_reload_icon = Sprite2D.new()
	_reload_icon.texture = reload_icon_texture
	_reload_icon.scale = reload_icon_scale
	_reload_icon.position = reload_icon_offset
	_reload_icon.z_index = 20
	owner_node.add_child(_reload_icon)


func _hide_reload_icon() -> void:
	if is_instance_valid(_reload_icon):
		_reload_icon.queue_free()
	_reload_icon = null


func _update_reload_icon(delta: float) -> void:
	if not is_instance_valid(_reload_icon):
		return
	var shooter := _find_shooter()
	if shooter != null and "is_dead" in shooter and shooter.is_dead:
		_hide_reload_icon()
		return
	_reload_icon.rotation += TAU * reload_icon_turns_per_second * delta


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
	_hide_reload_icon()
	refresh_visuals()
	ammo_changed.emit(ammo, stats.magazine_size)


## Dispara todas las balas del disparo (1, 3, un abanico de perdigones...).
func _spawn_bullet() -> void:
	var shooter := _find_shooter()
	var count := maxi(stats.bullets_per_shot, 1)
	var angles := PackedFloat32Array()
	for i in count:
		# Con varias balas se reparten en abanico, centradas en la puntería
		var fan_offset := (i - (count - 1) / 2.0) * stats.fan_angle_degrees
		var jitter := randf_range(-stats.spread_degrees, stats.spread_degrees)
		var angle_offset := deg_to_rad(fan_offset + jitter)
		_spawn_one_bullet(shooter, angle_offset)
		angles.append(aim_direction.angle() + angle_offset)
	# En red: las otras PCs dibujan las mismas balas (sin daño; el daño lo hace la PC de quien dispara)
	if LanNetwork.in_lobby:
		_net_fired.rpc(muzzle.global_position, angles, stats.bullet_scale, stats.bullet_speed, stats.bullet_lifetime,
				stats.explosion_radius if stats.explosive_bullets else 0.0)


## Otra PC disparó: muestra sus balas. No dañan (el daño lo hace la PC de quien dispara): solo se ven y desaparecen al chocar.
@rpc("any_peer", "call_remote", "reliable")
func _net_fired(origin: Vector2, angles: PackedFloat32Array, bullet_scale: float, speed: float, lifetime: float, explosion_radius: float = 0.0) -> void:
	if is_multiplayer_authority():
		return
	var shooter := _find_shooter()
	for angle in angles:
		var bullet: Node = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.set("global_position", origin)
		bullet.set("global_rotation", angle)
		bullet.set("scale", Vector2.ONE * bullet_scale)
		bullet.set("damage", 0.0)
		bullet.set("speed", speed)
		bullet.set("lifetime", lifetime)
		bullet.set("shooter", shooter)
		bullet.set("explosion_radius", explosion_radius)
		bullet.set("visual_only", true)


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


## Muestra el sprite que corresponde al arma actual (stats.weapon_style):
## con la escopeta se reemplaza el Sprite2D del arma; si no, vuelve el original.
func refresh_visuals() -> void:
	var is_shotgun := stats.weapon_style == &"escopeta"
	if _sprite != null:
		if is_shotgun:
			_sprite.texture = shotgun_texture
			_sprite.scale = shotgun_scale
			_sprite.position = shotgun_position
			_sprite.rotation = deg_to_rad(shotgun_rotation_degrees)
		else:
			_sprite.texture = _base_texture
			_sprite.scale = _base_sprite_scale
			_sprite.position = _base_sprite_position
			_sprite.rotation = _base_sprite_rotation
	muzzle.position = _base_muzzle_position + (shotgun_muzzle_offset if is_shotgun else Vector2.ZERO)


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
