extends Node2D
## Orbe de fuego de Rebecca. Dos estados:
##  - ORBIT: gira alrededor de ella. Hace daño por contacto (cada `hit_cooldown` s al mismo enemigo)
##    y se apaga solo a los `duration` segundos.
##  - FLY: lanzado con la E, vuela en línea recta, daña al primer enemigo que toca y desaparece
##    (también al chocar con el mapa o a los `fly_time` segundos).
## Corre solo en la PC de su dueña; en las demás hay una copia (net_puppet) que solo se ve.

enum State { ORBIT, FLY }

@export_group("Daño")
## Daño por contacto mientras orbita
@export var contact_damage: float = 15.0
## Segundos antes de poder dañar otra vez al mismo enemigo
@export var hit_cooldown: float = 0.5
## Daño al impactar lanzado con la E
@export var thrown_damage: float = 30.0
## Qué tan cerca (px) tiene que estar un enemigo para recibir el daño
@export var hit_radius: float = 42.0

@export_group("Duración y vuelo")
## Segundos que dura orbitando
@export var duration: float = 8.0
@export var fly_speed: float = 900.0
@export var fly_time: float = 1.2
## Qué tan rápido se acomoda en su lugar cuando cambia la cantidad de orbes
@export var slot_smoothing: float = 10.0

## Quién lo tiene y su pasiva (los asigna la pasiva)
var owner_player: Node2D
var passive: Node
var state: State = State.ORBIT
## Ángulo actual y ángulo de su lugar en la órbita
var orbit_angle: float = 0.0
var target_angle: float = 0.0
## true = copia que solo se ve en las demás PCs
var net_puppet: bool = false

var _net_started: bool = false
var _life_left: float = 0.0
var _fly_dir: Vector2 = Vector2.RIGHT
var _fly_left: float = 0.0
var _next_hit: Dictionary = {}  # enemigo -> momento (ms) en que se lo puede dañar de nuevo


func _ready() -> void:
	_life_left = duration


## Posición en la órbita según su ángulo.
func orbit_position() -> Vector2:
	var center: Vector2 = owner_player.global_position + passive.orbit_center
	return center + Vector2.from_angle(orbit_angle) * passive.orbit_radius


## La E lo llama: sale disparado en línea recta.
func launch(direction: Vector2) -> void:
	state = State.FLY
	_fly_dir = direction.normalized()
	_fly_left = fly_time
	_next_hit.clear()


## En red: la PC de la dueña replica el orbe; las demás PCs crean una copia (net_puppet).
func start_network(authority_id: int) -> void:
	if _net_started or not LanNetwork.in_lobby:
		return
	_net_started = true
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(":position"))
	config.property_set_replication_mode(NodePath(":position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config
	sync.set_multiplayer_authority(authority_id)
	add_child(sync)
	if not net_puppet:
		tree_exiting.connect(_notify_gone)


func _notify_gone() -> void:
	if multiplayer.has_multiplayer_peer() and LanNetwork.in_lobby:
		_net_gone.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _net_gone() -> void:
	if net_puppet:
		queue_free()


func _physics_process(delta: float) -> void:
	if net_puppet:
		visible = not (is_instance_valid(owner_player) and owner_player.is_dead and state == State.ORBIT)
		return
	if not is_instance_valid(owner_player) or owner_player.is_dead:
		queue_free()
		return
	if state == State.ORBIT:
		_update_orbit(delta)
	else:
		_update_fly(delta)


func _update_orbit(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	orbit_angle = lerp_angle(orbit_angle, target_angle, 1.0 - exp(-slot_smoothing * delta))
	global_position = orbit_position()
	for enemy in _find_enemies():
		if global_position.distance_to(_center_of(enemy)) <= hit_radius:
			_try_contact(enemy)


func _try_contact(enemy: Node2D) -> void:
	var now := Time.get_ticks_msec()
	if _next_hit.get(enemy, 0) > now:
		return
	_next_hit[enemy] = now + int(hit_cooldown * 1000.0)
	_deal_damage(enemy, contact_damage)


func _update_fly(delta: float) -> void:
	_fly_left -= delta
	if _fly_left <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + _fly_dir * fly_speed * delta
	# Choca con el mapa (los jugadores y objetos dañables se ignoran en el rayo)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = _damageable_rids()
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position = to
	for enemy in _find_enemies():
		if global_position.distance_to(_center_of(enemy)) <= hit_radius:
			_deal_damage(enemy, thrown_damage)
			queue_free()
			return


func _deal_damage(enemy: Node, amount: float) -> void:
	enemy.take_damage(amount)
	if is_instance_valid(passive):
		passive.on_orb_damage(amount)


## Los jugadores tienen el origen en los pies: se apunta al medio del cuerpo.
func _center_of(enemy: Node2D) -> Vector2:
	if enemy.is_in_group("players") and is_instance_valid(passive):
		return enemy.global_position + passive.orbit_center
	return enemy.global_position


## Jugadores del otro equipo (vivos) y objetos del grupo "targets".
func _find_enemies() -> Array:
	var enemies: Array = []
	for other in get_tree().get_nodes_in_group("players"):
		if other != owner_player and not other.is_dead and other.team != owner_player.team:
			enemies.append(other)
	for target in get_tree().get_nodes_in_group("targets"):
		if target.has_method("take_damage") and not ("is_dead" in target and target.is_dead):
			enemies.append(target)
	return enemies


func _damageable_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for group in ["players", "targets", "pushables"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is CollisionObject2D:
				rids.append(node.get_rid())
	return rids
