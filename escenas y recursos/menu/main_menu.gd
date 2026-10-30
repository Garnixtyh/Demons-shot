extends Control
## Menú de inicio: Modo práctica, Ver lobbies, Opciones y Salir.
##  - Los botones solo responden al MOUSE (sin foco de teclado).
##  - Un botón "seleccionado" = el mouse está encima: se desliza a su lugar y se agranda.
##    Deseleccionado: se esconde un poco hacia la izquierda.
##  - La imagen de la derecha cambia según el botón seleccionado y, al deseleccionar,
##    se queda la última (arranca mostrando la de "Modo práctica").
##    Las imágenes salen de `images_folder`, ver _resolve_option_images.
##  - Parallax con el mouse en el fondo, el logo y la imagen. El logo se mece suave.

const OptionsMenu := preload("options_menu.gd")

## Escena de la sala de pruebas
@export_file("*.tscn") var practice_scene: String = "res://escenas y recursos/test_room/test_room.tscn"
## Escena de la lista de lobbies
@export_file("*.tscn") var lobby_list_scene: String = "res://escenas y recursos/menu/lobby_list.tscn"

@export_group("Imágenes de la derecha")
## Carpeta con las imágenes del menú
@export_dir var images_folder: String = "res://sprites/menu/img"
## OPCIONAL: forzar la imagen de una opción. Ej: {"practica": "res://sprites/menu/img/mi_imagen.png"}
## Ids: practica, lobbies, opciones, salir. Si no se indica, se busca un archivo cuyo nombre
## contenga el id (practica.png, img_lobbies.png...); si no hay, se usan las imágenes por orden alfabético.
@export var option_images: Dictionary = {}
## Centro de la imagen en pantalla (si la escena tiene un nodo "ReneBand", usa su posición)
@export var image_position: Vector2 = Vector2(846.0, 370.0)
## Opción cuya imagen se muestra al abrir el menú
@export_enum("practica", "lobbies", "opciones", "salir") var default_option: String = "practica"
## Tamaño máximo (ancho, alto) en pantalla de las imágenes que reemplazan a la de por defecto
@export var image_box: Vector2 = Vector2(520.0, 560.0)

@export_group("Botones")
@export var buttons_x: float = 70.0
@export var buttons_top: float = 330.0
@export var button_size: Vector2 = Vector2(320.0, 54.0)
@export var button_spacing: float = 66.0
## Cuánto se esconden hacia la izquierda cuando no están seleccionados
@export var idle_shift: float = 70.0

@export_group("Logo")
## Cuánto se mece el logo (radianes a cada lado de su rotación original)
@export var logo_sway: float = 0.07
## Segundos de ir de un lado al otro
@export var logo_sway_time: float = 2.6

@export_group("Parallax (píxeles que se mueve cada capa con el mouse en el borde)")
@export var parallax_background: float = 14.0
@export var parallax_logo: float = 24.0
@export var parallax_image: float = 38.0
## Qué tan rápido sigue al mouse
@export var parallax_smoothing: float = 6.0
## El fondo se agranda un poco para que no se vean los bordes al moverse
@export var background_margin_scale: float = 1.05

const OPTIONS: Array[Dictionary] = [
	{"id": "practica", "text": "Modo práctica"},
	{"id": "lobbies", "text": "Ver lobbies"},
	{"id": "opciones", "text": "Opciones"},
	{"id": "salir", "text": "Salir"},
]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg"]
const IDLE_COLOR := Color(0.78, 0.78, 0.85, 0.8)

var _message_label: Label
var _buttons: Dictionary = {}        # id -> Button
var _button_tweens: Dictionary = {}  # id -> Tween
var _option_textures: Dictionary = {} # id -> Texture2D

var _background: Node2D
var _logo: Node2D
var _image_holder: Node2D
var _image_sprite: Sprite2D
var _shown_texture: Texture2D

var _background_base: Vector2
var _logo_base: Vector2
var _image_base: Vector2
var _parallax: Vector2 = Vector2.ZERO

