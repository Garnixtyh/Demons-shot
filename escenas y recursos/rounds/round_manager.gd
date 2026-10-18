class_name RoundManager
extends Node
## Maneja las rondas: al empezar cada una ofrece mejoras al jugador y aplica la elegida.

signal round_started(round_number: int)
signal upgrade_applied(upgrade: Upgrade)

@export var player_path: NodePath
@export var selector_path: NodePath
@export var options_per_round: int = 3

var round_number: int = 0

var player: CharacterBody2D
var selector: UpgradeSelector

var _pool: Array = []


func _ready() -> void:
	player = _find_node(player_path, "Player") as CharacterBody2D
	selector = _find_node(selector_path, "UpgradeSelector") as UpgradeSelector
	if player == null or selector == null:
		push_error("RoundManager: no encontré al jugador o al UpgradeSelector. "
				+ "Revisá que el nodo UpgradeSelector tenga asignado upgrade_selector.gd.")
		return
	# Mejoras genéricas + las propias del personaje elegido
	_pool = UpgradePool.create_all()
	if player.has_method("get_character_upgrades"):
		_pool.append_array(player.get_character_upgrades())
	selector.upgrade_chosen.connect(_on_upgrade_chosen)
	# Diferido para que el resto de la escena termine de conectarse antes de la ronda 1
	start_round.call_deferred()


## Empieza una ronda nueva y ofrece las mejoras para elegir.
func start_round() -> void:
	if selector.is_open():
		return
	round_number += 1
	var options: Array = _pool.duplicate()
	options.shuffle()
	selector.offer(options.slice(0, options_per_round), round_number)


## Busca el nodo por la ruta exportada; si no sirve, lo busca por nombre entre los hermanos.
func _find_node(path: NodePath, node_name: String) -> Node:
	if not path.is_empty() and has_node(path):
		return get_node(path)
	return get_parent().find_child(node_name, true, false)


func _on_upgrade_chosen(upgrade: Upgrade) -> void:
	var weapon := player.get_weapon() as Weapon
	upgrade.apply(weapon.stats, player)
	if upgrade.unique:
		_pool.erase(upgrade)
	weapon.reset()
	upgrade_applied.emit(upgrade)
	round_started.emit(round_number)
