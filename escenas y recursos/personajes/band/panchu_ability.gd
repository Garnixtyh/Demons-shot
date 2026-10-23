extends "../../abilities/ability.gd"
## Habilidad de Band con la mejora "Panchu".
## Con la habilidad CARGADA, Panchu orbita sobre Band. Al apretar E sale
## disparado a perseguir enemigos y desaparece al cabecear a uno (o a los
## segundos). Cuando termina el cooldown, vuelve a aparecer orbitando.
## Daño, aturdimiento, velocidad y órbita se ajustan en panchu.tscn.

const PanchuScene := preload("panchu.tscn")

var _panchu: Node2D = null
var _spawn_counter: int = 0


func _init() -> void:
	ability_name = "Panchu"
	cooldown = 7.0


func _ready() -> void:
	super()
	ready_again.connect(_spawn_panchu)
	_spawn_panchu.call_deferred()


func can_activate() -> bool:
	return super() and is_instance_valid(_panchu)


func _activate() -> void:
	_panchu.launch()
	_panchu = null


func _spawn_panchu() -> void:
	if is_instance_valid(_panchu) or not player.is_multiplayer_authority():
		return
	_panchu = PanchuScene.instantiate() as Node2D
	_panchu.owner_player = player
	var in_net := LanNetwork.in_lobby
	var panchu_name := ""
	if in_net:
		_spawn_counter += 1
		panchu_name = "Panchu_%d_%d" % [multiplayer.get_unique_id(), _spawn_counter]
		_panchu.name = panchu_name
	get_tree().current_scene.add_child(_panchu)
	_panchu.global_position = player.global_position + _panchu.orbit_offset
	if in_net:
		# Primero las otras PCs crean su copia, después se empieza a replicar
		GameSession.net_spawn_panchu.rpc(PanchuScene.resource_path, panchu_name, multiplayer.get_unique_id())
		get_tree().create_timer(0.15).timeout.connect(_start_panchu_sync.bind(_panchu))


func _start_panchu_sync(panchu: Node2D) -> void:
	if is_instance_valid(panchu):
		panchu.start_network(multiplayer.get_unique_id())


## Si la habilidad se cambia por otra, Panchu en órbita se va con ella.
func _exit_tree() -> void:
	if is_instance_valid(_panchu):
		_panchu.queue_free()
