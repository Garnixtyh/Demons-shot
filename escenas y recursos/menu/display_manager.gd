extends Node
## Autoload "DisplayManager": pantalla completa / ventana con Alt + Enter.
##
## El juego siempre se dibuja con el tamaño base del proyecto (el de Proyecto >
## Configuración > Pantalla > Ventana > Tamaño del viewport). Si la ventana o la pantalla
## tienen otra proporción, la imagen se escala SIN deformarse y quedan barras negras
## (como en las películas). Las escenas no cambian de tamaño.

## Color de las barras
const BAR_COLOR := Color(0.0, 0.0, 0.0)

var _windowed_size: Vector2i
var _windowed_position: Vector2i


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(BAR_COLOR)
	var window := get_window()
	var base_size := Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
			ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	window.content_scale_size = base_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_windowed_size = window.size
	_windowed_position = window.position


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.alt_pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	return get_window().mode == Window.MODE_FULLSCREEN


func toggle_fullscreen() -> void:
	var window := get_window()
	if is_fullscreen():
		window.mode = Window.MODE_WINDOWED
		window.size = _windowed_size
		window.position = _windowed_position
	else:
		_windowed_size = window.size
		_windowed_position = window.position
		window.mode = Window.MODE_FULLSCREEN