var _locked: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	OptionsMenu.apply_saved()
	_setup_scene_nodes()
	_resolve_option_images()
	_build_buttons()
	_show_option_image(default_option)
	_start_logo_sway()


func _process(delta: float) -> void:
	_update_parallax(delta)


# ---------------------------------------------------------------- Escena (fondo, logo, imagen)

func _setup_scene_nodes() -> void:
	_background = get_node_or_null("FondoMenu") as Node2D
	_logo = get_node_or_null("LogoTitle") as Node2D
	var original := get_node_or_null("ReneBand") as Sprite2D
	if _background != null:
		_background.scale *= background_margin_scale
		_background_base = _background.position
	if _logo != null:
		_logo_base = _logo.position
	# La imagen de la derecha vive en un nodo propio para moverla toda junta con el parallax
	_image_holder = Node2D.new()
	_image_holder.name = "ImagenDerecha"
	add_child(_image_holder)
	_image_base = image_position
	if original != null:
		_image_base = original.position
		original.queue_free()
	_image_holder.position = _image_base


func _start_logo_sway() -> void:
	if _logo == null:
		return
	var center := _logo.rotation
	_logo.rotation = center - logo_sway
	var tween := create_tween().set_loops()
	tween.tween_property(_logo, "rotation", center + logo_sway, logo_sway_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_logo, "rotation", center - logo_sway, logo_sway_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_parallax(delta: float) -> void:
	var half := get_viewport_rect().size / 2.0
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var target := ((get_viewport().get_mouse_position() - half) / half).clampf(-1.0, 1.0)
	_parallax = _parallax.lerp(target, 1.0 - exp(-parallax_smoothing * delta))
	# Las capas se mueven al revés del mouse; las de adelante, más
	if _background != null:
		_background.position = _background_base - _parallax * parallax_background
	if _logo != null:
		_logo.position = _logo_base - _parallax * parallax_logo
	_image_holder.position = _image_base - _parallax * parallax_image


# ---------------------------------------------------------------- Imagen de la derecha

## Cambia la imagen con un fundido y un pequeño deslizamiento.
func _show_image(texture: Texture2D, sprite_scale: Vector2, animate: bool = true) -> void:
	if texture == null or texture == _shown_texture:
		return
	_shown_texture = texture
	var old := _image_sprite
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = sprite_scale
	_image_holder.add_child(sprite)
	_image_sprite = sprite
	if not animate:
		return
	sprite.modulate.a = 0.0
	sprite.position = Vector2(40.0, 0.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.25)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if old != null:
		tween.tween_property(old, "modulate:a", 0.0, 0.2)
		tween.tween_property(old, "position", Vector2(-30.0, 0.0), 0.3)
		tween.chain().tween_callback(old.queue_free)


## Muestra la imagen de una opción (si tiene).
func _show_option_image(id: String) -> void:
	if _option_textures.has(id):
		var texture: Texture2D = _option_textures[id]
		_show_image(texture, _fit_scale(texture))


func _fit_scale(texture: Texture2D) -> Vector2:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	return Vector2.ONE * minf(image_box.x / tex_size.x, image_box.y / tex_size.y)


## Busca la imagen de cada opción: 1) option_images, 2) archivo con el id en el nombre, 3) por orden.
func _resolve_option_images() -> void:
	var files := _list_images()
	for i in OPTIONS.size():
		var id: String = OPTIONS[i]["id"]
		var path := ""
		if option_images.has(id):
			path = str(option_images[id])
		if path.is_empty():
			for file in files:
				if file.get_file().to_lower().contains(id):
					path = file
					break
		if path.is_empty() and i < files.size():
			path = files[i]
		if not path.is_empty() and ResourceLoader.exists(path):
			_option_textures[id] = load(path)
		else:
			push_warning("MainMenu: no hay imagen para '%s' (carpeta %s)" % [id, images_folder])


func _list_images() -> Array[String]:
	var found := {}
	for file_name in DirAccess.get_files_at(images_folder):
		# En el juego exportado los archivos aparecen como "x.png.import" / "x.png.remap"
		var clean := file_name.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension().to_lower() in IMAGE_EXTENSIONS:
			found[images_folder.path_join(clean)] = true
	var paths: Array[String] = []
	for path in found.keys():
		paths.append(path)
	paths.sort()
	return paths


# ---------------------------------------------------------------- Botones

func _build_buttons() -> void:
	var holder := Control.new()
	holder.name = "Botones"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	for i in OPTIONS.size():
		var id: String = OPTIONS[i]["id"]
		var button := _make_button(OPTIONS[i]["text"])
		button.position = Vector2(buttons_x - idle_shift - 320.0, buttons_top + i * button_spacing)
		button.modulate = Color(IDLE_COLOR, 0.0)
		holder.add_child(button)
		_buttons[id] = button
		button.mouse_entered.connect(_on_button_hovered.bind(id))
		button.mouse_exited.connect(_on_button_unhovered.bind(id))
		button.pressed.connect(_on_button_pressed.bind(id))
		# Entrada: los botones se deslizan uno tras otro hasta su lugar "deseleccionado"
		var tween := create_tween().set_parallel(true)
		tween.tween_interval(0.1 * i)
		tween.chain().tween_property(button, "position:x", buttons_x - idle_shift, 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(button, "modulate", IDLE_COLOR, 0.3)

	_message_label = Label.new()
	_message_label.position = Vector2(buttons_x, buttons_top + OPTIONS.size() * button_spacing)
	_message_label.modulate = Color(1, 0.5, 0.4)
	holder.add_child(_message_label)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size = button_size
	button.custom_minimum_size = button_size
	button.pivot_offset = Vector2(0.0, button_size.y / 2.0)
	# Solo mouse: sin foco, así no se manejan con teclado ni con el mando
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.1, 0.02, 0.07, 0.7), Color(0.55, 0.1, 0.25)))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.35, 0.05, 0.15, 0.9), Color(1.0, 0.45, 0.2)))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.5, 0.1, 0.1, 0.95), Color(1.0, 0.7, 0.3)))
	return button


