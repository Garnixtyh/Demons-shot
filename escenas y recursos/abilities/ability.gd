extends Node
## MOLDE de habilidad especial (tecla E).
##
## Cada personaje tiene su propia habilidad: se crea un script nuevo que
## EXTIENDE este y sobrescribe _activate(). Ejemplo:
##
##   extends "ability.gd"
##
##   func _init() -> void:
##       ability_name = "Mi habilidad"
##       cooldown = 8.0
##
##   func _activate() -> void:
##       # lo que haga la habilidad (usá `player` para acceder al jugador)
##
## Después se asigna a cada personaje en el Inspector del jugador:
## grupo "Habilidad especial" > ability_script_path.
##
## Este script se encarga del cooldown, de las señales y del texto en pantalla.

signal activated
signal cooldown_started(duration: float)
signal ready_again

@export var ability_name: String = "Habilidad"
## Segundos de espera entre usos
@export var cooldown: float = 5.0
## Muestra abajo en pantalla el nombre y el cooldown de la habilidad
@export var show_hud: bool = true

## El jugador dueño de la habilidad (el nodo padre)
var player: Node2D

var _cooldown_left: float = 0.0
var _hud_label: Label


func _ready() -> void:
	player = get_parent() as Node2D
	if show_hud:
		_create_hud()


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
		if _cooldown_left == 0.0:
			ready_again.emit()
	_update_hud()


## La llama el jugador al apretar E. Devuelve true si se usó.
func try_activate() -> bool:
	if not can_activate():
		return false
	_activate()
	_cooldown_left = cooldown
	activated.emit()
	cooldown_started.emit(cooldown)
	return true


func can_activate() -> bool:
	return _cooldown_left <= 0.0 and not player.is_dead and not player.net_frozen


## 0 = lista para usar, 1 = recién usada (sirve para barras de cooldown)
func get_cooldown_ratio() -> float:
	if cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_left / cooldown, 0.0, 1.0)


## SOBRESCRIBIR en cada personaje: lo que hace la habilidad.
func _activate() -> void:
	pass


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_label = Label.new()
	layer.add_child(_hud_label)
	_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_label.offset_top = -44.0
	_hud_label.offset_bottom = -16.0
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 20)


func _update_hud() -> void:
	if _hud_label == null:
		return
	# En red, solo se muestra el cooldown de TU habilidad, no el de los demás jugadores
	_hud_label.visible = player != null and player.is_multiplayer_authority()
	if _cooldown_left > 0.0:
		_hud_label.text = "%s: %.1f s" % [ability_name, _cooldown_left]
	else:
		_hud_label.text = "[E] %s" % ability_name
