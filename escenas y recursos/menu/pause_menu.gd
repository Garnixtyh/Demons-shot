extends CanvasLayer
## Menú de pausa del modo un jugador (Escape). Pausa el juego mientras está abierto.
##  - A la izquierda los botones (Opciones, Reanudar, Volver al menú) con el mismo estilo del menú
##    principal; están en la escena (nodo "Botones"), cambialos ahí.
##  - A la derecha la lista de items (mejoras) que agarró el jugador, con su icono.
##    Pasá el mouse sobre un icono para ver su nombre y descripción (mismo cuadro que en la tienda).
##  - Escape también reanuda.

const OptionsMenu := preload("options_menu.gd")

## Escena a la que se vuelve con "volver al menú" (la pasa el RunManager)
@export_file("*.tscn") var menu_scene: String = "res://escenas y recursos/menu/main_menu.tscn"
## Cuánto se esconden hacia la izquierda los botones no seleccionados
@export var idle_shift: float = 50.0
## Tamaño en pantalla de cada icono de item
@export var item_icon_size: float = 72.0
## Icono que se usa si la mejora no tiene PNG
@export var fallback_icon: Texture2D = preload("res://icon.svg")

const GOLD := Color(1.0, 0.85, 0.3)
const IDLE_COLOR := Color(0.78, 0.78, 0.85, 0.8)
## Botón de la escena -> acción
const BUTTONS := {
	"Reanudar": "reanudar",
	"Opciones": "opciones",
	"VolverMenu": "menu",
}

var _locked: bool = false
var _buttons: Dictionary = {}        # nombre del nodo -> Button
var _base_x: Dictionary = {}         # nombre del nodo -> X de la escena (seleccionado)
var _tweens: Dictionary = {}
# Tooltip igual al de la tienda
var _tooltip: PanelContainer
var _tip_title: Label
var _tip_desc: Label

@onready var _items_grid: GridContainer = $Items/Margen/VBox/Grilla
@onready var _empty_label: Label = $Items/Margen/VBox/Vacio


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_buttons()
	_build_tooltip()
	_build_items()
	_apply_character()


func _process(_delta: float) -> void:
	if _tooltip.visible:
		_place_tooltip()


func _exit_tree() -> void:
	# Si el menú se va por cualquier motivo, el juego no se queda pausado
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _locked:
		get_viewport().set_input_as_handled()
		_resume()


# ---------------------------------------------------------------- Botones

func _build_buttons() -> void:
	var index := 0
	for node_name in BUTTONS:
		var button := get_node_or_null("Botones/" + node_name) as Button
		if button == null:
			push_warning("PauseMenu: falta el botón 'Botones/%s' en la escena." % node_name)
			continue
		button.focus_mode = Control.FOCUS_NONE
		_buttons[node_name] = button
		_base_x[node_name] = button.position.x
		button.modulate = Color(IDLE_COLOR, 0.0)
		button.position.x = _base_x[node_name] - idle_shift - 320.0
		button.mouse_entered.connect(_animate.bind(node_name, true))
		button.mouse_exited.connect(_animate.bind(node_name, false))
		button.pressed.connect(_on_pressed.bind(BUTTONS[node_name]))
		# Entrada: se deslizan uno tras otro
		var tween := create_tween().set_parallel(true)
		tween.tween_interval(0.08 * index)
		tween.chain().tween_property(button, "position:x", _base_x[node_name] - idle_shift, 0.4) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(button, "modulate", IDLE_COLOR, 0.25)
		_tweens[node_name] = tween
		index += 1


func _animate(node_name: String, selected: bool) -> void:
	if _locked and selected:
		return
	var button := _buttons[node_name] as Button
	if _tweens.has(node_name):
		(_tweens[node_name] as Tween).kill()
	var tween := create_tween().set_parallel(true)
	_tweens[node_name] = tween
	if selected:
		tween.tween_property(button, "position:x", _base_x[node_name], 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE * 1.07, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", Color.WHITE, 0.15)
	else:
		tween.tween_property(button, "position:x", _base_x[node_name] - idle_shift, 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE, 0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", IDLE_COLOR, 0.25)


func _on_pressed(action: String) -> void:
	if _locked:
		return
	match action:
		"opciones":
			_open_options()
		"reanudar":
			_resume()
		"menu":
			_go_to_menu()


func _open_options() -> void:
	_locked = true
	for node_name in _buttons:
		_animate(node_name, false)
	var options := OptionsMenu.new()
	options.closed.connect(func() -> void: _locked = false)
	add_child(options)


func _resume() -> void:
	_locked = true
	get_tree().paused = false
	queue_free()


func _go_to_menu() -> void:
	_locked = true
	get_tree().paused = false
	if ResourceLoader.exists(menu_scene):
		get_tree().change_scene_to_file(menu_scene)
	else:
		push_warning("PauseMenu: no existe la escena '%s'." % menu_scene)
		queue_free()


# ---------------------------------------------------------------- Personaje (color del fondo e icono)

func _apply_character() -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player == null or not player.has_method("get_character_data"):
		return
	var data = player.get_character_data()
	if data == null:
		return
	var background := get_node_or_null("Fondo") as CanvasItem
	if background != null:
		background.modulate = data.menu_color
	var icon := get_node_or_null("IconoPersonaje") as TextureRect
	if icon != null:
		icon.texture = data.menu_icon
		icon.visible = data.menu_icon != null


# ---------------------------------------------------------------- Items

func _build_items() -> void:
	var player := get_tree().get_first_node_in_group("players")
	var items: Array = []
	if player != null and "collected_items" in player:
		items = player.collected_items
	_empty_label.visible = items.is_empty()
	for item in items:
		_items_grid.add_child(_make_item(item))


func _make_item(item: Dictionary) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(item_icon_size, item_icon_size)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_entered.connect(_show_tip.bind(item["title"], item["description"]))
	slot.mouse_exited.connect(_hide_tip)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture: Texture2D = null
	var path: String = item["icon_path"]
	if not path.is_empty() and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	icon.texture = texture if texture != null else fallback_icon
	slot.add_child(icon)
	if int(item["count"]) > 1:
		var count := Label.new()
		count.text = "x%d" % int(item["count"])
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 18)
		count.add_theme_constant_override("outline_size", 6)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_child(count)
	return slot


# ---------------------------------------------------------------- Tooltip (misma descripción que en la tienda)

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_tooltip.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	_tip_title = _tip_label(box, 26, GOLD)
	_tip_desc = _tip_label(box, 18, Color.WHITE)
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(300, 0)


func _tip_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _show_tip(title: String, description: String) -> void:
	_tip_title.text = title
	_tip_desc.text = description
	_tooltip.reset_size()
	_tooltip.visible = true
	_place_tooltip()
	# La primera vez el texto con salto de línea aún no calculó su alto: se reajusta al frame siguiente
	# (mientras tanto queda invisible, así no se ve el recuadro enorme)
	_tooltip.modulate.a = 0.0
	await get_tree().process_frame
	if not _tooltip.visible:
		return
	_tip_desc.reset_size()
	_tooltip.reset_size()
	_place_tooltip()
	_tooltip.modulate.a = 1.0


func _hide_tip() -> void:
	_tooltip.visible = false


## Cerca del cursor, sin salirse de la pantalla
func _place_tooltip() -> void:
	var view := get_viewport().get_visible_rect().size
	var pos := get_viewport().get_mouse_position() + Vector2(20, 20)
	pos.x = clampf(pos.x, 0.0, maxf(view.x - _tooltip.size.x, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(view.y - _tooltip.size.y, 0.0))
	_tooltip.position = pos
