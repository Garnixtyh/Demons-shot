class_name AnimationManager
extends AnimationPlayer
## TEMPLATE del manejador de animaciones del jugador.
##
## - Elige la animación según el estado del jugador: idle, walk, jump o fall.
## - Da vuelta TODO el personaje (nodo Visuals) según hacia dónde mira.
## - Si falta alguna animación, crea una de reemplazo (placeholder) que anima
##   el nodo Body con estiramientos, rebote e inclinación.
##
## Para usar tus propios sprites:
##   1. Reemplazá el contenido de Visuals/Body por tu AnimatedSprite2D o Sprite2D.
##   2. Creá en este AnimationPlayer animaciones con los mismos nombres
##      ("idle", "walk", "jump", "fall"). Las que ya existan NO se pisan.
##   3. El resto (elegir animación y dar vuelta al personaje) sigue funcionando igual.
##
## Estructura esperada (hijos del jugador):
##   Player (CharacterBody2D)
##   ├─ Visuals (Node2D)      <- se da vuelta con scale.x = 1 / -1
##   │   └─ Body (Node2D)     <- lo animan los placeholders
##   └─ AnimationPlayer       <- este script

const IDLE := &"idle"
const WALK := &"walk"
const JUMP := &"jump"
const FALL := &"fall"
## Variantes del esquive. Una se elige al azar en cada esquive. Podés sumar más
## creando en el AnimationPlayer "dash4", "dash5"... (se detectan solas).
const DASH_1 := &"dash1"
const DASH_2 := &"dash2"
const DASH_3 := &"dash3"

## Nodo que se da vuelta (ruta relativa a este nodo)
@export var visuals_path: NodePath = ^"../Visuals"
## Nombre del nodo hijo de Visuals que animan los placeholders
@export var body_name: String = "Body"
## true = mira hacia donde apunta el mouse (como el arma va dentro de Visuals,
## es lo que se ve bien); false = mira hacia donde camina
@export var face_aim_direction: bool = true
## Velocidad horizontal mínima para considerar que está caminando
@export var walk_threshold: float = 20.0
## Diferencia mínima para cambiar de lado (evita girar por movimientos mínimos)
@export var facing_deadzone: float = 5.0

## 1 = derecha, -1 = izquierda
var facing: int = 1

var _player: CharacterBody2D
var _visuals: Node2D
var _body: Node2D
## Pose original de Body (para devolverlo a su lugar al terminar el esquive)
var _body_rest: Vector2
## Nombres de las animaciones de esquive disponibles (dash1, dash2, ...)
var _dash_names: Array = []
var _was_dashing: bool = false


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	_visuals = get_node(visuals_path) as Node2D
	_body = _visuals.get_node(NodePath(body_name)) as Node2D
	_body_rest = _body.position
	playback_default_blend_time = 0.08
	# Corre antes que el arma, así ella apunta con el personaje ya dado vuelta
	process_priority = -10
	_create_missing_animations()
	_collect_dash_animations()
	play(IDLE)


func _process(_delta: float) -> void:
	if _player.is_dead:
		return
	# En red, hacia dónde mira un jugador remoto llega replicado (Visuals:scale):
	# no se calcula con TU mouse
	if _player.is_multiplayer_authority():
		_update_facing()
	_update_animation()


func _update_facing() -> void:
	var direction: float
	if face_aim_direction:
		direction = _player.get_global_mouse_position().x - _player.global_position.x
	else:
		direction = _player.velocity.x
	if absf(direction) > facing_deadzone:
		facing = 1 if direction > 0.0 else -1
	# Se da vuelta todo el personaje de una vez
	_visuals.scale.x = facing


## Un jugador remoto no se mueve con física en esta PC, así que is_on_floor() no sirve:
## se usa el valor que replica su dueño.
func _is_grounded() -> bool:
	if _player.is_multiplayer_authority():
		return _player.is_on_floor()
	if "net_on_floor" in _player:
		return _player.net_on_floor
	return _player.is_on_floor()


## Elige al azar cuál animación de esquive usar (devuelve su índice). La llama el jugador.
func pick_dash_variant() -> int:
	if _dash_names.is_empty():
		return 0
	return randi() % _dash_names.size()


## true mientras el jugador está en pleno esquive (dueño o copia de red).
func _is_dash_active() -> bool:
	return "net_dashing" in _player and _player.net_dashing and not _dash_names.is_empty()


func _update_animation() -> void:
	# Esquive: se reproduce la variante elegida (dash1, dash2, ...) una sola vez
	if _is_dash_active():
		if not _was_dashing:
			_was_dashing = true
			var index := clampi(int(_player.get("net_dash_variant")), 0, _dash_names.size() - 1)
			play(_dash_names[index], 0.02)
		return
	if _was_dashing:
		_was_dashing = false
		_reset_body()

	var next: StringName
	if not _is_grounded():
		next = JUMP if _player.velocity.y < 0.0 else FALL
	elif absf(_player.velocity.x) > walk_threshold:
		next = WALK
	else:
		next = IDLE

	if next != StringName(current_animation):
		play(next)

	# La caminata se acelera o frena según la velocidad real
	


# ---------------------------------------------------------------------------
# Animaciones de reemplazo (solo se crean si no existen)
# ---------------------------------------------------------------------------

