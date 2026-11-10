class_name ShopMenu
extends CanvasLayer
## Menú de la tienda (se arma por código). Se abre con open(jugador, artículos):
## muestra los artículos con su icono y precio; al pasar el cursor por un icono aparece
## un cuadro con su nombre y descripción; al clickear se compra con los puntos del jugador.
## Esc lo cierra. Mientras está abierto el jugador queda quieto.

signal closed
## Salió bien el reroll: el vendedor tiene que sortear artículos nuevos (set_items)
signal reroll_succeeded

## Tamaño de la imagen de cada artículo
const SLOT_SIZE := Vector2(120, 120)
## Estante: cuántos artículos van en cada fila (de arriba hacia abajo)
## Tamaño del sprite de reroll con su precio
const REROLL_BOX_SIZE := Vector2(80, 100)
## Escala de un artículo al pasar el cursor
const SLOT_HOVER_SCALE := 1.12
## Pantalla de elección de mejora (la misma que usan las rondas)
const SELECTOR_SCENE := preload("res://escenas y recursos/rounds/upgrade_selector.tscn")
## Animaciones del NPC (sutiles: el sprite es grande). Escala al pasar el cursor, y
## "aplastado" (ancho, alto) y "rebote" al interactuar.
const NPC_HOVER_SCALE := 1.02
const NPC_SQUASH := Vector2(1.07, 0.94)
const NPC_REBOUND := Vector2(0.98, 1.03)
const GOLD := Color(1.0, 0.82, 0.3)
## Textos flotantes: el "$" al comprar (amarillo) y lo gastado en el reroll (rojo), con borde negro
const FLOAT_YELLOW := Color(1.0, 0.9, 0.15)
const FLOAT_RED := Color(1.0, 0.15, 0.15)
const FLOAT_RISE := 80.0
const FLOAT_TIME := 0.9
const RED := Color(1.0, 0.4, 0.4)

## Posición de la tienda: desplazamiento desde el CENTRO de la pantalla (negativo = a la izquierda)
var shop_position: Vector2 = Vector2(-220, 0)
## Imagen de fondo de la tienda (placeholder: el icono de Godot)
var shop_background: Texture2D = null
## Escala del fondo (1.0 = tamaño original de la imagen; el fondo nunca se recorta)
var shop_background_scale: float = 1.0
## Cuántos artículos van en cada fila del estante (de arriba hacia abajo)
var shelf_row_counts: Array[int] = [2, 3]
## Centro de cada fila: desplazamiento desde el centro del fondo
var shelf_row_positions: Array[Vector2] = [Vector2(0, -90), Vector2(0, 70)]
## Separación horizontal entre los artículos de una fila
var shelf_item_spacing: int = 18
## Puntos que cuesta apretar el botón de reroll (los configura el Shopkeeper)
var reroll_cost: int = 1
## Posición del reroll: desplazamiento desde el CENTRO de la pantalla hasta el centro de su sprite
var reroll_position: Vector2 = Vector2(-480, 0)
## Cuánto sube el precio del reroll cada vez que se usa (dura toda la run)
var reroll_cost_increase: int = 1
## Precio actual del reroll (arranca en reroll_cost). Sube solo cuando los artículos cambian.
var _reroll_current: int = 1
## Probabilidad (0 a 1) de que el frasco se atasque en cada reroll. Cada vez que los artículos
## cambian suma jam_chance_increase. Al atascarse reroll hace un último cambio y no acepta más puntos.
var jam_chance: float = 0.05
var jam_chance_increase: float = 0.01
## true cuando el frasco ya se atascó (dura toda la run)
var _jammed: bool = false
## Probabilidad (0 a 1) de que un reroll renueve todos los artículos (0.2 = 1 de cada 5)
var reroll_chance: float = 0.2
## Sprite del botón de reroll (el Shopkeeper le pasa un placeholder)
var reroll_icon: Texture2D = null
## Sprite del NPC que aparece al abrir la tienda, sus frases y cuánto dura cada una
var npc_icon: Texture2D = null
var npc_dialogs: Array[String] = []
## Tamaño en pantalla del sprite del NPC
var npc_size: Vector2 = Vector2(160, 160)
## El sprite del NPC es una hoja de frames: columnas (hframes) y filas (vframes), como en Sprite2D.
## npc_fps = frames por segundo de la animación (0 = queda quieto en el primer frame).
var npc_hframes: int = 1
var npc_vframes: int = 1
var npc_fps: float = 8.0
## Posición del NPC: desplazamiento desde el CENTRO de la pantalla hasta el centro de su sprite
var npc_position: Vector2 = Vector2(400, 120)
var dialog_time: float = 3.0
## Frases del NPC según lo que pasa en la tienda: { evento: [frases] } (las define el Shopkeeper).
## Eventos: buy, no_money, pocket_full, reroll_ok, reroll_fail, drink_chosen.
## "{item}" en una frase se reemplaza por el nombre del artículo.
var npc_lines: Dictionary = {}

