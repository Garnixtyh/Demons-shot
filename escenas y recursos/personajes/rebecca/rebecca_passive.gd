extends Node
## Pasiva de Rebecca: cada vez que su básico (el fuego) conecta, genera un orbe de fuego
## que gira alrededor de TODO su cuerpo (360°). Máximo `max_orbs` a la vez.
## Es un nodo aparte (no vive en la E), así sigue funcionando aunque cambie la habilidad.
## Los orbes reales viven en la PC de su dueña; en las otras PCs se ven copias (como Panchu).

const OrbScene := preload("orbe_fuego.tscn")

## Orbes simultáneos (la mejora "Algo se prende fuego" suma 2)
@export var max_orbs: int = 3
## Fracción del daño de los orbes que se convierte en vida (mejora "Corazón en llamas"; 0 = nada)
@export var lifesteal_ratio: float = 0.0
@export_group("Órbita")
## Centro de la órbita respecto de los pies de Rebecca (hacia arriba = y negativo)
@export var orbit_center: Vector2 = Vector2(0.0, -50.0)
@export var orbit_radius: float = 95.0
## Radianes por segundo
@export var orbit_speed: float = 3.5

var player: Node2D
var _orbs: Array = []
var _base_angle: float = 0.0
var _spawn_counter: int = 0


func _ready() -> void:
	player = get_parent() as Node2D
	var weapon = player.get_weapon()
	weapon.bullet_hit.connect(_on_bullet_hit)
	player.died.connect(clear_orbs)


func _physics_process(delta: float) -> void:
	_orbs = _orbs.filter(func(o): return is_instance_valid(o))
	if _orbs.is_empty():
		return
	_base_angle = wrapf(_base_angle + orbit_speed * delta, 0.0, TAU)
	# Los orbes se reparten parejo por el círculo; si uno se va, los demás se reacomodan solos
	for i in _orbs.size():
		_orbs[i].target_angle = _base_angle + TAU * i / _orbs.size()


## El básico de Rebecca pegó en algo.
func _on_bullet_hit(_target: Node) -> void:
	if not player.is_multiplayer_authority() or player.is_dead or player.is_shielded():
		return
	_orbs = _orbs.filter(func(o): return is_instance_valid(o))
	if _orbs.size() >= max_orbs:
		return
	_add_orb()


func _add_orb() -> void:
	var orb := OrbScene.instantiate() as Node2D
	orb.owner_player = player
	orb.passive = self
	orb.orbit_angle = _base_angle + TAU * _orbs.size() / (_orbs.size() + 1)
	orb.target_angle = orb.orbit_angle
	var in_net := LanNetwork.in_lobby
	var orb_name := ""
	if in_net:
		_spawn_counter += 1
		orb_name = "Orbe_%d_%d" % [multiplayer.get_unique_id(), _spawn_counter]
		orb.name = orb_name
	_orbs.append(orb)
	# El orbe es un Area2D: no se puede agregar a la escena mientras la física procesa colisiones
	# (la bala conecta justo ahí), así que se agrega y se termina de armar en diferido.
	get_tree().current_scene.add_child.call_deferred(orb)
	_finish_orb.call_deferred(orb, in_net, orb_name)


func _finish_orb(orb: Node2D, in_net: bool, orb_name: String) -> void:
	if not is_instance_valid(orb) or not orb.is_inside_tree():
		return
	orb.global_position = orb.orbit_position()
	if in_net:
		# Primero las otras PCs crean su copia, después se empieza a replicar
		GameSession.net_spawn_panchu.rpc(OrbScene.resource_path, orb_name, multiplayer.get_unique_id())
		get_tree().create_timer(0.15).timeout.connect(_start_orb_sync.bind(orb))


func _start_orb_sync(orb: Node2D) -> void:
	if is_instance_valid(orb):
		orb.start_network(multiplayer.get_unique_id())


## Cuántos orbes tiene girando ahora.
func orb_count() -> int:
	_orbs = _orbs.filter(func(o): return is_instance_valid(o))
	return _orbs.size()


## Saca todos los orbes de la órbita y los devuelve (la E los lanza). Se queda sin ninguno.
func take_all_orbs() -> Array:
	_orbs = _orbs.filter(func(o): return is_instance_valid(o))
	var taken := _orbs.duplicate()
	_orbs.clear()
	return taken


## Apaga todos los orbes (al morir, o al terminar el escudo).
func clear_orbs() -> void:
	for orb in _orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbs.clear()


## Un orbe hizo daño: con "Corazón en llamas" cura a Rebecca.
func on_orb_damage(amount: float) -> void:
	if lifesteal_ratio > 0.0 and is_instance_valid(player):
		player.heal(amount * lifesteal_ratio)
