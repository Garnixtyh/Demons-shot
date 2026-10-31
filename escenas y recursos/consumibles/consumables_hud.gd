class_name ConsumablesHud
extends CanvasLayer
## HUD del bolsillo de consumibles: muestra el que tenés guardado (con la tecla para usarlo)
## y, arriba, los efectos que están activos con los segundos que les quedan.
## Lo crea el jugador como hijo suyo; solo se ve en el jugador de ESTA PC.

## Tamaño del cuadro del bolsillo en píxeles
@export var slot_size: float = 80.0
## Separación con el borde inferior izquierdo de la pantalla
@export var margin: float = 16.0
## Imagen del bolsillo cuando está vacío
@export var empty_texture: Texture2D = preload("res://sprites/recolectables/tarot/carta_blanco.png")
@export var empty_alpha: float = 0.45
## Letra que se ve en la esquina del bolsillo
@export var key_text: String = "Q"

var _player: Node = null
var _icon: TextureRect
var _name_label: Label
var _effects_label: Label


func _ready() -> void:
	layer = 4
	_player = get_parent()
	_build()


func _process(_delta: float) -> void:
	# En red, los jugadores de las otras PCs también tienen este nodo: solo se ve el tuyo
	visible = _player != null and _player.is_multiplayer_authority()
	if not visible:
		return
	var item = _player.pocket
	if item != null and is_instance_valid(item):
		_icon.texture = item.hud_icon
		_icon.modulate.a = 1.0
		_name_label.text = item.display_name
	else:
		_icon.texture = empty_texture
		_icon.modulate.a = empty_alpha
		_name_label.text = ""
	var lines: PackedStringArray = []
	for child in _player.get_children():
		if child is Consumable and child.active:
			lines.append("%s  %.1fs" % [child.display_name, maxf(child.time_left, 0.0)])
	_effects_label.text = "\n".join(lines)


func _build() -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.anchor_left = 0.0
	box.anchor_right = 0.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = margin
	box.offset_bottom = -margin
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(box)

	_effects_label = _make_label(14)
	box.add_child(_effects_label)

	var slot := Control.new()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(_icon)

	var key := _make_label(16)
	key.text = key_text
	key.position = Vector2(4, 0)
	slot.add_child(key)

	_name_label = _make_label(14)
	box.add_child(_name_label)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label
