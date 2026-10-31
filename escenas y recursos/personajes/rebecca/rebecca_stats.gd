extends "../character_stats.gd"
## Rebecca: lanza fuego con su libro. Stats base IGUALES a Band (después se ajustan acá).
## Pasiva: cada vez que su básico conecta genera un orbe de fuego que orbita a su alrededor.
## Habilidad (E): lanza todos los orbes en línea recta.
## Visual: usa el mismo rig que Band, pero con las texturas de res://sprites/rebe/
## y con su propio AnimationPlayer ("AnimationPlayer_rebecca").

const OrbThrowAbility := preload("lanzar_orbes_ability.gd")
const FirePassive := preload("rebecca_passive.gd")
## Bala de fuego (placeholder: el sprite de la bala de Band teñido de naranja; cambiale el sprite en bala_fuego.tscn)
const FireBullet := preload("bala_fuego.tscn")
const AnimationManagerScript := preload("res://escenas y recursos/player/animation_manager.gd")

const SKELETON := "Visuals/cuerpo/Skeleton2D"
## Carpeta de las texturas de Band (la que usa player.tscn)
const BAND_DIR := "res://sprites/band/"
const REBE_DIR := "res://sprites/rebe/"
## Textura de Rebecca para cada Sprite2D del esqueleto (igual que en rebe_test.tscn)
const NODE_TEXTURES := {
	"Pierna1": "pierna1.png",
	"Pierna2": "pierna1.png",
	"Pantalon1": "sombrero.png",
	"Braso1": "braso1.png",
	"Braso2": "braso2.png",
	"Cuerpo": "cuerpo.png",
	"Mano1": "mano1.png",
	"Poncho1": "corbata.png",
	"Cabeza1": "cabeza1.png",
	"Cara1": "cara1.png",
}
## Sprites de Band que Rebecca no usa: se ocultan
const HIDDEN_NODES := ["Pantalon2", "Cuerda", "Sombrero"]
## Si una animación de Band asigna una textura de Band, se cambia por la de Rebecca (por nombre de archivo)
const FILE_RENAMES := {"poncho1.png": "corbata.png", "pantalon1.png": "sombrero.png", "braso1.png": "braso1.png"}
const ANIMATION_PLAYER_NAME := "AnimationPlayer_rebecca"

var _cache: Dictionary = {}


func _init() -> void:
	display_name = "Rebecca"
	# Sin cambios de stats (mismos que Band). Para tocarlos:
	#   player_overrides = {"max_health": 90.0}
	weapon_overrides = {
	"bullet_lifetime": 0.3,
	 "bullet_scale" : 2,
	 "bullet_speed" : 350,
	 "magazine_size" : 3,
	 "daamge" : 3, 
	 "automatic" : true
	}
	ability_script = OrbThrowAbility
	passive_script = FirePassive
	bullet_scene = FireBullet
	weapon_look = {"texture": preload("res://sprites/rebe/mano2.png"), "scale": Vector2(0.2, 0.2),
	"reload_icon_texture": preload("res://sprites/rebe/rebe_recarga.png"),
		"position": Vector2(11, -4), "rotation_degrees": -90.0, "muzzle_position": Vector2(23, -8)}


func apply(player: Node, weapon_stats: Resource) -> void:
	super.apply(player, weapon_stats)
	apply_visuals(player)


## Texturas + AnimationPlayer propio. Se puede llamar más de una vez (no duplica nada).
func apply_visuals(player: Node) -> void:
	if player.has_node(ANIMATION_PLAYER_NAME):
		return
	print("[Rebecca] aplicando texturas y AnimationPlayer propio")
	_replace_sprite_textures(player)
	_create_rebecca_animation_player(player)
	print("[Rebecca] listo: AnimationPlayer activo = ", player.get("_animator"))


func _load_rebe(file: String) -> Texture2D:
	var path := REBE_DIR + file
	if not _cache.has(path):
		if ResourceLoader.exists(path):
			_cache[path] = load(path)
		else:
			push_warning("Rebecca: no existe la textura %s" % path)
			_cache[path] = null
	return _cache[path]


