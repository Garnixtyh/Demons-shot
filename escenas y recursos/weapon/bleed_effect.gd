extends Node
## Sangrado (carta Justice): se agrega como hijo de quien sangra y le hace daño cada
## `interval` segundos hasta que pasa `duration`. Usa take_damage() del padre. Tiñe de rojo.

## Tinte rojo aplicado mientras sangra (valor fijo: una constante no puede calcularse)
const TINT := Color(1.0, 0.45, 0.45)

var damage_per_tick: float = 4.0
var interval: float = 0.5
var duration: float = 3.0

var _time_left: float = 0.0
var _tick_timer: float = 0.0
var _victim: Node
var _original_modulate: Color = Color.WHITE


## Configura (o renueva) el sangrado. Si ya había uno, se queda con el más fuerte.
func refresh(p_damage: float, p_duration: float, p_interval: float) -> void:
	damage_per_tick = maxf(damage_per_tick if _time_left > 0.0 else 0.0, p_damage)
	interval = p_interval
	duration = p_duration
	_time_left = p_duration
	if _tick_timer <= 0.0:
		_tick_timer = p_interval


func _ready() -> void:
	_victim = get_parent()
	if _victim is CanvasItem:
		_original_modulate = _victim.modulate
		_victim.modulate = _original_modulate * TINT


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_victim) or ("dead" in _victim and _victim.dead):
		queue_free()
		return
	_time_left -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += interval
		_victim.take_damage(damage_per_tick)
	if _time_left <= 0.0:
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_victim) and _victim is CanvasItem:
		_victim.modulate = _original_modulate
