extends StaticBody2D
## Muñeco de práctica para probar daño. Se reinicia solo al morir.

@export var max_health: float = 100.0

@onready var _label: Label = $Label
@onready var _visual: ColorRect = $ColorRect

var health: float


func _ready() -> void:
	health = max_health
	_update_label()


func take_damage(amount: float) -> void:
	health -= amount
	_update_label()
	_flash()
	if health <= 0.0:
		await get_tree().create_timer(1.0).timeout
		health = max_health
		_update_label()


func _update_label() -> void:
	_label.text = "%d / %d" % [maxf(health, 0.0), max_health]


func _flash() -> void:
	_visual.modulate = Color(2, 2, 2)
	await get_tree().create_timer(0.05).timeout
	_visual.modulate = Color.WHITE
