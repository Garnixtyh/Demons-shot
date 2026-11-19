extends Control
## Una carta de mejora. Se arma con setup(upgrade, índice) y avisa con `chosen`
## cuando se la clickea. Sus animaciones las maneja el AnimationPlayer de la escena
## (upgrade_card_animator.gd): "entrada", "seleccion" y "salida".
##
## Cartas propias (por ejemplo la de un personaje): hacé una escena heredada de
## upgrade_card.tscn y cambiá `card_color`, el sprite de la carta o lo que quieras.

signal chosen

## Color de fondo de la carta (cuando no hay sprite de carta)
@export var card_color: Color = Color(0.15, 0.17, 0.23)
## Tamaño del icono de la mejora en píxeles
@export var icon_size: float = 110.0
## Icono que se usa si la mejora no tiene PNG (o el archivo no existe)
@export var fallback_icon: Texture2D = preload("res://icon.svg")

## Capa de física de la zona de la carta (solo la usa el mouse; nada más la detecta)
const AREA_LAYER := 1 << 19

var _interactive: bool = false
var _locked: bool = false
var _hovered: bool = false

@onready var _body: Control = $Body
## Zona interactiva (Area2D + CollisionShape2D, nodo "Body/Colision"): el mouse la detecta con la física 2D.
## Se mueve y escala junto con la carta, así que sigue a la animación.
var _area: Area2D
var _shape: CollisionShape2D
## Opcional: si la escena no tiene el nodo Fondo (Panel), simplemente no se usa
@onready var _panel: Panel = get_node_or_null("Body/Fondo") as Panel
@onready var _card_sprite: Sprite2D = $Body/SpriteCarta
@onready var _category: Label = $Body/Margin/VBox/Categoria
@onready var _icon_area: Control = $Body/Margin/VBox/IconoArea
@onready var _icon: Sprite2D = $Body/Margin/VBox/IconoArea/Icono
@onready var _title: Label = $Body/Margin/VBox/Titulo
@onready var _description: Label = $Body/Margin/VBox/Descripcion
@onready var _key: Label = $Body/Margin/VBox/Tecla
@onready var _animator: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_apply_style()
	# El mouse lo maneja el Area2D, no el rectángulo del Control
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_area()
	# Invisible hasta que empiece la animación de entrada
	_body.modulate.a = 0.0
	_body.resized.connect(_layout)
	_icon_area.resized.connect(_layout)
	_layout.call_deferred()


## Completa la carta con los datos de la mejora.
func setup(upgrade: Upgrade, index: int) -> void:
	_category.text = upgrade.category_name()
	_title.text = upgrade.title
	_description.text = upgrade.description
	_key.text = "[%d]" % (index + 1)
	var texture: Texture2D = null
	if not upgrade.icon_path.is_empty() and ResourceLoader.exists(upgrade.icon_path):
		texture = load(upgrade.icon_path) as Texture2D
	_icon.texture = texture if texture != null else fallback_icon
	_layout()


## Empieza la animación de entrada (con una demora opcional).
func play_enter(delay: float = 0.0) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_start_enter)
	else:
		_start_enter()


## Animación de salida (carta no elegida). Devuelve cuánto dura.
func play_exit() -> float:
	_locked = true
	_animator.play(&"salida")
	return _animator.get_animation(&"salida").length


## La carta elegida queda en su pose de selección.
func play_selected() -> void:
	_locked = true
	_animator.play(&"seleccion")


func _start_enter() -> void:
	if _locked:
		return
	_animator.play(&"entrada")
	_animator.animation_finished.connect(_on_enter_finished, CONNECT_ONE_SHOT)


func _on_enter_finished(_animation: StringName) -> void:
	if _locked:
		return
	_interactive = true
	if _hovered:
		_animator.play(&"seleccion")


## Busca el Area2D "Body/Colision" de la escena; si la escena no lo tiene, lo crea.
func _setup_area() -> void:
	_area = get_node_or_null("Body/Colision") as Area2D
	if _area == null:
		_area = Area2D.new()
		_area.name = "Colision"
		_body.add_child(_area)
		_shape = CollisionShape2D.new()
		_shape.name = "Forma"
		_shape.shape = RectangleShape2D.new()
		_area.add_child(_shape)
	else:
		_shape = _area.get_node_or_null("Forma") as CollisionShape2D
	_area.input_pickable = true
	_area.collision_layer = AREA_LAYER
	_area.collision_mask = 0
	_area.monitoring = false
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	_area.input_event.connect(_on_area_input_event)


func _on_mouse_entered() -> void:
	_hovered = true
	if _interactive and not _locked:
		_animator.play(&"seleccion")


func _on_mouse_exited() -> void:
	_hovered = false
	if _interactive and not _locked:
		_animator.play_backwards(&"seleccion")


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _interactive and not _locked and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit()


func _apply_style() -> void:
	if _panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = card_color
	style.border_color = card_color.lightened(0.45)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", style)


## Centra los sprites dentro de la carta y ajusta su tamaño.
func _layout() -> void:
	_body.pivot_offset = _body.size / 2.0
	# La zona del mouse cubre toda la carta
	if _shape != null and _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = _body.size
		_shape.position = _body.size / 2.0
	_card_sprite.position = _body.size / 2.0
	if _card_sprite.texture != null:
		_card_sprite.scale = _body.size / _card_sprite.texture.get_size()
	_icon.position = _icon_area.size / 2.0
	if _icon.texture != null:
		var texture_size := _icon.texture.get_size()
		_icon.scale = Vector2.ONE * icon_size / maxf(texture_size.x, texture_size.y)
