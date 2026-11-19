extends CanvasLayer
## Autoload "TwixelOverlay": aplica twixel.gdshader a TODO el juego (menús, lobbys y partida).
## F5 activa o desactiva el efecto. Se dibuja debajo del CRT (que está en la capa 100).

## Ruta del shader (cambiala si lo guardás en otra carpeta)
@export var shader_path: String = "res://shaders/twixel.gdshader"
@export var toggle_key: Key = KEY_F5
@export var start_enabled: bool = true
## Imagen con los colores de la paleta (opcional). Si la asignás, se activa la cuantización.
@export var palette: Texture2D

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 99  # encima del juego, debajo del CRT
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(shader_path):
		push_warning("TwixelOverlay: no encontré el shader '%s'. Revisá shader_path." % shader_path)
		return
	_material = ShaderMaterial.new()
	_material.shader = load(shader_path)
	if palette != null:
		_material.set_shader_parameter("palette_texture", palette)
		_material.set_shader_parameter("quantize", true)
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no tapa los clics
	_rect.visible = start_enabled
	add_child(_rect)


func _unhandled_input(event: InputEvent) -> void:
	if _rect != null and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == toggle_key:
		_rect.visible = not _rect.visible


func set_enabled(value: bool) -> void:
	if _rect != null:
		_rect.visible = value
