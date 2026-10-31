extends Control
## Sala de espera en red. Muestra la config del lobby (LobbyConfig.current) y los dos equipos,
## con los jugadores que manda LanNetwork. El host puede empezar; cualquiera puede cambiar de equipo.

@export_file("*.tscn") var lobby_list_scene: String = "res://escenas y recursos/menu/lobby_list.tscn"
@export var background_color: Color = Color(0.16, 0.0, 0.237, 0.621)

@export_group("Fondo y parallax (igual que el menú principal)")
## Imagen de fondo (la misma de la lista de lobbies)
@export var background_texture: Texture2D = preload("res://escenas y recursos/menu/fondo.png")
## Píxeles que se mueve el fondo con el mouse en el borde de la pantalla (0 = sin parallax)
@export var parallax_background: float = 14.0
@export var parallax_smoothing: float = 6.0
## El fondo se agranda un poco para que no se vean los bordes al moverse
@export var background_margin_scale: float = 1.05

@export_group("Selector de personajes")
## En qué parte de la pantalla va el selector (esquina, centro, borde...)
@export var selector_anchor: Control.LayoutPreset = Control.PRESET_BOTTOM_RIGHT
## Separación (px) del selector respecto a ese borde/esquina
@export var selector_margin: int = 40
## Ajuste fino extra en píxeles (x → derecha, y → abajo). Con esto lo movés a donde quieras
@export var selector_offset: Vector2 = Vector2.ZERO
## Cuánto (px) se mueven las flechas hacia afuera mientras esperan (0 = quietas)
@export var arrow_bob_distance: float = 5.0
## Segundos que dura cada ida y vuelta de ese movimiento
@export var arrow_bob_time: float = 0.6

const TEAM_NAMES := ["ROJO", "AZUL"]
const TEAM_COLORS := [Color(1.0, 0.4, 0.4), Color(0.4, 0.6, 1.0)]

var config: LobbyConfig

var _team_boxes: Array[VBoxContainer] = []
var _start_button: Button
var _message_label: Label
var _selector_icon: TextureRect
var _selector_name: Label
var _shown_character: String = ""
var _fondo: Sprite2D
var _parallax: MenuParallax
var _last_step: int = 1

## Flechas del selector de personajes. Para usar las tuyas, poné estos archivos en la carpeta
## (la izquierda es opcional: si no existe se usa la derecha espejada). Si no hay ninguna, se dibuja un placeholder.
const ARROW_RIGHT_PATH := CharacterRoster.ICON_FOLDER + "flecha_derecha.png"
const ARROW_LEFT_PATH := CharacterRoster.ICON_FOLDER + "flecha_izquierda.png"
const SELECTOR_ICON_SIZE := Vector2(110, 92)
const ARROW_SIZE := Vector2(40, 40)
## Animación de las flechas: cuántos px se mueven en reposo y cuánto tarda cada vaivén (s)
const ARROW_NUDGE := 5.0
const ARROW_IDLE_TIME := 0.5


func _ready() -> void:
	if not LanNetwork.in_lobby:
		# Abriste la escena sola para probarla: hostea un lobby de prueba
		var test_config := LobbyConfig.new()
		test_config.lobby_name = "Lobby de prueba"
		test_config.map_name = LobbyConfig.MAPS.keys()[0]
		LanNetwork.host_lobby(test_config)
	config = LobbyConfig.current
	_build_ui()
	_refresh_slots()
	_refresh_selector()
	LanNetwork.players_changed.connect(_refresh_slots)
	LanNetwork.players_changed.connect(_refresh_selector)
	LanNetwork.left_lobby.connect(func(_reason: String) -> void: _go_to_lobby_list())


