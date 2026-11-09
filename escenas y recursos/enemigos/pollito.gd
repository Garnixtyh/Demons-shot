class_name Pollito
extends EnemyBase
## Pollito: como un Goomba. Camina en línea recta, da la vuelta al chocar con una pared y solo
## hace daño por contacto.

@export var walk_speed: float = 90.0
## Da la vuelta al llegar a un borde (false = se cae como un Goomba)
@export var turn_at_ledges: bool = false

var _turn_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	face(1.0 if randf() < 0.5 else -1.0)
	_play_loop(&"walk")


func _ai(delta: float, _player: Node2D) -> void:
	_turn_cooldown = maxf(_turn_cooldown - delta, 0.0)
	if _turn_cooldown <= 0.0 and (is_on_wall() or (turn_at_ledges and _ledge_ahead())):
		face(-facing)
		_turn_cooldown = 0.3
	velocity.x = facing * walk_speed


## true si adelante no hay piso
func _ledge_ahead() -> bool:
	if not is_on_floor():
		return false
	var from := Transform2D(0.0, global_position + Vector2(facing * 20.0, -4.0))
	return not test_move(from, Vector2(0.0, 24.0))
