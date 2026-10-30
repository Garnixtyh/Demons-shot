extends "../character_stats.gd"
## Rebecca: lanza fuego con su libro. Stats base IGUALES a Band (después se ajustan acá).
## Pasiva: cada vez que su básico conecta genera un orbe de fuego que orbita a su alrededor.
## Habilidad (E): lanza todos los orbes en línea recta.

const OrbThrowAbility := preload("lanzar_orbes_ability.gd")
const FirePassive := preload("rebecca_passive.gd")
## Bala de fuego (placeholder: el sprite de la bala de Band teñido de naranja; cambiale el sprite en bala_fuego.tscn)
const FireBullet := preload("bala_fuego.tscn")
## Rebe: usa el mismo rig que Band pero con sus propias texturas
## y su propia copia de las animaciones.

const TermoAbility := preload("../band/termo_ability.gd")

const SKELETON := "Visuals/cuerpo/Skeleton2D"

## textura de Band -> textura de Rebe (cada una reemplazada acá)
const TEXTURES := {
	"res://sprites/band_demon-shot/pierna1.png":   "res://sprites/rebe/pierna1.png",
	"res://sprites/band_demon-shot/pantalon1.png": "res://sprites/rebe/pantalon1.png",
	"res://sprites/band_demon-shot/pantalon2.png": "res://sprites/rebe/pantalon2.png",
	"res://sprites/band_demon-shot/cuerpo.png":    "res://sprites/rebe/cuerpo.png",
	"res://sprites/band_demon-shot/cuerda.png":    "res://sprites/rebe/cuerda.png",
	"res://sprites/band_demon-shot/braso1.png":    "res://sprites/rebe/braso1.png",
	"res://sprites/band_demon-shot/mano1.png":     "res://sprites/rebe/mano1.png",
	"res://sprites/band_demon-shot/poncho1.png":   "res://sprites/rebe/poncho1.png",
	"res://sprites/band_demon-shot/poncho2.png":   "res://sprites/rebe/poncho2.png",
	"res://sprites/band_demon-shot/cabeza1.png":   "res://sprites/rebe/cabeza1.png",
	"res://sprites/band_demon-shot/cara1.png":     "res://sprites/rebe/cara1.png",
	"res://sprites/band_demon-shot/sombrero.png":  "res://sprites/rebe/sombrero.png",
}


func _init() -> void:
	display_name = "Rebe"
	ability_script = TermoAbility


func apply(player: Node, weapon_stats: Resource) -> void:
	super.apply(player, weapon_stats)
	_replace_textures(player)
	_duplicate_animations(player)


func _load_texture(band_path: String) -> Texture2D:
	var rebe_path: String = TEXTURES.get(band_path, "")
	if rebe_path.is_empty() or not ResourceLoader.exists(rebe_path):
		return null
	return load(rebe_path) as Texture2D


## 1) Cambia la textura de cada Sprite2D del esqueleto
func _replace_textures(player: Node) -> void:
	for sprite in player.get_node(SKELETON).get_children():
		if sprite is Sprite2D and sprite.texture != null:
			var tex := _load_texture(sprite.texture.resource_path)
			if tex != null:
				sprite.texture = tex


## 2) Copia propia de las animaciones de este jugador
func _duplicate_animations(player: Node) -> void:
	var anim := player.get_node("AnimationPlayer") as AnimationPlayer
	var old_lib := anim.get_animation_library(&"")
	var new_lib := AnimationLibrary.new()
	for anim_name in old_lib.get_animation_list():
		var copy := old_lib.get_animation(anim_name).duplicate(true) as Animation
		_swap_texture_tracks(copy)
		new_lib.add_animation(anim_name, copy)
	anim.remove_animation_library(&"")
	anim.add_animation_library(&"", new_lib)
	anim.play(&"idle")


## Las animaciones de Band también animan la propiedad "texture"
## (Poncho1 y Cara1): si no se cambian, pisan las texturas de Rebe.
func _swap_texture_tracks(animation: Animation) -> void:
	for t in animation.get_track_count():
		if not str(animation.track_get_path(t)).ends_with(":texture"):
			continue
		for k in animation.track_get_key_count(t):
			var old_tex := animation.track_get_key_value(t, k) as Texture2D
			if old_tex == null:
				continue
			var new_tex := _load_texture(old_tex.resource_path)
			if new_tex != null:
				animation.track_set_key_value(t, k, new_tex)
	
	display_name = "Rebecca"
	# Sin cambios de stats (mismos que Band). Para tocarlos:
	#   player_overrides = {"max_health": 90.0}
	weapon_overrides = {"bullet_lifetime": 6.0}
	ability_script = OrbThrowAbility
	passive_script = FirePassive
	bullet_scene = FireBullet
	weapon_look = {"texture": preload("res://sprites/fugo.png"), "scale": Vector2(0.2, 0.2),
		"position": Vector2(11, -4), "rotation_degrees": -90.0, "muzzle_position": Vector2(23, -8)}
