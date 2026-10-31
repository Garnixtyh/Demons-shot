class_name Consumable
extends RigidBody2D
## MOLDE de los consumibles (no se usa solo: cada consumible lo extiende y tiene su PROPIA escena).
##
## Ciclo de vida:
##   1. Está en el mapa. Un jugador que lo toca y tiene el bolsillo vacío se lo lleva.
##   2. Queda guardado en el bolsillo del jugador (player.pocket), fuera del mapa.
##   3. Con la Q el jugador lo usa: se aplica el efecto durante `duration` segundos y se destruye.
##
## Para crear un consumible nuevo:
##   - Escena nueva: RigidBody2D (físicas) + Sprite2D + CollisionShape2D, y un hijo Area2D llamado
##     "Pickup" (con su CollisionShape2D) que detecta al jugador. El script extiende este.
##   - Poné `display_name`, `hud_icon` y `duration` en _setup() (o en el Inspector).
##   - Escribí _apply_effect(player) y _remove_effect(player).
## No sobreescribas _ready ni _physics_process: usá _setup().

## Nombre que se ve en el bolsillo del HUD
@export var display_name: String = "Consumible"
## Imagen que se ve en el bolsillo del HUD
@export var hud_icon: Texture2D
## Segundos que dura el efecto (0 = instantáneo)
@export var duration: float = 0.0

## Segundos que le quedan al efecto (mientras está activo)
var time_left: float = 0.0
## true mientras el efecto está funcionando
var active: bool = false

var _taken: bool = false
var _retry_timer: float = 0.0
var _player: Node = null
## Zona que detecta al jugador (hijo "Pickup")
var _pickup: Area2D = null
## Jugadores que ya no chocan con el consumible (lo atraviesan; solo lo recogen)
var _ignored_players: Dictionary = {}


func _ready() -> void:
	add_to_group("consumables")
	_pickup = get_node_or_null("Pickup") as Area2D
	if _pickup == null:
		push_warning("Consumable '%s': falta el hijo Area2D llamado 'Pickup'." % name)
	_setup()


## Preparación propia de cada consumible (se llama desde _ready).
func _setup() -> void:
	pass


## Se llama al usarlo. Aplica el efecto (con los stats del jugador).
func _apply_effect(_player_node: Node) -> void:
	pass


## Se llama cuando termina `duration`. Tiene que dejar los stats como estaban.
func _remove_effect(_player_node: Node) -> void:
	pass


# ---------------------------------------------------------------- Recogerlo

func _physics_process(delta: float) -> void:
	if active:
		time_left -= delta
		if time_left <= 0.0:
			_finish()
		return
	if _taken or _pickup == null:
		return
	_ignore_players()
	_retry_timer = maxf(_retry_timer - delta, 0.0)
	if _retry_timer > 0.0:
		return
	# Se revisa todos los frames (no solo al entrar): si el bolsillo estaba lleno y se libera
	# estando encima, lo agarra igual.
	for body in _pickup.get_overlapping_bodies():
		if _try_pickup(body):
			break


## Los jugadores no chocan con el consumible (no lo empujan ni los traba): lo atraviesan.
func _ignore_players() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not _ignored_players.has(player):
			_ignored_players[player] = true
			add_collision_exception_with(player)


func _try_pickup(body: Node) -> bool:
	if not body.is_in_group("players") or not body.is_multiplayer_authority():
		return false
	if not body.has_method("can_take_consumable") or not body.can_take_consumable():
		return false
	# Si el host lo rechaza (otro jugador llegó antes), vuelve a probar recién en medio segundo
	_retry_timer = 0.5
	if LanNetwork.in_lobby:
		_request_pickup.rpc_id(1, body.get_multiplayer_authority())
	else:
		_collect.call_deferred(body)
	return true


## Sin red: el jugador se lo lleva directo.
func _collect(body: Node) -> void:
	if _taken:
		return
	_taken = true
	if not body.add_to_pocket(self):
		queue_free()


## En red, el host decide quién se lo lleva (así dos jugadores no agarran el mismo).
@rpc("any_peer", "call_local", "reliable")
func _request_pickup(peer_id: int) -> void:
	if not multiplayer.is_server() or _taken:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	_taken = true
	_net_taken.rpc(peer_id)


## El host avisó quién se lo llevó: en esa PC va al bolsillo; en las demás desaparece del mapa.
@rpc("authority", "call_local", "reliable")
func _net_taken(peer_id: int) -> void:
	_taken = true
	if peer_id != multiplayer.get_unique_id():
		queue_free()
		return
	var player := _find_local_player()
	if player == null or not player.add_to_pocket(self):
		queue_free()


func _find_local_player() -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player
	return null


# ---------------------------------------------------------------- Usarlo

## La llama el jugador con la Q. El consumible pasa a ser hijo del jugador mientras dura el efecto.
func use(player: Node) -> void:
	_player = player
	# Deja de ser un objeto físico: queda quieto, sin colisión y sin zona de recogida
	set_deferred("freeze", true)
	collision_mask = 0
	if _pickup != null:
		_pickup.set_deferred("monitoring", false)
	hide()
	player.add_child(self)
	active = true
	time_left = duration
	_apply_effect(player)
	if duration <= 0.0:
		_finish()


func _finish() -> void:
	if not active:
		return
	active = false
	if is_instance_valid(_player):
		_remove_effect(_player)
	queue_free()
