extends CanvasLayer
## Autoload "CrtOverlay": aplica crt.gdshader a TODO el juego (menús, lobbys y partida).
## F3 activa o desactiva el CRT, F4 la estática (líneas que se mueven, ruido y viñeta).

## Ruta del shader (cambiala si lo guardás en otra carpeta)
@export var shader_path: String = "res://shaders/crt.gdshader"
@export var toggle_key: Key = KEY_F3
@export var static_toggle_key: Key = KEY_F4

var _rect: ColorRect
var _material: ShaderMaterial
var _crt_on: bool = true
var _static_on: bool = true


func _ready() -> void:
	layer = 100  # encima de todo
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(shader_path):
		push_warning("CrtOverlay: no encontré el shader '%s'. Revisá shader_path." % shader_path)
		return
	_material = ShaderMaterial.new()
	_material.shader = load(shader_path)
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no tapa los clics
	add_child(_rect)


func _unhandled_input(event: InputEvent) -> void:
	if _material == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == toggle_key:
		set_enabled(not _crt_on)
	elif event.keycode == static_toggle_key:
		set_static_enabled(not _static_on)


func set_enabled(value: bool) -> void:
	_crt_on = value
	if _material != null:
		_material.set_shader_parameter("crt_enabled", value)


func set_static_enabled(value: bool) -> void:
	_static_on = value
	if _material != null:
		_material.set_shader_parameter("static_enabled", value)