var _player: Node = null
var _items: Array = []
var _slots: Dictionary = {}  # ShopItem -> {"sprite": TextureRect, "price": Label, "tween": Tween}

var _shelf_area: Control
var _points_label: Label
## Artículo del trago misterioso mientras se elige la mejora (para el "$" al volver)
var _drink_item: ShopItem = null
var _selector: UpgradeSelector = null
## true mientras el selector de mejoras del trago está abierto (el menú de la tienda se oculta)
var _selecting: bool = false
var _reroll_box: VBoxContainer
var _reroll_sprite: TextureRect
var _reroll_price: Label
var _reroll_tween: Tween
var _npc_sprite: TextureRect
var _npc_name: Label
var _npc_frames: Array[AtlasTexture] = []
var _npc_frame_time: float = 0.0
var _npc_tween: Tween
var _bubble_holder: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_id: int = 0
var _last_line: String = ""
var _tooltip: PanelContainer
var _tip_title: Label
var _tip_desc: Label
var _tip_price: Label
var _root: Control


func _ready() -> void:
	layer = 50
	visible = false
	_reroll_current = reroll_cost
	_build_ui()


func is_open() -> bool:
	return visible


## Abre la tienda para `player` con los artículos `items` (ShopItem).
func open(player: Node, items: Array) -> void:
	if visible:
		return
	_player = player
	if player.has_signal("points_changed") and not player.points_changed.is_connected(_on_points_changed):
		player.points_changed.connect(_on_points_changed)
	_reroll_sprite.texture = reroll_icon
	_update_reroll_price()
	_layout_reroll()
	_setup_npc_frames()
	_layout_npc()
	_bubble_id += 1
	_bubble.hide()
	set_items(items)
	visible = true
	player.set_net_frozen(true)


## Cambia los artículos a la venta (después de un reroll exitoso).
func set_items(items: Array) -> void:
	_items = items
	_hide_tooltip()
	_rebuild_items()
	if is_instance_valid(_player):
		_on_points_changed(_player.points)


