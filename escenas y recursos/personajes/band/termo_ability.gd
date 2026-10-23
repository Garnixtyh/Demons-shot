extends "../../abilities/ability.gd"
## Habilidad de Band (E): lanza un termo explosivo hacia el mouse.
## El termo es una escena propia (termo_explosivo.tscn): ahí se le pone el sprite
## y se ajusta la mecha, el daño y el radio.

const TermoScene := preload("termo_explosivo.tscn")
@export var recarga: = 6.7
## Velocidad del lanzamiento
@export var throw_speed: float = 750.0
## Impulso extra hacia arriba (para que salga en arco)
@export var upward_boost: float = 150.0


func _init() -> void:
	ability_name = "Termo explosivo"
	cooldown = recarga


func _activate() -> void:
	var weapon: Node = player.get_weapon()
	var origin: Vector2 = weapon.muzzle.global_position
	var velocity: Vector2 = weapon.aim_direction * throw_speed \
			+ Vector2(0.0, -upward_boost) + player.velocity * 0.5
	var spin := randf_range(-6.0, 6.0)
	if not LanNetwork.in_lobby:
		_spawn_termo(origin, velocity, spin, "", player)
	elif multiplayer.is_server():
		_host_spawn(origin, velocity, spin, player)
	else:
		_server_throw.rpc_id(1, origin, velocity, spin)


## Un cliente pide lanzar un termo: lo crea el host y lo replica a todos.
@rpc("any_peer", "call_remote", "reliable")
func _server_throw(origin: Vector2, velocity: Vector2, spin: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player.get_multiplayer_authority():
		return
	_host_spawn(origin, velocity, spin, player)


func _host_spawn(origin: Vector2, velocity: Vector2, spin: float, thrower: Node2D) -> void:
	var termo_name := "Termo_%d" % GameSession.next_object_id()
	_spawn_termo(origin, velocity, spin, termo_name, thrower)
	_net_spawn_termo.rpc(termo_name, origin, velocity, spin, str(thrower.name))


@rpc("any_peer", "call_remote", "reliable")
func _net_spawn_termo(termo_name: String, origin: Vector2, velocity: Vector2, spin: float, thrower_name: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var thrower := get_tree().current_scene.get_node_or_null(thrower_name) as Node2D
	_spawn_termo(origin, velocity, spin, termo_name, thrower)


func _spawn_termo(origin: Vector2, velocity: Vector2, spin: float, termo_name: String, thrower: Node2D) -> void:
	var thermos := TermoScene.instantiate() as RigidBody2D
	if not termo_name.is_empty():
		thermos.name = termo_name
	thermos.owner_player = thrower
	get_tree().current_scene.add_child(thermos)
	thermos.global_position = origin
	# No choca con quien lo lanza
	if thrower != null:
		thermos.add_collision_exception_with(thrower)
	thermos.linear_velocity = velocity
	thermos.angular_velocity = spin
	if not termo_name.is_empty():
		thermos.start_network()