func _create_missing_animations() -> void:
	var rest := _body.position
	var body_path := str(get_node(root_node).get_path_to(_body))
	var library := _get_default_library()

	# Solo los que tienen esquive (el jugador); por ejemplo Panchu no lo usa
	if "net_dashing" in _player:
		_create_missing_dash_animations(library, body_path, rest)

	if not library.has_animation(IDLE):
		library.add_animation(IDLE, _make_animation(1.2, true, body_path, {
			"scale": [[0.0, Vector2(1, 1)], [0.6, Vector2(1.02, 1.05)], [1.2, Vector2(1, 1)]],
			"rotation": [[0.0, 0.0], [1.2, 0.0]],
			"position": [[0.0, rest], [1.2, rest]],
		}))

	if not library.has_animation(WALK):
		var bob := rest + Vector2(0, -4)
		library.add_animation(WALK, _make_animation(0.5, true, body_path, {
			"scale": [
				[0.0, Vector2(1, 1)], [0.125, Vector2(0.96, 1.04)], [0.25, Vector2(1, 1)],
				[0.375, Vector2(0.96, 1.04)], [0.5, Vector2(1, 1)],
			],
			"rotation": [[0.0, 0.08], [0.25, -0.08], [0.5, 0.08]],
			"position": [
				[0.0, rest], [0.125, bob], [0.25, rest], [0.375, bob], [0.5, rest],
			],
		}))

	if not library.has_animation(JUMP):
		library.add_animation(JUMP, _make_animation(0.2, false, body_path, {
			"scale": [[0.0, Vector2(1, 1)], [0.1, Vector2(0.85, 1.2)], [0.2, Vector2(0.85, 1.2)]],
			"rotation": [[0.0, 0.0], [0.2, 0.0]],
			"position": [[0.0, rest], [0.2, rest]],
		}))

	if not library.has_animation(FALL):
		library.add_animation(FALL, _make_animation(0.3, false, body_path, {
			"scale": [[0.0, Vector2(0.85, 1.2)], [0.15, Vector2(1.08, 0.94)], [0.3, Vector2(1.08, 0.94)]],
			"rotation": [[0.0, 0.0], [0.3, 0.05]],
			"position": [[0.0, rest], [0.3, rest]],
		}))


## Placeholders del esquive (duran lo mismo que el esquive). Si creás tus propias
## "dash1", "dash2"... en el AnimationPlayer, estas NO se crean.
func _create_missing_dash_animations(library: AnimationLibrary, body_path: String, rest: Vector2) -> void:
	var length: float = 0.18
	if "dash_duration" in _player:
		length = maxf(float(_player.get("dash_duration")), 0.05)
	var t1 := length * 0.2
	var t2 := length * 0.75

	# dash1: se estira y se inclina hacia adelante
	if not library.has_animation(DASH_1):
		library.add_animation(DASH_1, _make_animation(length, false, body_path, {
			"scale": [[0.0, Vector2(1, 1)], [t1, Vector2(1.35, 0.8)], [t2, Vector2(1.35, 0.8)], [length, Vector2(1, 1)]],
			"rotation": [[0.0, 0.0], [t1, 0.3], [t2, 0.3], [length, 0.0]],
			"position": [[0.0, rest], [length, rest]],
		}))

	# dash2: pequeño salto con un giro completo
	if not library.has_animation(DASH_2):
		library.add_animation(DASH_2, _make_animation(length, false, body_path, {
			"scale": [[0.0, Vector2(1, 1)], [length * 0.5, Vector2(0.85, 0.85)], [length, Vector2(1, 1)]],
			"rotation": [[0.0, 0.0], [length, TAU]],
			"position": [[0.0, rest], [length * 0.5, rest + Vector2(0, -12)], [length, rest]],
		}))

	# dash3: se agacha y se desliza, inclinado hacia atrás
	if not library.has_animation(DASH_3):
		library.add_animation(DASH_3, _make_animation(length, false, body_path, {
			"scale": [[0.0, Vector2(1, 1)], [t1, Vector2(1.4, 0.6)], [t2, Vector2(1.4, 0.6)], [length, Vector2(1, 1)]],
			"rotation": [[0.0, 0.0], [t1, -0.12], [t2, -0.12], [length, 0.0]],
			"position": [[0.0, rest], [t1, rest + Vector2(0, 6)], [t2, rest + Vector2(0, 6)], [length, rest]],
		}))


## Junta todas las animaciones llamadas dash + número (dash1, dash2, dash3, dash4...).
func _collect_dash_animations() -> void:
	_dash_names.clear()
	for anim_name in get_animation_list():
		var text := String(anim_name)
		if text.begins_with("dash") and text.substr(4).is_valid_int():
			_dash_names.append(StringName(text))
	_dash_names.sort_custom(func(a, b) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)


## Devuelve Body a su pose normal (los placeholders del esquive lo estiran y lo giran).
func _reset_body() -> void:
	_body.rotation = 0.0
	_body.scale = Vector2.ONE
	_body.position = _body_rest


## tracks: { "propiedad": [[tiempo, valor], ...] }
func _make_animation(length: float, loop: bool, body_path: String, tracks: Dictionary) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for property in tracks:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("%s:%s" % [body_path, property]))
		for key in tracks[property]:
			animation.track_insert_key(track, key[0], key[1])
	return animation


func _get_default_library() -> AnimationLibrary:
	if has_animation_library(&""):
		return get_animation_library(&"")
	var library := AnimationLibrary.new()
	add_animation_library(&"", library)
	return library