func close() -> void:
	if not visible:
		return
	visible = false
	_hide_tooltip()
	_bubble_id += 1
	_bubble.hide()
	if is_instance_valid(_player):
		_player.set_net_frozen(false, false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _selecting and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _tooltip.visible:
		_place_tooltip()
	if visible and _npc_frames.size() > 1 and npc_fps > 0.0:
		_npc_frame_time += delta
		_npc_sprite.texture = _npc_frames[int(_npc_frame_time * npc_fps) % _npc_frames.size()]


# ---------------------------------------------------------------- Compra

func _try_buy(item: ShopItem) -> void:
	if item.sold or not is_instance_valid(_player):
		return
	if _player.points < item.price:
		_npc_event("no_money")
		return
	if item.upgrade_choices > 0:
		_buy_with_selector(item)
		return
	var custom_message := ""
	match item.kind:
		ShopItem.Kind.UPGRADE:
			var weapon = _player.get_weapon()
			item.upgrade.apply(weapon.stats, _player)
			weapon.reset()
		_:
			if item.on_buy.is_valid():
				# Objeto que se aplica al comprarlo (ej: trago misterioso)
				var result = item.on_buy.call(_player)
				if result is String and not (result as String).is_empty():
					custom_message = result
			else:
				var consumable := item.scene.instantiate() as Consumable
				if item.kind == ShopItem.Kind.CARD and consumable is CartaTarot:
					(consumable as CartaTarot).set_card(item.card_index)
				# Con el bolsillo ocupado, suelta el que tenía y se queda con el nuevo
				if not _player.add_to_pocket(consumable, true):
					consumable.free()
					_npc_event("pocket_full")
					return
	_player.spend_points(item.price)
	item.sold = true
	_mark_sold(item)
	_float_text("$", FLOAT_YELLOW, _slot_center(item))
	if custom_message.is_empty():
		_npc_event("buy", item.title)
	else:
		_npc_say(custom_message)


## Objeto que da a elegir una mejora (trago misterioso): se cobra, se oculta el menú de la tienda
## y se abre el selector de mejoras. Al elegir, se aplica la mejora y vuelve la tienda.
func _buy_with_selector(item: ShopItem) -> void:
	if _selecting:
		return
	_player.spend_points(item.price)
	item.sold = true
	_mark_sold(item)
	_selecting = true
	_drink_item = item
	_hide_tooltip()
	_root.hide()
	if _selector == null:
		_selector = SELECTOR_SCENE.instantiate() as UpgradeSelector
		add_child(_selector)
		_selector.upgrade_chosen.connect(_on_box_upgrade_chosen)
	_selector.offer(ShopPool.upgrade_options(_player, item.upgrade_choices), 0, 0,
			"%s — elegí una mejora" % item.title)


func _on_box_upgrade_chosen(upgrade: Upgrade) -> void:
	if not _selecting:
		return
	var weapon = _player.get_weapon()
	upgrade.apply(weapon.stats, _player)
	weapon.reset()
	_selecting = false
	_root.show()
	if _drink_item != null:
		_float_text("$", FLOAT_YELLOW, _slot_center(_drink_item))
		_drink_item = null
	_npc_event("drink_chosen", upgrade.title)


## Cursor sobre el sprite de reroll: crece y se ladea un poco (y muestra su info)
func _on_reroll_hover(hovering: bool) -> void:
	_animate(_reroll_sprite, hovering, 0.0, NPC_HOVER_SCALE, true)
	if hovering and _jammed:
		_show_tip("Reroll", "El frasco está trabado: no acepta más puntos.", "")
	elif hovering:
		_show_tip("Reroll",
				"Una chance de %d%% de renovar todos los artículos.\nGasta puntos aunque no salga." % roundi(reroll_chance * 100.0),
				"Precio: %d punto(s)" % _reroll_current)
	else:
		_hide_tooltip()


func _on_reroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_reroll_press()
		_on_reroll_pressed()


## Al tocarlo: la misma animación que el NPC al interactuar
func _play_reroll_press() -> void:
	_reroll_tween = _squash_tween(_reroll_sprite, _reroll_tween)


## Animación de "cursor encima" compartida (reroll y NPC)
func _animate(sprite: Control, hovering: bool, tilt: float, grow: float, is_reroll: bool) -> void:
	var tween := create_tween().set_parallel(true)
	if is_reroll:
		if _reroll_tween != null:
			_reroll_tween.kill()
		_reroll_tween = tween
	else:
		if _npc_tween != null:
			_npc_tween.kill()
		_npc_tween = tween
	tween.tween_property(sprite, "scale", Vector2.ONE * (grow if hovering else 1.0), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", tilt if hovering else 0.0, 0.12)


## Botón de reroll: siempre gasta puntos, pero solo a veces renueva los artículos.
func _on_reroll_pressed() -> void:
	if not is_instance_valid(_player):
		return
	# Frasco atascado: no acepta más puntos
	if _jammed:
		_npc_event("reroll_jammed")
		return
	var cost := _reroll_current
	if not _player.spend_points(cost):
		_npc_event("no_money")
		return
	# Sale lo gastado, en rojo, flotando desde el frasco
	_float_text("-%d" % cost, FLOAT_RED, _reroll_sprite.global_position + _reroll_sprite.size * 0.5)
	# ¿Se atasca? Reroll por última vez y se acabó
	if randf() < jam_chance:
		_jammed = true
		_update_reroll_price()
		_npc_event("reroll_jam")
		reroll_succeeded.emit()
		return
	if randf() < reroll_chance:
		# Al cambiarse los artículos sube el precio y es más probable que se atasque
		_reroll_current += reroll_cost_increase
		jam_chance = minf(jam_chance + jam_chance_increase, 1.0)
		_update_reroll_price()
		_npc_event("reroll_ok")
		reroll_succeeded.emit()
	else:
		_npc_event("reroll_fail")


## Acomoda el reroll según reroll_position (relativo al centro de la pantalla)
func _layout_reroll() -> void:
	if _reroll_box == null:
		return
	var center := get_viewport().get_visible_rect().size * 0.5 + reroll_position
	_reroll_box.position = center - REROLL_BOX_SIZE * 0.5


func _update_reroll_price() -> void:
	_reroll_price.text = "TRABADO" if _jammed else "%d pt" % _reroll_current


func _on_points_changed(points: int) -> void:
	_points_label.text = "Puntos: %d" % points
	for item: ShopItem in _slots:
		if not item.sold:
			(_slots[item]["price"] as Label).add_theme_color_override(
					"font_color", Color.WHITE if points >= item.price else RED)


func _mark_sold(item: ShopItem) -> void:
	var slot: Dictionary = _slots[item]
	var sprite := slot["sprite"] as TextureRect
	if slot["tween"] != null:
		(slot["tween"] as Tween).kill()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.scale = Vector2.ONE
	sprite.modulate = Color(1, 1, 1, 0.4)
	(slot["price"] as Label).text = "VENDIDO"
	(slot["price"] as Label).remove_theme_color_override("font_color")
	_hide_tooltip()


## Centro en pantalla de la imagen de un artículo
func _slot_center(item: ShopItem) -> Vector2:
	if not _slots.has(item):
		return get_viewport().get_visible_rect().size * 0.5
	var sprite := _slots[item]["sprite"] as TextureRect
	return sprite.global_position + sprite.size * 0.5


## Texto que sube flotando y se desvanece (con borde negro)
func _float_text(text: String, color: Color, center: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	_root.add_child(label)
	label.reset_size()
	label.position = center - label.size * 0.5
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_RISE, FLOAT_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TIME * 0.6).set_delay(FLOAT_TIME * 0.4)
	tween.chain().tween_callback(label.queue_free)


## El NPC reacciona a lo que pasa: dice una frase al azar de npc_lines[evento]
## (sin repetir la anterior). "{item}" se reemplaza por `item_name`.
func _npc_event(event: String, item_name: String = "") -> void:
	var lines: Array = npc_lines.get(event, [])
	if lines.is_empty():
		return
	var line: String = lines.pick_random()
	if lines.size() > 1:
		while line == _last_line:
			line = lines.pick_random()
	_npc_say(line.replace("{item}", item_name))


# ---------------------------------------------------------------- Interfaz

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)  # frena los clicks que irían al juego

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Correr los offsets mueve toda la tienda (el centro de la pantalla + shop_position)
	center.offset_left = shop_position.x
	center.offset_right = shop_position.x
	center.offset_top = shop_position.y
	center.offset_bottom = shop_position.y
	_root.add_child(center)

	# Sin rectángulo: en su lugar va una imagen de fondo
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(panel)
	var bg_texture: Texture2D = shop_background if shop_background != null else preload("res://icon.svg")
	# El panel mide lo que la imagen (x escala) y la imagen se muestra entera, sin recortar
	panel.custom_minimum_size = (Vector2(640, 520) if shop_background == null \
			else bg_texture.get_size() * shop_background_scale)
	var background := TextureRect.new()
	background.texture = bg_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)

	# Puntos: esquina superior derecha del fondo de la tienda
	_points_label = Label.new()
	_points_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_points_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_points_label.offset_right = -18.0
	_points_label.offset_top = 12.0
	_points_label.add_theme_font_size_override("font_size", 24)
	_points_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_points_label.add_theme_constant_override("outline_size", 6)
	background.add_child(_points_label)

	# Zona de los estantes: ocupa todo el fondo; las filas se colocan según shelf_row_positions
	_shelf_area = Control.new()
	_shelf_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shelf_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf_area.resized.connect(_layout_shelf_rows)
	background.add_child(_shelf_area)

	# Reroll: va aparte del fondo de la tienda (hijo directo de _root, no del fondo).
	# Solo un sprite (con animaciones al pasar el cursor y al tocarlo) y su precio.
	# Su posición sale de reroll_position (ver _layout_reroll).
	_reroll_box = VBoxContainer.new()
	_reroll_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reroll_box.custom_minimum_size = REROLL_BOX_SIZE
	_reroll_box.size = REROLL_BOX_SIZE
	_root.add_child(_reroll_box)
	get_viewport().size_changed.connect(_layout_reroll)
	_layout_reroll()
	var reroll_box := _reroll_box
	_reroll_sprite = TextureRect.new()
	_reroll_sprite.custom_minimum_size = Vector2(72, 72)
	_reroll_sprite.pivot_offset = Vector2(36, 72)
	_reroll_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reroll_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reroll_sprite.mouse_entered.connect(_on_reroll_hover.bind(true))
	_reroll_sprite.mouse_exited.connect(_on_reroll_hover.bind(false))
	_reroll_sprite.gui_input.connect(_on_reroll_gui_input)
	reroll_box.add_child(_reroll_sprite)
	_reroll_price = Label.new()
	_reroll_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reroll_price.add_theme_color_override("font_outline_color", Color.BLACK)
	_reroll_price.add_theme_constant_override("outline_size", 6)
	reroll_box.add_child(_reroll_price)

	_build_npc(_root)

	_build_tooltip()


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 10
	_root.add_child(_tooltip)
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
	_tip_price = _tip_label(box, 18, GOLD)


