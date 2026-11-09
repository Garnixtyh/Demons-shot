class_name FireHazard
extends Area2D
## Fuego en el piso que dejan las velas del Velador: daña al jugador que lo toca (cada `tick`
## segundos) y se apaga solo al pasar `duration`. Usa un sprite animado (hoja de frames).

var texture: Texture2D = null
var hframes: int = 4
var fps: float = 8.0
var damage: float = 6.0
var tick: float = 0.7
var duration: float = 4.0
## Zona que daña (centrada de la base del fuego hacia arriba)
var hit_size: Vector2 = Vector2(44, 64)
var sprite_scale: Vector2 = Vector2(2, 2)

var _time: float = 0.0
var _tick_timer: float = 0.0
var _snapped: bool = false
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit_size
	shape.shape = rect
	shape.position = Vector2(0.0, -hit_size.y * 0.5)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = maxi(hframes, 1)
	_sprite.scale = sprite_scale
	_sprite.frame = randi() % _sprite.hframes
	if texture != null:
		# La base del sprite queda en el origen del fuego
		_sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if not _snapped:
		_snapped = true
		_snap_to_ground()
	_time += delta
	_tick_timer -= delta
	if _sprite.texture != null:
		_sprite.frame = int(_time * fps + 0.5) % _sprite.hframes
	# Se achica y desaparece en el último medio segundo
	var left := duration - _time
	if left <= 0.0:
		queue_free()
		return
	if left < 0.5:
		_sprite.modulate.a = left / 0.5
	if _tick_timer <= 0.0:
		for body in get_overlapping_bodies():
			if body.is_in_group("players") and body.has_method("take_damage"):
				body.take_damage(damage)
				_tick_timer = tick
				break


## Apoya el fuego sobre el piso que tenga debajo (ignora jugador y enemigos)
func _snap_to_ground() -> void:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(0.0, -40.0)
	var exclude: Array[RID] = []
	for i in 5:
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 400.0), 1)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return
		var collider: Object = hit["collider"]
		if collider is CharacterBody2D or collider is RigidBody2D:
			exclude.append(hit["rid"])
			continue
		global_position = hit["position"]
		return