func _refresh_slots() -> void:
	var my_id := multiplayer.get_unique_id()
	for team in 2:
		var box := _team_boxes[team]
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		var members: Array = []
		for id in LanNetwork.players.keys():
			var p: Dictionary = LanNetwork.players[id]
			if int(p["team"]) == team:
				var label := str(p["name"])
				if id == 1:
					label += "  (host)"
				label += "  [%s]" % CharacterRoster.display_name(LanNetwork.character_of(id))
				if id == my_id:
					label += "  ← vos"
				members.append(label)
		for i in config.team_size:
			var slot := Label.new()
			if i < members.size():
				slot.text = members[i]
			else:
				slot.text = "(vacío)"
				slot.modulate = Color(1, 1, 1, 0.4)
			slot.custom_minimum_size = Vector2(240, 36)
			box.add_child(slot)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_parallax_background()

	var background := ColorRect.new()
	background.color = background_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	# Encabezado: nombre del lobby + nombre del jugador editable
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var title := Label.new()
	title.text = "%s  (%s)" % [config.lobby_name, config.team_label()]
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var name_label := Label.new()
	name_label.text = "Tu nombre:"
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_label)

	var name_edit := PlayerNameEdit.new()
	name_edit.custom_minimum_size = Vector2(200, 36)
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_edit)

	# Resumen de la configuración
	var summary := Label.new()
	summary.modulate = Color(1, 1, 1, 0.75)
	summary.text = "Mapa: %s   |   Puntos por ronda: %d   |   Rondas para ganar: %d   |   Mejoras por ronda: %d   |   Rerolls: %d" % [
		config.map_name, config.points_to_win_round, config.rounds_to_win,
		config.upgrades_per_round, config.rerolls,
	]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	if multiplayer.is_server():
		var ip_label := Label.new()
		ip_label.modulate = Color(1, 1, 1, 0.5)
		ip_label.text = "Tu IP en la red (para entrar por IP directa): %s" % LanNetwork.get_lan_ip()
		box.add_child(ip_label)

	# Equipos
	var teams := HBoxContainer.new()
	teams.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teams.alignment = BoxContainer.ALIGNMENT_CENTER
	teams.add_theme_constant_override("separation", 60)
	box.add_child(teams)

	for team in 2:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		teams.add_child(column)

		var team_title := Label.new()
		team_title.text = TEAM_NAMES[team]
		team_title.add_theme_font_size_override("font_size", 24)
		team_title.modulate = TEAM_COLORS[team]
		team_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(team_title)

		var slots := VBoxContainer.new()
		slots.add_theme_constant_override("separation", 6)
		column.add_child(slots)
		_team_boxes.append(slots)

	_message_label = Label.new()
	_message_label.modulate = Color(1, 0.5, 0.4)
	box.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	var leave_button := Button.new()
	leave_button.text = "Salir"
	leave_button.custom_minimum_size = Vector2(140, 44)
	leave_button.pressed.connect(_on_leave_pressed)
	buttons.add_child(leave_button)

	var switch_button := Button.new()
	switch_button.text = "Cambiar de equipo"
	switch_button.custom_minimum_size = Vector2(180, 44)
	switch_button.pressed.connect(LanNetwork.request_switch_team)
	buttons.add_child(switch_button)

	_start_button = Button.new()
	_start_button.custom_minimum_size = Vector2(180, 44)
	_start_button.pressed.connect(_on_start_pressed)
	if multiplayer.is_server():
		_start_button.text = "Empezar"
	else:
		_start_button.text = "Esperando al host..."
		_start_button.disabled = true
	buttons.add_child(_start_button)

	_build_character_selector()


# ---------------------------------------------------------------- Fondo con parallax

func _build_parallax_background() -> void:
	if background_texture == null:
		return
	_fondo = Sprite2D.new()
	_fondo.name = "Fondo"
	_fondo.texture = background_texture
	add_child(_fondo)
	_fit_background()
	resized.connect(_fit_background)
	if parallax_background > 0.0:
		_parallax = MenuParallax.new()
		_parallax.smoothing = parallax_smoothing
		add_child(_parallax)
		_parallax.add_layer(_fondo, parallax_background)


## El fondo cubre toda la pantalla (con un margen para el parallax) y queda centrado.
func _fit_background() -> void:
	if _fondo == null:
		return
	var view := size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
	var tex := background_texture.get_size()
	_fondo.scale = Vector2.ONE * maxf(view.x / tex.x, view.y / tex.y) * background_margin_scale
	_fondo.position = view / 2.0
	if _parallax != null:
		_parallax.rebase(_fondo, _fondo.position)


# ---------------------------------------------------------------- Selector de personaje (esquina derecha)

func _build_character_selector() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	row.add_child(_make_arrow_button(-1))

	_selector_icon = TextureRect.new()
	_selector_icon.custom_minimum_size = SELECTOR_ICON_SIZE
	_selector_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selector_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_selector_icon)

	row.add_child(_make_arrow_button(1))

	_selector_name = Label.new()
	_selector_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_selector_name)

	# La posición se aplica con todo ya armado (así el tamaño del selector es el real)
	panel.set_anchors_and_offsets_preset(selector_anchor, Control.PRESET_MODE_MINSIZE, selector_margin)
	panel.position += selector_offset


func _make_arrow_button(step: int) -> Control:
	# La flecha va dentro de un Control fijo: así se puede mover/escalar sin pelear con el contenedor
	var holder := Control.new()
	holder.custom_minimum_size = ARROW_SIZE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var button := TextureButton.new()
	button.texture_normal = _arrow_texture(step)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.size = ARROW_SIZE
	button.pivot_offset = ARROW_SIZE / 2.0
	button.set_meta("step", step)
	button.pressed.connect(_on_arrow_pressed.bind(step, button))
	button.mouse_entered.connect(_arrow_hover.bind(button))
	button.mouse_exited.connect(_arrow_idle.bind(button))
	holder.add_child(button)
	_arrow_idle(button)
	return holder


