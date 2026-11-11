extends "../../abilities/ability.gd"
## Habilidad de Band (E): lanza una pava explosiva hacia el mouse.
## La pava es una escena propia (pava_explosiva.tscn): ahí se le pone el sprite
## y se ajusta la mecha, el daño y el radio.

const PavaScene := preload("pava_explosiva.tscn")
@export var recarga: = 6.7
## Velocidad del lanzamiento
@export var throw_speed: float = 750.0
## Impulso extra hacia arriba (para que salga en arco)
@export var upward_boost: float = 150.0


func _init() -> void:
	ability_name = "Pava explosiva"
	icon = preload("res://sprites/band/pava.png")
	cooldown = recarga


func _activate() -> void:
	var weapon: Node = player.get_weapon()
	var origin: Vector2 = weapon.muzzle.global_position
	var velocity: Vector2 = weapon.aim_direction * throw_speed \
			+ Vector2(0.0, -upward_boost) + player.velocity * 0.5
	var spin := randf_range(-6.0, 6.0)
	if not LanNetwork.in_lobby:
		_spawn_pava(origin, velocity, spin, "", player)
	elif multiplayer.is_server():
		_host_spawn(origin, velocity, spin, player)
	else:
		_server_throw.rpc_id(1, origin, velocity, spin)


## Un cliente pide lanzar una pava: lo crea el host y lo replica a todos.
@rpc("any_peer", "call_remote", "reliable")
func _server_throw(origin: Vector2, velocity: Vector2, spin: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player.get_multiplayer_authority():
		return
	_host_spawn(origin, velocity, spin, player)


func _host_spawn(origin: Vector2, velocity: Vector2, spin: float, thrower: Node2D) -> void:
	var pava_name := "Pava_%d" % GameSession.next_object_id()
	_spawn_pava(origin, velocity, spin, pava_name, thrower)
	_net_spawn_pava.rpc(pava_name, origin, velocity, spin, str(thrower.name))


@rpc("any_peer", "call_remote", "reliable")
func _net_spawn_pava(pava_name: String, origin: Vector2, velocity: Vector2, spin: float, thrower_name: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var thrower := get_tree().current_scene.get_node_or_null(thrower_name) as Node2D
	_spawn_pava(origin, velocity, spin, pava_name, thrower)


func _spawn_pava(origin: Vector2, velocity: Vector2, spin: float, pava_name: String, thrower: Node2D) -> void:
	var pava := PavaScene.instantiate() as RigidBody2D
	if not pava_name.is_empty():
		pava.name = pava_name
	pava.owner_player = thrower
	get_tree().current_scene.add_child(pava)
	pava.global_position = origin
	# No choca con quien lo lanza
	if thrower != null:
		pava.add_collision_exception_with(thrower)
	pava.linear_velocity = velocity
	pava.angular_velocity = spin
	if not pava_name.is_empty():
		pava.start_network()
