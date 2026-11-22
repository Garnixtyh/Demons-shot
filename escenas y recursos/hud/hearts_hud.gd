class_name HeartsHud
extends CanvasLayer
## HUD de vida con contenedores de corazón: uno cada `hp_per_heart` de vida máxima.
## Cada corazón tiene 3 capas (de abajo hacia arriba):
##   1. fondo  (vida_fondo.png)
##   2. líquido: un shader sobre la misma imagen del fondo, así el líquido queda
##      recortado por su forma. Sube y baja según la vida actual, con olas simples.
##   3. marco  (vida_marco.png)
## Ponelo en el mapa instanciando hearts_hud.tscn. Muestra la vida de TU jugador.

const LIQUID_SHADER := preload("res://escenas y recursos/hud/heart_liquid.gdshader")

@export var frame_texture: Texture2D = preload("res://sprites/hud/vida_marco.png")
@export var background_texture: Texture2D = preload("res://sprites/hud/vida_fondo.png")
## Vida que representa cada corazón
@export var hp_per_heart: float = 25.0
## Tamaño en pantalla del MARCO (define el tamaño de cada contenedor)
@export var frame_size: Vector2 = Vector2(48, 48)
## Tamaño en pantalla del FONDO y del líquido (independiente del marco)
@export var background_size: Vector2 = Vector2(40, 40)
## Desplazamiento del fondo respecto del centro del marco (0, 0 = centrado)
@export var background_offset: Vector2 = Vector2.ZERO
## Corazones por fila (con 250 de vida máxima: 2 filas de 5)
@export var hearts_per_row: int = 5
@export var spacing: float = 4.0
@export var margin: Vector2 = Vector2(16, 16)
## Qué tan rápido sube/baja el líquido hacia la vida real (más alto = más rápido)
@export var fill_speed: float = 8.0
@export var liquid_color: Color = Color(1.0, 0.0, 0.0)
@export var surface_color: Color = Color(1.0, 0.45, 0.45)
## Rango vertical del corazón dentro de la imagen (0 = arriba, 1 = abajo).
## Si el PNG tiene espacio vacío arriba/abajo, ajustalo para que "lleno" y "vacío" coincidan.
@export_range(0.0, 1.0) var heart_top: float = 0.0
@export_range(0.0, 1.0) var heart_bottom: float = 1.0
@export var wave_amplitude: float = 0.025

var _flow: HFlowContainer
var _hearts: Array[Dictionary] = []  # {"material": ShaderMaterial, "fill": float}
var _player: Node = null


func _ready() -> void:
	layer = 4
	_flow = HFlowContainer.new()
	_flow.position = margin
	# Ancho justo para `hearts_per_row` corazones: el siguiente salta a la fila de abajo
	_flow.custom_minimum_size = Vector2(frame_size.x * hearts_per_row + spacing * (hearts_per_row - 1), 0.0)
	_flow.add_theme_constant_override("h_separation", int(spacing))
	_flow.add_theme_constant_override("v_separation", int(spacing))
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flow)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
	var max_health: float = _player.max_health
	var health: float = _player.health
	var count := maxi(ceili(max_health / hp_per_heart), 1)
	if count != _hearts.size():
		_rebuild(count)
	var weight := 1.0 - exp(-fill_speed * delta)
	for i in _hearts.size():
		var target := clampf((health - i * hp_per_heart) / hp_per_heart, 0.0, 1.0)
		var heart := _hearts[i]
		heart["fill"] = lerpf(heart["fill"], target, weight)
		(heart["material"] as ShaderMaterial).set_shader_parameter("fill", heart["fill"])


## El jugador de ESTA PC (en red, el que controlás vos).
func _find_player() -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority() and "max_health" in player:
			return player
	return null


func _rebuild(count: int) -> void:
	# Los corazones que ya existen conservan su nivel de líquido
	while _hearts.size() > count:
		_hearts.pop_back()
		_flow.get_child(_flow.get_child_count() - 1).queue_free()
		_flow.remove_child(_flow.get_child(_flow.get_child_count() - 1))
	while _hearts.size() < count:
		_add_heart()


func _add_heart() -> void:
	var holder := Control.new()
	holder.custom_minimum_size = frame_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# El fondo y el líquido comparten tamaño y posición (centrados en el marco + offset)
	var bg_position := (frame_size - background_size) / 2.0 + background_offset

	# 1. Fondo
	holder.add_child(_make_layer(background_texture, bg_position, background_size))

	# 2. Líquido (recortado por el alpha del fondo)
	var liquid := _make_layer(background_texture, bg_position, background_size)
	var material := ShaderMaterial.new()
	material.shader = LIQUID_SHADER
	material.set_shader_parameter("fill", 0.0)
	material.set_shader_parameter("top", heart_top)
	material.set_shader_parameter("bottom", heart_bottom)
	material.set_shader_parameter("liquid_color", liquid_color)
	material.set_shader_parameter("surface_color", surface_color)
	material.set_shader_parameter("wave_amp", wave_amplitude)
	liquid.material = material
	holder.add_child(liquid)

	# 3. Marco por encima
	holder.add_child(_make_layer(frame_texture, Vector2.ZERO, frame_size))

	_flow.add_child(holder)
	_hearts.append({"material": material, "fill": 0.0})


func _make_layer(texture: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = pos
	rect.size = size
	return rect