func _tip_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _rebuild_items() -> void:
	for child in _shelf_area.get_children():
		child.queue_free()
	_slots.clear()
	# Los artículos se reparten por filas (shelf_row_counts), cada una en su posición del inspector
	var index := 0
	for count: int in shelf_row_counts:
		if index >= _items.size():
			break
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", shelf_item_spacing)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shelf_area.add_child(row)
		for item: ShopItem in _items.slice(index, index + count):
			row.add_child(_make_slot(item))
			if item.sold:
				_mark_sold(item)
		index += count
	_layout_shelf_rows.call_deferred()


## Centra cada fila en su posición (shelf_row_positions, relativa al centro del fondo)
func _layout_shelf_rows() -> void:
	if _shelf_area == null or not is_instance_valid(_shelf_area):
		return
	var row_index := 0
	for row in _shelf_area.get_children():
		if row.is_queued_for_deletion() or not row is Control:
			continue
		var offset := shelf_row_positions[row_index] if row_index < shelf_row_positions.size() else Vector2.ZERO
		row.reset_size()
		row.position = _shelf_area.size * 0.5 + offset - row.size * 0.5
		row_index += 1


## Un artículo: solo la imagen (crece al pasar el cursor, click para comprar) y su precio debajo
func _make_slot(item: ShopItem) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := TextureRect.new()
	sprite.texture = item.icon
	sprite.custom_minimum_size = SLOT_SIZE
	sprite.pivot_offset = SLOT_SIZE * 0.5
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite.mouse_entered.connect(_on_slot_hover.bind(item, true))
	sprite.mouse_exited.connect(_on_slot_hover.bind(item, false))
	sprite.gui_input.connect(_on_slot_gui_input.bind(item))
	box.add_child(sprite)
	var price := Label.new()
	price.text = "%d pts" % item.price
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)
	_slots[item] = {"sprite": sprite, "price": price, "tween": null}
	return box


