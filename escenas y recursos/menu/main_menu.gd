extends Control
## Menú de inicio: Un jugador, Ver lobbies, Opciones y Salir.
##  - Los botones solo responden al MOUSE (sin foco de teclado).
##  - Un botón "seleccionado" = el mouse está encima: se desliza a su lugar y se agranda.
##    Deseleccionado: se esconde un poco hacia la izquierda.
##  - La imagen de la derecha cambia según el botón seleccionado y, al deseleccionar,
##    se queda la última (arranca mostrando start_image: Band y Rene).
##    Las imágenes salen de `images_folder`, ver _resolve_option_images.
##  - Parallax con el mouse en el fondo, el logo y la imagen (los botones no tienen). El logo se mece suave.
##  - Los botones están en la misma capa que el logo (la imagen de la derecha queda por encima).

const OptionsMenu := preload("options_menu.gd")

## Escena de la sala de pruebas
@export_file("*.tscn") var practice_scene: String = "res://escenas y recursos/test_room/test_room.tscn"
## Escena del modo un jugador (la run por salas)
@export_file("*.tscn") var single_player_scene: String = "res://escenas y recursos/run/mapa_run.tscn"
## Escena de la lista de lobbies
@export_file("*.tscn") var lobby_list_scene: String = "res://escenas y recursos/menu/lobby_list.tscn"

@export_group("Imágenes de la derecha")
## Carpeta con las imágenes del menú
@export_dir var images_folder: String = "res://sprites/menu/img"
## OPCIONAL: forzar la imagen de una opción. Ej: {"practica": "res://sprites/menu/img/mi_imagen.png"}
## Ids: practica, singleplayer, lobbies, opciones, salir. Si no se indica, se busca un archivo cuyo nombre
## contenga el id (practica.png, img_lobbies.png...); si no hay, se usan las imágenes por orden alfabético.
@export var option_images: Dictionary = {}
## Centro de la imagen en pantalla (si la escena tiene un nodo "ReneBand", usa su posición)
@export var image_position: Vector2 = Vector2(846.0, 370.0)
## Imagen que se muestra al abrir el menú, antes de pasar el mouse por un botón (Band y Rene)
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg") var start_image: String = "res://sprites/menu/img/rene_band.png"
## Tamaño máximo (ancho, alto) en pantalla de las imágenes que reemplazan a la de por defecto
@export var image_box: Vector2 = Vector2(520.0, 560.0)

@export_group("Botones")
## Los botones están en la escena (nodo "Botones"): cambiales posición, tamaño, texto, fuente o estilo ahí.
## La posición X de cada botón en la escena es donde queda al SELECCIONARlo.
## Cuánto se esconden hacia la izquierda cuando no están seleccionados
@export var idle_shift: float = 50.0

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

## Cada opción busca el botón "Botones/<Id>" de la escena (Singleplayer, Lobbies, Opciones, Salir)
const OPTIONS: Array[Dictionary] = [
	{"id": "singleplayer"},
	{"id": "lobbies"},
	{"id": "opciones"},
	{"id": "salir"},
]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg"]
const IDLE_COLOR := Color(0.78, 0.78, 0.85, 0.8)

var _message_label: Label
var _buttons: Dictionary = {}        # id -> Button
var _button_tweens: Dictionary = {}  # id -> Tween
var _button_base_x: Dictionary = {}  # id -> X de la escena (posición seleccionado)
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
	_show_start_image()
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


## Imagen inicial del menú (start_image). Se queda hasta que el mouse pase por un botón.
func _show_start_image() -> void:
	if start_image.is_empty() or not ResourceLoader.exists(start_image):
		push_warning("MainMenu: no existe la imagen inicial '%s'. Revisá start_image en el Inspector." % start_image)
		return
	var texture := load(start_image) as Texture2D
	if texture != null:
		_show_image(texture, _fit_scale(texture), false)


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
	var holder := get_node_or_null("Botones") as Control
	if holder == null:
		push_warning("MainMenu: falta el nodo 'Botones' en la escena del menú.")
		return
	var shown := 0
	var last_bottom := 0.0
	for i in OPTIONS.size():
		var id: String = OPTIONS[i]["id"]
		var button := holder.get_node_or_null(id.capitalize().replace(" ", "")) as Button
		if button == null:
			push_warning("MainMenu: falta el botón 'Botones/%s' en la escena." % id.capitalize())
			continue
		var base_x := button.position.x
		_button_base_x[id] = base_x
		last_bottom = maxf(last_bottom, button.position.y + button.size.y)
		# Solo mouse: sin foco, así no se manejan con teclado ni con el mando
		button.focus_mode = Control.FOCUS_NONE
		button.position.x = base_x - idle_shift - 320.0
		button.modulate = Color(IDLE_COLOR, 0.0)
		_buttons[id] = button
		button.mouse_entered.connect(_on_button_hovered.bind(id))
		button.mouse_exited.connect(_on_button_unhovered.bind(id))
		button.pressed.connect(_on_button_pressed.bind(id))
		# Entrada: los botones se deslizan uno tras otro hasta su lugar "deseleccionado"
		var tween := create_tween().set_parallel(true)
		tween.tween_interval(0.1 * shown)
		tween.chain().tween_property(button, "position:x", base_x - idle_shift, 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(button, "modulate", IDLE_COLOR, 0.3)
		shown += 1

	_message_label = Label.new()
	_message_label.position = Vector2(100.0, last_bottom + 12.0)
	_message_label.modulate = Color(1, 0.5, 0.4)
	holder.add_child(_message_label)


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
		tween.tween_property(button, "position:x", _button_base_x[id], 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE * 1.07, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", Color.WHITE, 0.15)
	else:
		tween.tween_property(button, "position:x", _button_base_x[id] - idle_shift, 0.3) \
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
		"singleplayer":
			_go_to(single_player_scene)
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
