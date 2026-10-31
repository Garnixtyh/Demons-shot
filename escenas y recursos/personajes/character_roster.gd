class_name CharacterRoster
extends RefCounted
## Lista de personajes que se pueden elegir en la sala de espera.
## Para agregar uno nuevo: sumá una línea a CHARACTERS (id = nombre de su carpeta en personajes/)
## y poné su icono en res://sprites/menu/selector_de_personajes/.

const ICON_FOLDER := "res://sprites/menu/selector_de_personajes/"
const DEFAULT_ID := "band"

const CHARACTERS := [
	{"id": "band", "name": "Band", "icon": ICON_FOLDER + "band_icon.png"},
	{"id": "rebecca", "name": "Rebecca", "icon": ICON_FOLDER + "rebe_icon.png"},
]


static func ids() -> Array:
	return CHARACTERS.map(func(c: Dictionary) -> String: return c["id"])


static func is_valid(id: String) -> bool:
	return ids().has(id)


## Id válido siempre (si llega algo raro, vuelve al personaje por defecto).
static func clean(id: String) -> String:
	return id if is_valid(id) else DEFAULT_ID


static func index_of(id: String) -> int:
	return maxi(ids().find(id), 0)


static func display_name(id: String) -> String:
	return str(CHARACTERS[index_of(id)]["name"])


static func icon(id: String) -> Texture2D:
	var path := str(CHARACTERS[index_of(id)]["icon"])
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Id del personaje que está `step` lugares después (da la vuelta).
static func step_id(id: String, step: int) -> String:
	return str(CHARACTERS[posmod(index_of(id) + step, CHARACTERS.size())]["id"])
