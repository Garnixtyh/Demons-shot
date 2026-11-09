class_name BossPortal
extends Area2D
## Portal que aparece al completar todas las fases. Al entrar avisa con `entered`
## (el RunManager lo usa para ir a la sala del jefe, que se agrega más adelante).

signal entered

var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	var zone := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90, 140)
	zone.shape = shape
	add_child(zone)
	body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("players"):
			entered.emit())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Óvalo violeta que pulsa (placeholder)
	var pulse := 1.0 + sin(_t * 4.0) * 0.06
	for i in 4:
		var k := 1.0 - i * 0.2
		var pts := PackedVector2Array()
		for a in 32:
			var ang := TAU * a / 32.0
			pts.append(Vector2(cos(ang) * 45.0, sin(ang) * 70.0) * k * pulse)
		draw_colored_polygon(pts, Color(0.55, 0.2, 0.9, 0.35 + i * 0.15))
