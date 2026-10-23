extends RigidBody2D
## Termo explosivo: una dinamita con las mismas físicas que el barril explosivo.
## Se lanza con la E de Band, rebota/rueda y explota cuando se le acaba la mecha
## (o si le disparan). La explosión daña a todo lo que tenga take_damage().
## Para ponerle tu sprite: reemplazá el nodo "Sprite" de termo_explosivo.tscn
## (y ajustá el collider si cambia el tamaño).

signal exploded

## Segundos desde que se lanza hasta que explota
@export var fuse_time: float = 2.5
@export var explosion_radius: float = 150.0
## Daño en el centro de la explosión
@export var explosion_damage: float = 70.0
## Proporción del daño que recibe quien está en el borde
@export_range(0.0, 1.0) var edge_damage_ratio: float = 0.4
## false = la explosión no daña a quien lo lanzó
@export var damage_owner: bool = false
@export var explosion_color: Color = Color(1.0, 0.55, 0.1, 0.8)
@export var explosion_visual_time: float = 0.35

@export_group("Empuje (F)")
@export var push_force: float = 1900.0
@export var max_push_speed: float = 500.0

## Quién lo lanzó (lo asigna la habilidad)
var owner_player: Node = null

var _time_left: float = 0.0
var _exploded: bool = false
## true durante una partida en red. El host simula el termo; los demás solo lo muestran.
var _net_active: bool = false


func _ready() -> void:
	add_to_group("pushables")
	_time_left = fuse_time


## La llama la habilidad al lanzarlo en una partida en red (en todas las PCs).
func start_network() -> void:
	if not LanNetwork.in_lobby or _net_active:
		return
	_net_active = true
	if not multiplayer.is_server():
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true  # la posición llega del host
		# El cliente crea su receptor enseguida, para que exista cuando llegue lo que manda el host
		_add_synchronizer()
		return
	# El host espera un instante para que los demás ya tengan creado el termo
	get_tree().create_timer(0.1).timeout.connect(_add_synchronizer)


func _add_synchronizer() -> void:
	if _exploded or not is_inside_tree() or has_node("NetSync"):
		return
	var config := SceneReplicationConfig.new()
	for prop in [":position", ":rotation"]:
		config.add_property(NodePath(prop))
		config.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config  # autoridad: el host
	add_child(sync)


func _physics_process(delta: float) -> void:
	if _net_active and not multiplayer.is_server():
		return
	if _exploded:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_explode()
		return
	# Parpadea cada vez más rápido a medida que se acaba la mecha
	var urgency := 1.0 - _time_left / maxf(fuse_time, 0.01)
	var blink_rate := lerpf(3.0, 16.0, urgency)
	modulate = Color(0.533, 0.287, 0.363, 1.0) if sin(_time_left * blink_rate * TAU) > 0.0 else Color.WHITE


## Si le disparan, explota enseguida.
func take_damage(_amount: float) -> void:
	if _net_active and not multiplayer.is_server():
		_server_take_damage.rpc_id(1)
		return
	_time_left = minf(_time_left, 0.0)


func push(direction: float, delta: float) -> void:
	if _net_active and not multiplayer.is_server():
		_server_push.rpc_id(1, direction, delta)
		return
	if direction == 0.0:
		return
	if signf(linear_velocity.x) == direction and absf(linear_velocity.x) >= max_push_speed:
		return
	apply_central_impulse(Vector2(direction * push_force * delta, 0.0))


func _explode() -> void:
	_exploded = true
	var center := global_position
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
		if body == owner_player and not damage_owner:
			continue
		already_hit[body] = true
		var distance_ratio := clampf(center.distance_to(body.global_position) / explosion_radius, 0.0, 1.0)
		body.take_damage(lerpf(explosion_damage, explosion_damage * edge_damage_ratio, distance_ratio))
	_spawn_explosion_visual(center)
	if _net_active:
		_net_explosion.rpc(center)
	exploded.emit()
	queue_free()


@rpc("any_peer", "call_remote", "reliable")
func _server_take_damage() -> void:
	if multiplayer.is_server():
		take_damage(0.0)


@rpc("any_peer", "call_remote", "unreliable")
func _server_push(direction: float, delta: float) -> void:
	if multiplayer.is_server():
		push(direction, delta)


## El host avisa que explotó: se dibuja la explosión y desaparece la copia.
@rpc("authority", "call_remote", "reliable")
func _net_explosion(center: Vector2) -> void:
	_spawn_explosion_visual(center)
	queue_free()


## Círculo naranja que se expande y se desvanece (placeholder visual).
func _spawn_explosion_visual(center: Vector2) -> void:
	var fx := Node2D.new()
	fx.z_index = 10
	get_tree().current_scene.add_child(fx)
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