func _on_slot_gui_input(event: InputEvent, item: ShopItem) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_buy(item)


func _on_slot_hover(item: ShopItem, hovering: bool) -> void:
	if item.sold or not _slots.has(item):
		return
	var slot: Dictionary = _slots[item]
	var sprite := slot["sprite"] as TextureRect
	if slot["tween"] != null:
		(slot["tween"] as Tween).kill()
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE * (SLOT_HOVER_SCALE if hovering else 1.0), 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slot["tween"] = tween
	if hovering:
		_show_tooltip(item)
	else:
		_hide_tooltip()


func _show_tooltip(item: ShopItem) -> void:
	_show_tip(item.title, item.description, "Precio: %d puntos" % item.price)


func _show_tip(title: String, description: String, price: String) -> void:
	_tip_title.text = title
	_tip_desc.text = description
	_tip_price.text = price
	_tooltip.reset_size()
	_tooltip.visible = true
	_place_tooltip()


func _hide_tooltip() -> void:
	_tooltip.visible = false


## Cerca del cursor, sin salirse de la pantalla
func _place_tooltip() -> void:
	var view := get_viewport().get_visible_rect().size
	var pos := _root.get_local_mouse_position() + Vector2(20, 20)
	pos.x = clampf(pos.x, 0.0, maxf(view.x - _tooltip.size.x, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(view.y - _tooltip.size.y, 0.0))
	_tooltip.position = pos


# ---------------------------------------------------------------- NPC de la tienda

## NPC: sprite + nombre + globo de diálogo, sueltos sobre la pantalla (no dentro del panel).
## Tamaño y posición salen de npc_size y npc_position (se acomodan en _layout_npc).
func _build_npc(parent: Control) -> void:
	# Espacio reservado para el globo, justo encima del sprite
	_bubble_holder = Control.new()
	_bubble_holder.custom_minimum_size = Vector2(280, 150)
	_bubble_holder.size = Vector2(280, 150)
	_bubble_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_bubble_holder)
	_bubble = PanelContainer.new()
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_holder.add_child(_bubble)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_bubble.add_child(margin)
	_bubble_label = Label.new()
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.custom_minimum_size = Vector2(240, 0)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(_bubble_label)

	_npc_sprite = TextureRect.new()
	_npc_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc_sprite.mouse_entered.connect(_animate.bind(_npc_sprite, true, 0.0, NPC_HOVER_SCALE, false))
	_npc_sprite.mouse_exited.connect(_animate.bind(_npc_sprite, false, 0.0, 1.0, false))
	_npc_sprite.gui_input.connect(_on_npc_gui_input)
	parent.add_child(_npc_sprite)

	_npc_name = Label.new()
	_npc_name.text = "NPC"
	_npc_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_npc_name)

	get_viewport().size_changed.connect(_layout_npc)
	_layout_npc()


