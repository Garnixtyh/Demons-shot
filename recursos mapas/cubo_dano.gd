extends Area2D
## Cubo de daño para probar la muerte: hace daño periódico a todo lo que tenga take_damage().

@export var damage_per_tick: float = 15.0
@export var tick_time: float = 0.4

var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var hit := false
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage_per_tick)
			hit = true
	if hit:
		_timer = tick_time
