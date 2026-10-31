extends Node
## Autoload (Proyecto > Ajustes > Globales > Autoload) con el nombre "PlayerProfile".
## Guarda el nombre del jugador para usarlo en la lista de lobbys, la sala de espera y las partidas.

signal name_changed(new_name: String)
signal character_changed(new_character: String)

const SAVE_PATH := "user://profile.cfg"
const MAX_LENGTH := 16

var player_name: String = "":
	set(value):
		var clean := value.strip_edges().left(MAX_LENGTH)
		if clean.is_empty() or clean == player_name:
			return
		player_name = clean
		name_changed.emit(player_name)
		_save()


## Personaje elegido en la sala de espera (solo de esta PC; se manda al host).
var character: String = CharacterRoster.DEFAULT_ID:
	set(value):
		var clean := CharacterRoster.clean(value)
		if clean == character:
			return
		character = clean
		character_changed.emit(character)
		_save()


func _ready() -> void:
	_load()
	if player_name.is_empty():
		player_name = "Jugador%d" % randi_range(100, 999)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		player_name = str(cfg.get_value("profile", "name", ""))
		character = str(cfg.get_value("profile", "character", CharacterRoster.DEFAULT_ID))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", player_name)
	cfg.set_value("profile", "character", character)
	cfg.save(SAVE_PATH)
