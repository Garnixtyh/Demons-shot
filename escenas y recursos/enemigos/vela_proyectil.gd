class_name CandleProjectile
extends Area2D
## Vela lanzada por el Velador. Vuela en arco (gravedad propia); al tocar al jugador le hace daño
## y, al impactar contra algo (jugador, piso o pared), se apaga y deja fuegos (FireHazard).

var thrower: Node = null
var velocity: Vector2 = Vector2.ZERO
var fall_gravity: float = 900.0
var damage: float = 15.0
## Vueltas por segundo que gira en el aire (radianes/s)
var spin: float = 12.0
var texture: Texture2D = null
var fire_count: int = 3
var fire_spacing: float = 70.0
var fire_damage: float = 6.0
var fire_tick: float = 0.7
var fire_duration: float = 4.0
var fire_texture: Texture2D = null
var fire_hframes: int = 4

var _impacted: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	add_child(sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	rotation += spin * delta
	if global_position.y > 5000.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _impacted or body == thrower or body.is_in_group("enemies"):
		return
	if body.is_in_group("players") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	_impact()


func _impact() -> void:
	_impacted = true
	set_physics_process(false)
	var parent := get_parent()
	var origin := global_position
	for i in fire_count:
		var offset := (i - (fire_count - 1) * 0.5) * fire_spacing
		var fire := FireHazard.new()
		fire.texture = fire_texture
		fire.hframes = fire_hframes
		fire.damage = fire_damage
		fire.tick = fire_tick
		fire.duration = fire_duration
		fire.position = parent.to_local(origin + Vector2(offset, 0.0))
		# Se agrega recién cuando termina el paso de física (acá todavía se están procesando choques)
		parent.add_child.call_deferred(fire)
	queue_free()