## Textura de Rebecca equivalente a una textura de Band (null si no es de Band)
func _rebe_texture(band_texture: Texture2D) -> Texture2D:
	if band_texture == null or not band_texture.resource_path.begins_with(BAND_DIR):
		return null
	var file := band_texture.resource_path.get_file()
	return _load_rebe(str(FILE_RENAMES.get(file, file)))


## 1) Pone la textura de Rebecca a cada Sprite2D y oculta los que no usa
func _replace_sprite_textures(player: Node) -> void:
	var skeleton := player.get_node(SKELETON)
	for sprite_name in NODE_TEXTURES:
		var sprite := skeleton.get_node_or_null(sprite_name) as Sprite2D
		if sprite == null:
			push_warning("Rebecca: no existe el sprite %s" % sprite_name)
			continue
		var tex := _load_rebe(NODE_TEXTURES[sprite_name])
		if tex != null:
			sprite.texture = tex
	for sprite_name in HIDDEN_NODES:
		var sprite := skeleton.get_node_or_null(sprite_name) as CanvasItem
		if sprite != null:
			sprite.visible = false


## 2) Crea AnimationPlayer_rebecca con copias de las animaciones de Band y
##    reemplaza al AnimationPlayer original (que pisaba las texturas).
const OWN_LIBRARY := "res://escenas y recursos/personajes/rebecca/rebecca_animations.res"

func _create_rebecca_animation_player(player: Node) -> void:
	var old := player.get_node("AnimationPlayer") as AnimationPlayer

	var library: AnimationLibrary
	if ResourceLoader.exists(OWN_LIBRARY):
		# Animaciones propias de Rebecca
		library = (load(OWN_LIBRARY) as AnimationLibrary).duplicate(true)
	else:
		# Si todavía no existe el archivo, copia las de Band
		library = AnimationLibrary.new()
		var source := old.get_animation_library(&"")
		for anim_name in source.get_animation_list():
			var copy := source.get_animation(anim_name).duplicate(true) as Animation
			library.add_animation(anim_name, copy)
	for anim_name in library.get_animation_list():
		var animation := library.get_animation(anim_name)
		_remove_unresolved_tracks(animation, player)
		_swap_texture_tracks(animation)

	var rebe := AnimationPlayer.new()
	# ... el resto queda igual (name, set_script, body_name, add_animation_library, etc.)
	rebe.name = ANIMATION_PLAYER_NAME
	rebe.set_script(AnimationManagerScript)  # mismo manejador: idle / walk / jump / fall / dash
	rebe.set("body_name", "cuerpo")
	rebe.add_animation_library(&"", library)

	# El de Band se apaga y se quita
	old.stop()
	old.set_process(false)
	old.name = "AnimationPlayer_band"
	old.queue_free()

	player.add_child(rebe)
	# player.gd guardó el AnimationPlayer de Band en _animator: se lo cambiamos por el de Rebecca
	player.set("_animator", rebe)


## Las animaciones de Band también asignan la propiedad "texture" (Poncho1, Cara1, poses):
## si no se cambian, pisan las texturas de Rebecca en cada frame.
func _swap_texture_tracks(animation: Animation) -> void:
	for t in animation.get_track_count():
		if not str(animation.track_get_path(t)).ends_with(":texture"):
			continue
		for k in animation.track_get_key_count(t):
			var tex := _rebe_texture(animation.track_get_key_value(t, k) as Texture2D)
			if tex != null:
				animation.track_set_key_value(t, k, tex)


## rebe_test tiene el arma en Visuals/cuerpo/Weapon, pero en el jugador está en Visuals/Weapon
## (y su posición/escala las manda weapon_look). Se sacan las pistas de nodos que no existen en el jugador.
func _remove_unresolved_tracks(animation: Animation, player: Node) -> void:
	for t in range(animation.get_track_count() - 1, -1, -1):
		var node_path := NodePath(str(animation.track_get_path(t)).get_slice(":", 0))
		if player.get_node_or_null(node_path) == null:
			animation.remove_track(t)
