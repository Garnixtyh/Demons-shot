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
## Carpeta de las texturas de Rebecca. Cada PNG se busca con el MISMO nombre que el de Band
## (cuerpo.png, poncho1.png, band_pose1.png...).
const REBE_DIR := "res://sprites/rebe/"
## Solo si algún archivo de Rebecca se llama distinto: "nombre_en_band.png": "nombre_en_rebe.png"
const RENAMES := {}
const ANIMATION_PLAYER_NAME := "AnimationPlayer_rebecca"

var _cache: Dictionary = {}


func _init() -> void:
	display_name = "Rebecca"
	# Sin cambios de stats (mismos que Band). Para tocarlos:
	#   player_overrides = {"max_health": 90.0}
	weapon_overrides = {"bullet_lifetime": 6.0}
	ability_script = OrbThrowAbility
	passive_script = FirePassive
	bullet_scene = FireBullet
	weapon_look = {"texture": preload("res://sprites/fugo.png"), "scale": Vector2(0.2, 0.2),
		"position": Vector2(11, -4), "rotation_degrees": -90.0, "muzzle_position": Vector2(23, -8)}


func apply(player: Node, weapon_stats: Resource) -> void:
	super.apply(player, weapon_stats)
	apply_visuals(player)


## Texturas + AnimationPlayer propio. Se puede llamar más de una vez (no duplica nada).
func apply_visuals(player: Node) -> void:
	if player.has_node(ANIMATION_PLAYER_NAME):
		return
	_replace_sprite_textures(player)
	_create_rebecca_animation_player(player)


## Textura de Rebecca equivalente a una de Band (null si no es de Band o falta el archivo)
func _rebe_texture(band_texture: Texture2D) -> Texture2D:
	if band_texture == null or not band_texture.resource_path.begins_with(BAND_DIR):
		return null
	var file := band_texture.resource_path.get_file()
	var path: String = REBE_DIR + str(RENAMES.get(file, file))
	if not _cache.has(path):
		if ResourceLoader.exists(path):
			_cache[path] = load(path)
		else:
			push_warning("Rebecca: no existe la textura %s" % path)
			_cache[path] = null
	return _cache[path]


## 1) Cambia la textura de cada Sprite2D del esqueleto
func _replace_sprite_textures(player: Node) -> void:
	for sprite in player.get_node(SKELETON).get_children():
		if sprite is Sprite2D:
			var tex := _rebe_texture(sprite.texture)
			if tex != null:
				sprite.texture = tex


## 2) Crea AnimationPlayer_rebecca con copias de las animaciones de Band y
##    reemplaza al AnimationPlayer original (que pisaba las texturas).
func _create_rebecca_animation_player(player: Node) -> void:
	var old := player.get_node("AnimationPlayer") as AnimationPlayer

	var library := AnimationLibrary.new()
	var source := old.get_animation_library(&"")
	for anim_name in source.get_animation_list():
		var copy := source.get_animation(anim_name).duplicate(true) as Animation
		_swap_texture_tracks(copy)
		library.add_animation(anim_name, copy)

	var rebe := AnimationPlayer.new()
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
