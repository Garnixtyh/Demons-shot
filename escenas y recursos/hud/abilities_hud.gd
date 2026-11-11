class_name AbilitiesHud
extends CanvasLayer
## HUD de habilidades: un cuadro con la imagen de la habilidad especial (pava de Band, tecla E)
## y otro con la del golpe melee. Al usarse el cuadro se pone transparente hasta que se recarga.
## La recarga se ve como en el LoL: la imagen se rellena con un barrido en sentido horario,
## empezando desde arriba, sobre la versión transparente.
## Lo crea el jugador como hijo suyo; solo se ve en el jugador de ESTA PC.

## Tamaño de cada cuadro en píxeles
const SLOT_SIZE := 80.0
## Separación entre cuadros y con el borde inferior de la pantalla
const SLOT_GAP := 12.0
const MARGIN := 16.0
## Transparencia de la imagen que se va rellenando mientras la habilidad se recarga
const COOLDOWN_ALPHA := 0.3
## Imagen del golpe melee (placeholder) y de la esquina cuando no hay letra (placeholder)
const MELEE_TEXTURE := preload("res://sprites/band/mano1.png")
const GODOT_ICON := preload("res://icon.svg")
## Imagen de la habilidad si esta no define `icon`
const ABILITY_FALLBACK_TEXTURE := preload("res://icon.svg")

var _player: Node = null
var _ability_slot: Control
var _ability_icon: RadialIcon
var _melee_icon: RadialIcon


func _ready() -> void:
	layer = 4
	_player = get_parent()
	_build()


func _process(_delta: float) -> void:
	# En red, los jugadores de las otras PCs también tienen este nodo: solo se ve el tuyo
	var root := get_node_or_null("Root") as Control
	if root != null:
		root.visible = _player != null and _player.is_multiplayer_authority()
	if _player == null or not _player.is_multiplayer_authority():
		return
	var ability = _player.get_ability()
	_ability_slot.visible = ability != null
	if ability != null:
		_ability_icon.texture = ability.icon if ability.icon != null else ABILITY_FALLBACK_TEXTURE
		_ability_icon.set_fill(1.0 - ability.get_cooldown_ratio())
	_melee_icon.set_fill(1.0 - _player.get_melee_cooldown_ratio())


func _build() -> void:
	var root := HBoxContainer.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", int(SLOT_GAP))
	# Abajo al centro de la pantalla
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.offset_bottom = -MARGIN
	add_child(root)

	_ability_slot = _make_slot(root)
	_ability_icon = _ability_slot.get_node("Icono") as RadialIcon
	_add_corner_text(_ability_slot, "E")

	var melee_slot := _make_slot(root)
	_melee_icon = melee_slot.get_node("Icono") as RadialIcon
	_melee_icon.texture = MELEE_TEXTURE
	_add_corner_icon(melee_slot, GODOT_ICON)


## Un cuadro: la imagen ocupa todo (se transparenta sola) y la esquina queda siempre opaca
func _make_slot(parent: Control) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	var icon := RadialIcon.new()
	icon.name = "Icono"
	icon.ghost_alpha = COOLDOWN_ALPHA
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	return slot


## Letra de la tecla en la esquina inferior derecha
func _add_corner_text(slot: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -2.0
	label.offset_bottom = -0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	slot.add_child(label)


## Icono chico en la esquina inferior derecha (en lugar de la letra)
func _add_corner_icon(slot: Control, texture: Texture2D) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(26, 26)
	icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	icon.grow_vertical = Control.GROW_DIRECTION_BEGIN
	icon.offset_right = -2.0
	icon.offset_bottom = -2.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)


## Imagen con relleno circular: de fondo la versión transparente y encima la versión
## opaca recortada en un sector que crece en sentido horario desde las 12 en punto.
class RadialIcon extends Control:
	var texture: Texture2D:
		set(value):
			texture = value
			queue_redraw()
	## Transparencia de la parte todavía sin rellenar
	var ghost_alpha: float = 0.3
	## 0 = vacía (recién usada), 1 = llena (lista)
	var fill: float = 1.0

	func set_fill(value: float) -> void:
		value = clampf(value, 0.0, 1.0)
		if is_equal_approx(value, fill):
			return
		fill = value
		queue_redraw()

	func _draw() -> void:
		if texture == null:
			return
		var rect := _fit_rect()
		if fill >= 1.0:
			draw_texture_rect(texture, rect, false)
			return
		draw_texture_rect(texture, rect, false, Color(1, 1, 1, ghost_alpha))
		if fill <= 0.0:
			return
		# Abanico de triángulos desde el centro, siguiendo el borde de la imagen
		var center := rect.get_center()
		var points := PackedVector2Array([center])
		var steps := maxi(int(ceil(fill * 72.0)), 2)
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * fill * float(i) / float(steps)
			points.append(_edge_point(rect, center, Vector2.from_angle(angle)))
		var uvs := PackedVector2Array()
		for point in points:
			uvs.append((point - rect.position) / rect.size)
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)

	## Donde cabe la imagen entera sin deformarse, centrada
	func _fit_rect() -> Rect2:
		var tex_size := texture.get_size()
		if tex_size.x <= 0.0 or tex_size.y <= 0.0:
			return Rect2(Vector2.ZERO, size)
		var factor := minf(size.x / tex_size.x, size.y / tex_size.y)
		var fitted := tex_size * factor
		return Rect2((size - fitted) * 0.5, fitted)

	## Punto donde un rayo desde el centro cruza el borde del rectángulo
	func _edge_point(rect: Rect2, center: Vector2, direction: Vector2) -> Vector2:
		var half := rect.size * 0.5
		var tx := INF if is_zero_approx(direction.x) else half.x / absf(direction.x)
		var ty := INF if is_zero_approx(direction.y) else half.y / absf(direction.y)
		return center + direction * minf(tx, ty)
