class_name ShopMenu
extends CanvasLayer
## Menú de la tienda (se arma por código). Se abre con open(jugador, artículos):
## muestra los artículos con su icono y precio; al pasar el cursor por un icono aparece
## un cuadro con su nombre y descripción; al clickear se compra con los puntos del jugador.
## Esc o el botón "Salir" lo cierra. Mientras está abierto el jugador queda quieto.

signal closed
## Salió bien el reroll: el vendedor tiene que sortear artículos nuevos (set_items)
signal reroll_succeeded

const SLOT_SIZE := Vector2(120, 120)
const ICON_MAX := 96
## Filas del menú: los objetos van en la misma fila que las mejoras
const SECTIONS := [
	{"title": "MEJORAS", "kinds": [ShopItem.Kind.UPGRADE, ShopItem.Kind.OBJECT]},
	{"title": "CARTAS", "kinds": [ShopItem.Kind.CARD]},
]
## Pantalla de elección de mejora (la misma que usan las rondas)
const SELECTOR_SCENE := preload("res://escenas y recursos/rounds/upgrade_selector.tscn")
## Animaciones del NPC (sutiles: el sprite es grande). Escala al pasar el cursor, y
## "aplastado" (ancho, alto) y "rebote" al interactuar.
const NPC_HOVER_SCALE := 1.02
const NPC_SQUASH := Vector2(1.07, 0.94)
const NPC_REBOUND := Vector2(0.98, 1.03)
const GOLD := Color(1.0, 0.82, 0.3)
const RED := Color(1.0, 0.4, 0.4)

## Puntos que cuesta apretar el botón de reroll (los configura el Shopkeeper)
var reroll_cost: int = 1
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
var npc_position: Vector2 = Vector2(480, 120)
var dialog_time: float = 3.0

var _player: Node = null
var _items: Array = []
var _slots: Dictionary = {}  # ShopItem -> {"button": Button, "price": Label}

var _sections: VBoxContainer
var _points_label: Label
var _message: Label
var _selector: UpgradeSelector = null
## true mientras el selector de mejoras de la caja está abierto (el menú de la tienda se oculta)
var _selecting: bool = false
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
var _tip_kind: Label
var _tip_title: Label
var _tip_desc: Label
var _tip_price: Label
var _root: Control


func _ready() -> void:
	layer = 50
	visible = false
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
	_reroll_price.text = "%d pt" % reroll_cost
	_setup_npc_frames()
	_layout_npc()
	_bubble_id += 1
	_bubble.hide()
	set_items(items)
	_message.text = ""
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
		_player.set_net_frozen(false)
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
		_say("No te alcanzan los puntos.", RED)
		return
	if item.upgrade_choices > 0:
		_buy_with_selector(item)
		return
	var result_message := "Compraste: %s" % item.title
	match item.kind:
		ShopItem.Kind.UPGRADE:
			var weapon = _player.get_weapon()
			item.upgrade.apply(weapon.stats, _player)
			weapon.reset()
		_:
			if item.on_buy.is_valid():
				# Objeto que se aplica al comprarlo (ej: caja misteriosa)
				var result = item.on_buy.call(_player)
				if result is String and not (result as String).is_empty():
					result_message = result
			else:
				if not _player.can_take_consumable():
					_say("Tenés el bolsillo lleno (usá el consumible con Q).", RED)
					return
				var consumable := item.scene.instantiate() as Consumable
				if item.kind == ShopItem.Kind.CARD and consumable is CartaTarot:
					(consumable as CartaTarot).set_card(item.card_index)
				if not _player.add_to_pocket(consumable):
					consumable.free()
					_say("No se pudo guardar el objeto.", RED)
					return
	_player.spend_points(item.price)
	item.sold = true
	_mark_sold(item)
	_say(result_message, GOLD)


## Objeto que da a elegir una mejora (caja misteriosa): se cobra, se oculta el menú de la tienda
## y se abre el selector de mejoras. Al elegir, se aplica la mejora y vuelve la tienda.
func _buy_with_selector(item: ShopItem) -> void:
	if _selecting:
		return
	_player.spend_points(item.price)
	item.sold = true
	_mark_sold(item)
	_selecting = true
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
	_say("Elegiste: %s" % upgrade.title, GOLD)


## Cursor sobre el sprite de reroll: crece y se ladea un poco (y muestra su info)
func _on_reroll_hover(hovering: bool) -> void:
	_animate(_reroll_sprite, hovering, deg_to_rad(-10.0), 1.18, true)
	if hovering:
		_show_tip("REROLL", "Reroll",
				"Una chance de %d%% de renovar todos los artículos.\nGasta puntos aunque no salga." % roundi(reroll_chance * 100.0),
				"Precio: %d punto(s)" % reroll_cost)
	else:
		_hide_tooltip()


func _on_reroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_reroll_press()
		_on_reroll_pressed()


