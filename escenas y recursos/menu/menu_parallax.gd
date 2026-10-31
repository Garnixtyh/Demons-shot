class_name MenuParallax
extends Node
## Parallax con el mouse para los menús (el mismo efecto del menú principal).
## Cada "capa" es un Node2D que se mueve al revés del mouse; cuanto mayor su fuerza, más se mueve.
## Uso:
##   var parallax := MenuParallax.new()
##   add_child(parallax)
##   parallax.smoothing = 6.0
##   parallax.add_layer(mi_sprite, 14.0)   # 14 px con el mouse en el borde de la pantalla

## Qué tan rápido sigue al mouse
var smoothing: float = 6.0

var _layers: Array[Dictionary] = []
var _offset: Vector2 = Vector2.ZERO


## Agrega una capa. Su posición actual es el punto de reposo (mouse en el centro).
func add_layer(node: Node2D, strength: float) -> void:
	_layers.append({"node": node, "base": node.position, "strength": strength})


## Cambia el punto de reposo de una capa (por ejemplo si se re-centró al cambiar el tamaño de la ventana).
func rebase(node: Node2D, new_base: Vector2) -> void:
	for layer in _layers:
		if layer["node"] == node:
			layer["base"] = new_base


func _process(delta: float) -> void:
	var viewport := get_viewport()
	var half := viewport.get_visible_rect().size / 2.0
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var target := ((viewport.get_mouse_position() - half) / half).clampf(-1.0, 1.0)
	_offset = _offset.lerp(target, 1.0 - exp(-smoothing * delta))
	for layer in _layers:
		var node := layer["node"] as Node2D
		if is_instance_valid(node):
			node.position = (layer["base"] as Vector2) - _offset * float(layer["strength"])