## Corta npc_icon en frames (hframes × vframes) para animar el NPC. Con 1×1 es una imagen común.
func _setup_npc_frames() -> void:
	_npc_frames.clear()
	_npc_frame_time = 0.0
	var columns := maxi(npc_hframes, 1)
	var rows := maxi(npc_vframes, 1)
	if npc_icon == null or columns * rows <= 1:
		_npc_sprite.texture = npc_icon
		return
	var frame_size := Vector2(npc_icon.get_width() / float(columns), npc_icon.get_height() / float(rows))
	for row in rows:
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = npc_icon
			atlas.region = Rect2(Vector2(column, row) * frame_size, frame_size)
			_npc_frames.append(atlas)
	_npc_sprite.texture = _npc_frames[0]


## Acomoda el NPC según npc_size y npc_position (relativo al centro de la pantalla).
func _layout_npc() -> void:
	if _npc_sprite == null:
		return
	var center := get_viewport().get_visible_rect().size * 0.5 + npc_position
	_npc_sprite.custom_minimum_size = npc_size
	_npc_sprite.size = npc_size
	# Pivote abajo al centro: al aplastarse queda "apoyado" en el piso
	_npc_sprite.pivot_offset = Vector2(npc_size.x * 0.5, npc_size.y)
	_npc_sprite.position = center - npc_size * 0.5
	_bubble_holder.position = Vector2(center.x - _bubble_holder.size.x * 0.5,
			_npc_sprite.position.y - _bubble_holder.size.y)
	_npc_name.size = Vector2(npc_size.x, 24.0)
	_npc_name.position = Vector2(_npc_sprite.position.x, _npc_sprite.position.y + npc_size.y)


func _on_npc_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_say_random_line()


## Al interactuar: se estira hacia los costados y se aplasta de arriba hacia abajo, rápido y sin rotar
func _play_npc_squash() -> void:
	_npc_tween = _squash_tween(_npc_sprite, _npc_tween)


## Estirar hacia los costados y aplastar, compartido por el NPC y el reroll
func _squash_tween(sprite: Control, previous: Tween) -> Tween:
	if previous != null:
		previous.kill()
	sprite.rotation = 0.0
	var tween := create_tween()
	tween.tween_property(sprite, "scale", NPC_SQUASH, 0.05) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", NPC_REBOUND, 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE * NPC_HOVER_SCALE, 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## El NPC dice una frase al azar de npc_dialogs (sin repetir la anterior)
func _say_random_line() -> void:
	if npc_dialogs.is_empty():
		return
	var line: String = npc_dialogs.pick_random()
	if npc_dialogs.size() > 1:
		while line == _last_line:
			line = npc_dialogs.pick_random()
	_npc_say(line)


## Muestra `line` en el globo del NPC y lo hace reaccionar (se achica un instante)
func _npc_say(line: String) -> void:
	_play_npc_squash()
	_last_line = line
	_bubble_label.text = line
	_bubble.reset_size()
	_bubble.show()
	_bubble_id += 1
	var id := _bubble_id
	await get_tree().process_frame
	# Pegado abajo del espacio reservado (el globo crece hacia arriba)
	_bubble.position = Vector2((_bubble_holder.size.x - _bubble.size.x) * 0.5,
			_bubble_holder.size.y - _bubble.size.y)
	await get_tree().create_timer(dialog_time).timeout
	if id == _bubble_id:
		_bubble.hide()