func _set_arrow_tween(button: Control, tween: Tween) -> void:
	if button.has_meta("tween"):
		var old = button.get_meta("tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	button.set_meta("tween", tween)


## Reposo: la flecha "empuja" suavemente hacia el lado al que apunta.
func _arrow_idle(button: Control) -> void:
	var step: int = button.get_meta("step", 1)
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "position:x", ARROW_NUDGE * step, ARROW_IDLE_TIME)
	tween.tween_property(button, "position:x", 0.0, ARROW_IDLE_TIME)
	var settle := create_tween().set_parallel()
	settle.tween_property(button, "scale", Vector2.ONE, 0.1)
	settle.tween_property(button, "modulate", Color.WHITE, 0.1)
	_set_arrow_tween(button, tween)


## Mouse encima: crece un poco y se ilumina.
func _arrow_hover(button: Control) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(button, "position:x", 0.0, 0.1)
	tween.tween_property(button, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.35, 1.35, 1.35), 0.1)
	_set_arrow_tween(button, tween)


## Click: se aplasta y rebota.
func _arrow_press(button: Control) -> void:
	var step: int = button.get_meta("step", 1)
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(0.75, 0.75), 0.06)
	tween.parallel().tween_property(button, "position:x", ARROW_NUDGE * step, 0.06)
	tween.tween_property(button, "scale", Vector2(1.25, 1.25), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "position:x", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		if not button.is_hovered():
			_arrow_idle(button))
	_set_arrow_tween(button, tween)


func _on_arrow_pressed(step: int, button: Control) -> void:
	_arrow_press(button)
	_last_step = step
	var my_id := multiplayer.get_unique_id()
	var next := CharacterRoster.step_id(LanNetwork.character_of(my_id), step)
	PlayerProfile.character = next
	LanNetwork.request_set_character(next)
	_refresh_selector()  # se ve al instante; el host lo confirma enseguida


func _refresh_selector() -> void:
	if _selector_icon == null:
		return
	var id := LanNetwork.character_of(multiplayer.get_unique_id())
	_selector_icon.texture = CharacterRoster.icon(id)
	_selector_name.text = CharacterRoster.display_name(id)
	if id != _shown_character:
		if not _shown_character.is_empty():
			_animate_selector_change()
		_shown_character = id


## El icono nuevo "entra" desde el lado de la flecha: aparece girado y chico, y se acomoda con rebote.
func _animate_selector_change() -> void:
	_selector_icon.pivot_offset = SELECTOR_ICON_SIZE / 2.0
	_selector_icon.scale = Vector2(0.6, 0.6)
	_selector_icon.rotation = deg_to_rad(12.0 * _last_step)
	_selector_icon.modulate.a = 0.0
	_selector_name.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_selector_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_selector_icon, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_selector_icon, "modulate:a", 1.0, 0.15)
	tween.tween_property(_selector_name, "modulate:a", 1.0, 0.25)


## Flecha derecha (step > 0) o izquierda (step < 0): tu sprite si existe, si no un triángulo placeholder.
func _arrow_texture(step: int) -> Texture2D:
	if step < 0 and ResourceLoader.exists(ARROW_LEFT_PATH):
		return load(ARROW_LEFT_PATH)
	var right: Image
	if ResourceLoader.exists(ARROW_RIGHT_PATH):
		right = (load(ARROW_RIGHT_PATH) as Texture2D).get_image()
	else:
		right = _placeholder_arrow()
	if step < 0:
		right.flip_x()
	return ImageTexture.create_from_image(right)


func _placeholder_arrow() -> Image:
	var px := 64
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			# Triángulo apuntando a la derecha
			var half := (px / 2.0) * (1.0 - float(x) / px)
			if x >= 8 and absf(y - px / 2.0) <= half:
				image.set_pixel(x, y, Color(1, 1, 1, 0.9))
	return image


func _on_leave_pressed() -> void:
	LanNetwork.leave()
	_go_to_lobby_list()


func _go_to_lobby_list() -> void:
	if ResourceLoader.exists(lobby_list_scene):
		get_tree().change_scene_to_file(lobby_list_scene)
	else:
		push_warning("WaitingRoom: no existe la escena '%s'." % lobby_list_scene)


func _on_start_pressed() -> void:
	var err := LanNetwork.start_game()
	if err == ERR_FILE_NOT_FOUND:
		_message_label.text = "No se encontró el mapa:\n%s\n(revisá LobbyConfig.MAPS)" % config.map_path()
	elif err != OK:
		_message_label.text = "No se pudo empezar la partida (error %d)." % err