## Al tocarlo: se achica de golpe, rebota y da una vuelta completa
func _play_reroll_press() -> void:
	if _reroll_tween != null:
		_reroll_tween.kill()
	_reroll_sprite.rotation = 0.0
	_reroll_tween = create_tween()
	_reroll_tween.tween_property(_reroll_sprite, "scale", Vector2.ONE * 0.8, 0.06)
	_reroll_tween.tween_property(_reroll_sprite, "scale", Vector2.ONE * 1.3, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reroll_tween.parallel().tween_property(_reroll_sprite, "rotation", TAU, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reroll_tween.tween_property(_reroll_sprite, "scale", Vector2.ONE * 1.18, 0.1)
	_reroll_tween.tween_callback(func() -> void: _reroll_sprite.rotation = deg_to_rad(-10.0))


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
	if not _player.spend_points(reroll_cost):
		_say("No te alcanzan los puntos.", RED)
		return
	if randf() < reroll_chance:
		_say("¡Artículos renovados!", GOLD)
		reroll_succeeded.emit()
	else:
		_say("No hubo suerte... (te gastó %d punto%s)" % [reroll_cost, "" if reroll_cost == 1 else "s"], RED)


func _on_points_changed(points: int) -> void:
	_points_label.text = "Puntos: %d" % points
	for item: ShopItem in _slots:
		if not item.sold:
			(_slots[item]["price"] as Label).add_theme_color_override(
					"font_color", Color.WHITE if points >= item.price else RED)


func _mark_sold(item: ShopItem) -> void:
	var slot: Dictionary = _slots[item]
	(slot["button"] as Button).disabled = true
	(slot["button"] as Button).modulate = Color(1, 1, 1, 0.4)
	(slot["price"] as Label).text = "VENDIDO"
	(slot["price"] as Label).remove_theme_color_override("font_color")
	_hide_tooltip()


func _say(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


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
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "TIENDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)

	_points_label = Label.new()
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_points_label)

	box.add_child(HSeparator.new())
	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", 12)
	box.add_child(_sections)
	box.add_child(HSeparator.new())

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size = Vector2(0, 28)
	box.add_child(_message)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)

	# Reroll: solo un sprite (con animaciones al pasar el cursor y al tocarlo) y su precio
	var reroll_box := VBoxContainer.new()
	reroll_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(reroll_box)
	_reroll_sprite = TextureRect.new()
	_reroll_sprite.custom_minimum_size = Vector2(72, 72)
	_reroll_sprite.pivot_offset = Vector2(36, 36)
	_reroll_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reroll_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reroll_sprite.mouse_entered.connect(_on_reroll_hover.bind(true))
	_reroll_sprite.mouse_exited.connect(_on_reroll_hover.bind(false))
	_reroll_sprite.gui_input.connect(_on_reroll_gui_input)
	reroll_box.add_child(_reroll_sprite)
	_reroll_price = Label.new()
	_reroll_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_box.add_child(_reroll_price)

	var exit := Button.new()
	exit.text = "Salir (Esc)"
	exit.custom_minimum_size = Vector2(200, 44)
	exit.pressed.connect(close)
	buttons.add_child(exit)

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
	_tip_kind = _tip_label(box, 14, Color(0.7, 0.8, 0.9))
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
	for child in _sections.get_children():
		child.queue_free()
	_slots.clear()
	for section in SECTIONS:
		var kinds: Array = section["kinds"]
		var group := _items.filter(func(i: ShopItem) -> bool: return kinds.has(i.kind))
		if group.is_empty():
			continue
		var header := Label.new()
		header.text = section["title"]
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		_sections.add_child(header)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		_sections.add_child(row)
		for item: ShopItem in group:
			row.add_child(_make_slot(item))
			if item.sold:
				_mark_sold(item)


func _make_slot(item: ShopItem) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.icon = item.icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", ICON_MAX)
	button.pressed.connect(_try_buy.bind(item))
	button.mouse_entered.connect(_show_tooltip.bind(item))
	button.mouse_exited.connect(_hide_tooltip)
	box.add_child(button)
	var price := Label.new()
	price.text = "%d pts" % item.price
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)
	_slots[item] = {"button": button, "price": price}
	return box


func _show_tooltip(item: ShopItem) -> void:
	_show_tip(item.kind_name(), item.title, item.description, "Precio: %d puntos" % item.price)


func _show_tip(kind: String, title: String, description: String, price: String) -> void:
	_tip_kind.text = kind
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
		_play_npc_squash()
		_say_random_line()


## Al interactuar: se estira hacia los costados y se aplasta de arriba hacia abajo, rápido y sin rotar
func _play_npc_squash() -> void:
	if _npc_tween != null:
		_npc_tween.kill()
	_npc_sprite.rotation = 0.0
	_npc_tween = create_tween()
	_npc_tween.tween_property(_npc_sprite, "scale", NPC_SQUASH, 0.05) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_npc_tween.tween_property(_npc_sprite, "scale", NPC_REBOUND, 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_npc_tween.tween_property(_npc_sprite, "scale", Vector2.ONE * NPC_HOVER_SCALE, 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## El NPC dice una frase al azar de npc_dialogs (sin repetir la anterior)
func _say_random_line() -> void:
	if npc_dialogs.is_empty():
		return
	var line: String = npc_dialogs.pick_random()
	if npc_dialogs.size() > 1:
		while line == _last_line:
			line = npc_dialogs.pick_random()
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