func _make_style(background: Color, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.border_width_left = 6
	style.content_margin_left = 22.0
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	return style


func _on_button_hovered(id: String) -> void:
	if _locked:
		return
	_animate_button(id, true)
	_show_option_image(id)


func _on_button_unhovered(id: String) -> void:
	# La imagen NO cambia: se queda la última que se mostró
	_animate_button(id, false)


func _animate_button(id: String, selected: bool) -> void:
	var button := _buttons[id] as Button
	if _button_tweens.has(id):
		(_button_tweens[id] as Tween).kill()
	var tween := create_tween().set_parallel(true)
	_button_tweens[id] = tween
	if selected:
		tween.tween_property(button, "position:x", buttons_x, 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE * 1.07, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", Color.WHITE, 0.15)
	else:
		tween.tween_property(button, "position:x", buttons_x - idle_shift, 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE, 0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", IDLE_COLOR, 0.25)


func _on_button_pressed(id: String) -> void:
	if _locked:
		return
	# Golpecito al hacer click
	var button := _buttons[id] as Button
	if _button_tweens.has(id):
		(_button_tweens[id] as Tween).kill()
	var tween := create_tween()
	_button_tweens[id] = tween
	tween.tween_property(button, "scale", Vector2.ONE * 0.95, 0.06)
	tween.tween_property(button, "scale", Vector2.ONE * 1.07, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match id:
		"practica":
			_go_to(practice_scene)
		"lobbies":
			_go_to(lobby_list_scene)
		"opciones":
			_open_options()
		"salir":
			get_tree().quit()


# ---------------------------------------------------------------- Opciones

func _open_options() -> void:
	_locked = true
	for id in _buttons.keys():
		_animate_button(id, false)
	var options := OptionsMenu.new()
	options.closed.connect(_on_options_closed)
	add_child(options)


func _on_options_closed() -> void:
	_locked = false


func _go_to(path: String) -> void:
	if not ResourceLoader.exists(path):
		_message_label.text = "No se encontró la escena:\n%s" % path
		push_warning("MainMenu: no existe la escena '%s'. Revisá la ruta en el Inspector." % path)
		return
	get_tree().change_scene_to_file(path)
