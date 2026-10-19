extends AnimationPlayer
## Animaciones de una carta de mejora. Misma idea que el AnimationManager del jugador:
## si falta alguna animación, se crea una de reemplazo (placeholder) que anima el nodo
## Body de la carta. Si creás las tuyas en este AnimationPlayer con los mismos nombres,
## NO se pisan:
##   "entrada"   -> cuando la carta aparece
##   "seleccion" -> cuando el cursor está encima (al sacar el cursor se reproduce al revés)
##   "salida"    -> cuando se elige otra carta

const ENTER := &"entrada"
const HOVER := &"seleccion"
const EXIT := &"salida"

## Nodo que se anima (ruta relativa a la raíz de la carta)
@export var body_path: NodePath = ^"Body"


func _ready() -> void:
	_create_missing_animations()


func _create_missing_animations() -> void:
	var library := _get_default_library()
	var path := str(body_path)

	if not library.has_animation(ENTER):
		library.add_animation(ENTER, _make_animation(0.4, path, {
			"modulate": [[0.0, Color(1, 1, 1, 0)], [0.4, Color(1, 1, 1, 1)]],
			"position": [[0.0, Vector2(0, 90)], [0.4, Vector2.ZERO]],
			"scale": [[0.0, Vector2(0.8, 0.8)], [0.4, Vector2.ONE]],
		}))

	if not library.has_animation(HOVER):
		library.add_animation(HOVER, _make_animation(0.15, path, {
			"modulate": [[0.0, Color.WHITE], [0.15, Color.WHITE]],
			"position": [[0.0, Vector2.ZERO], [0.15, Vector2(0, -18)]],
			"scale": [[0.0, Vector2.ONE], [0.15, Vector2(1.08, 1.08)]],
		}))

	if not library.has_animation(EXIT):
		library.add_animation(EXIT, _make_animation(0.3, path, {
			"modulate": [[0.0, Color(1, 1, 1, 1)], [0.3, Color(1, 1, 1, 0)]],
			"position": [[0.0, Vector2.ZERO], [0.3, Vector2(0, 140)]],
			"scale": [[0.0, Vector2.ONE], [0.3, Vector2(0.85, 0.85)]],
		}))


## tracks: { "propiedad": [[tiempo, valor], ...] }
func _make_animation(length: float, node_path: String, tracks: Dictionary) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_NONE
	for property in tracks:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("%s:%s" % [node_path, property]))
		for key in tracks[property]:
			animation.track_insert_key(track, key[0], key[1])
	return animation


func _get_default_library() -> AnimationLibrary:
	if has_animation_library(&""):
		return get_animation_library(&"")
	var library := AnimationLibrary.new()
	add_animation_library(&"", library)
	return library
