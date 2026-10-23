class_name Bullet
extends Area2D
## Bala: avanza en línea recta, daña lo que tenga take_damage() y desaparece al chocar.
## Opcional: envenena al objetivo y/o explota al impactar (lo define el arma).

const PoisonEffect := preload("poison_effect.gd")

var damage: float = 20.0
var speed: float = 900.0
var lifetime: float = 1.5
## Quien disparó; la bala lo ignora para no dañarse a sí mismo
var shooter: Node = null

## Veneno: daño por tick (0 = sin veneno)
var poison_damage: float = 0.0
var poison_duration: float = 3.0
var poison_interval: float = 0.5

## Explosión al impactar: radio en píxeles (0 = no explota)
var explosion_radius: float = 0.0
var explosion_damage: float = 0.0
var explosion_color: Color = Color(1.0, 0.6, 0.1, 0.7)

## true = copia que solo se ve (bala de otra PC en red): no daña, solo desaparece al chocar
var visual_only: bool = false

var _impact_pending: bool = false
var _hit_body: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _impact_pending:
		# La explosión se resuelve acá (no se puede consultar la física dentro del callback)
		_explode()
		queue_free()
		return
	global_position += transform.x * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter or _impact_pending:
		return
	if visual_only:
		if explosion_radius > 0.0:
			_spawn_explosion_visual(global_position)
		queue_free()
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if poison_damage > 0.0:
			_apply_poison(body)
	if explosion_radius > 0.0:
		_hit_body = body
		_impact_pending = true
		hide()
		set_deferred("monitoring", false)
	else:
		queue_free()


func _apply_poison(body: Node) -> void:
	if body is RigidBody2D or not body.has_method("take_damage"):
		return
	if "is_dead" in body and body.is_dead:
		return
	var effect = body.get_node_or_null("PoisonEffect")
	if effect == null:
		effect = PoisonEffect.new()
		effect.name = "PoisonEffect"
		effect.refresh(poison_damage, poison_duration, poison_interval)
		body.add_child.call_deferred(effect)
	else:
		effect.refresh(poison_damage, poison_duration, poison_interval)


func _explode() -> void:
	var center := global_position
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1
	var already_hit := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var target := hit.collider as Node
		# El que recibió la bala ya se llevó el daño directo; el tirador no se daña
		if target == null or target == shooter or target == _hit_body or already_hit.has(target):
			continue
		already_hit[target] = true
		if target.has_method("take_damage"):
			target.take_damage(explosion_damage)
	_spawn_explosion_visual(center)


## Círculo que se expande y se desvanece (placeholder visual).
func _spawn_explosion_visual(center: Vector2) -> void:
	var fx := Node2D.new()
	fx.z_index = 10
	get_tree().current_scene.add_child(fx)
	fx.global_position = center
	var color := explosion_color
	var radius := explosion_radius
	fx.draw.connect(func() -> void: fx.draw_circle(Vector2.ZERO, radius, color))
	fx.scale = Vector2(0.3, 0.3)
	var tween := fx.create_tween().set_parallel(true)
	tween.tween_property(fx, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(fx.queue_free)
