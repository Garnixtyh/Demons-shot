extends RigidBody2D
## Barril explosivo.
## - Se empuja con F (lo llama el jugador a través del grupo "pushables").
## - Recibe daño de las balas (take_damage). Al llegar a 0 explota y desaparece.
## - Reaparece en su punto de origen (donde lo pusiste en el mapa) tras `respawn_time`.
## - La explosión daña a todo lo que tenga take_damage() (jugadores y otros barriles).

signal exploded
signal respawned

@export var max_health: float = 40.0
## Segundos desde que explota hasta que vuelve a aparecer
@export var respawn_time: float = 5.0
## Si cae por debajo de esta altura, vuelve a su spawn sin explotar
@export var fall_limit_y: float = 2000.0

@export_group("Explosión")
@export var explosion_radius: float = 160.0
## Daño en el centro de la explosión
@export var explosion_damage: float = 80.0
## Proporción del daño que recibe quien está en el borde (0.4 = 40 %)
@export_range(0.0, 1.0) var edge_damage_ratio: float = 0.4
@export var explosion_color: Color = Color(1.0, 0.55, 0.1, 0.8)
## Segundos que dura el círculo de la explosión
@export var explosion_visual_time: float = 0.35

@export_group("Empuje (F)")
## Fuerza del empuje (impulso por segundo)
@export var push_force: float = 900.0
## El empuje no acelera el barril por encima de esta velocidad
@export var max_push_speed: float = 180.0

var health: float
var is_exploded: bool = false

var _spawn_position: Vector2
var _explode_pending: bool = false
var _respawn_timer: float = 0.0
var _flash_tween: Tween
## true durante una partida en red. El host simula el barril; los demás solo lo muestran.
var _net_active: bool = false
var _remote_exploded: bool = false

@onready var _visual: CanvasItem = $Visual
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("pushables")
	_spawn_position = global_position
	health = max_health


## La llama GameSession al empezar la partida en red.
func start_network() -> void:
	if not LanNetwork.in_lobby or _net_active:
		return
	_net_active = true
	if not multiplayer.is_server():
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true  # la posición llega del host
	var config := SceneReplicationConfig.new()
	for prop in [":position", ":rotation"]:
		config.add_property(NodePath(prop))
		config.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(NodePath(":is_exploded"))
	config.property_set_replication_mode(NodePath(":is_exploded"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config  # autoridad: el host
	add_child(sync)


func _physics_process(delta: float) -> void:
	if _net_active and not multiplayer.is_server():
		# Cliente: solo muestra u oculta el barril según el estado que manda el host
		if is_exploded != _remote_exploded:
			_remote_exploded = is_exploded
			_visual.visible = not is_exploded
			_shape.set_deferred("disabled", is_exploded)
		return
	if is_exploded:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	if _explode_pending:
		_explode()
	elif global_position.y > fall_limit_y:
		_vanish()


## Lo llaman las balas y otras explosiones.
func take_damage(amount: float) -> void:
	if _net_active and not multiplayer.is_server():
		_server_take_damage.rpc_id(1, amount)
		return
	if is_exploded or _explode_pending:
		return
	health -= amount
	_flash()
	if health <= 0.0:
		# La explosión se resuelve en el siguiente _physics_process
		# (las consultas de física no se pueden hacer dentro de un callback)
		_explode_pending = true


## Lo llama el jugador mientras mantiene F cerca del barril.
## `direction` es -1 o 1 (hacia dónde se empuja).
func push(direction: float, delta: float) -> void:
	if _net_active and not multiplayer.is_server():
		_server_push.rpc_id(1, direction, delta)
		return
	if is_exploded or direction == 0.0:
		return
	var moving_same_way := signf(linear_velocity.x) == direction
	if moving_same_way and absf(linear_velocity.x) >= max_push_speed:
		return
	apply_central_impulse(Vector2(direction * push_force * delta, 0.0))


func _explode() -> void:
	_explode_pending = false
	var center := global_position
	_damage_area(center)
	_spawn_explosion_visual(center)
	if _net_active:
		_net_explosion.rpc(center)
	_vanish()
	exploded.emit()


@rpc("any_peer", "call_remote", "reliable")
func _server_take_damage(amount: float) -> void:
	if multiplayer.is_server():
		take_damage(amount)


@rpc("any_peer", "call_remote", "unreliable")
func _server_push(direction: float, delta: float) -> void:
	if multiplayer.is_server():
		push(direction, delta)


## El host avisa que el barril explotó, para dibujar la explosión en todas las PCs.
@rpc("authority", "call_remote", "reliable")
func _net_explosion(center: Vector2) -> void:
	_spawn_explosion_visual(center)


func _damage_area(center: Vector2) -> void:
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var already_hit := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body := hit.collider as Node2D
		if body == null or already_hit.has(body) or not body.has_method("take_damage"):
			continue
		already_hit[body] = true
		var distance_ratio := clampf(center.distance_to(body.global_position) / explosion_radius, 0.0, 1.0)
		body.take_damage(lerpf(explosion_damage, explosion_damage * edge_damage_ratio, distance_ratio))


## Círculo naranja que se expande y se desvanece (placeholder visual).
func _spawn_explosion_visual(center: Vector2) -> void:
	var fx := Node2D.new()
	fx.z_index = 10
	get_parent().add_child(fx)
	fx.global_position = center
	var color := explosion_color
	var radius := explosion_radius
	fx.draw.connect(func() -> void: fx.draw_circle(Vector2.ZERO, radius, color))
	fx.scale = Vector2(0.2, 0.2)
	var tween := fx.create_tween().set_parallel(true)
	tween.tween_property(fx, "scale", Vector2.ONE, explosion_visual_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "modulate:a", 0.0, explosion_visual_time)
	tween.chain().tween_callback(fx.queue_free)


## Desaparece (sin colisión ni visual) hasta que toque reaparecer.
func _vanish() -> void:
	is_exploded = true
	_respawn_timer = respawn_time
	_visual.hide()
	_shape.set_deferred("disabled", true)
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func _respawn() -> void:
	is_exploded = false
	health = max_health
	global_position = _spawn_position
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_visual.modulate = Color.WHITE
	_visual.show()
	_shape.set_deferred("disabled", false)
	freeze = false
	respawned.emit()


func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_visual.modulate = Color(2.0, 2.0, 2.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual, "modulate", Color.WHITE, 0.12)
