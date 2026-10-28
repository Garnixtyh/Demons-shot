extends CanvasLayer
## Autoload "CrtOverlay": aplica crt.gdshader a TODO el juego (menús, lobbys y partida).
## F3 activa o desactiva el efecto.

## Ruta del shader (cambiala si lo guardás en otra carpeta)
@export var shader_path: String = "res://shaders/crt.gdshader"
@export var toggle_key: Key = KEY_F3

var _rect: ColorRect
var _material: ShaderMaterial


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
	if _material != null and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == toggle_key:
		set_enabled(not _material.get_shader_parameter("crt_enabled"))


func set_enabled(value: bool) -> void:
	if _material != null:
		_material.set_shader_parameter("crt_enabled", value)
