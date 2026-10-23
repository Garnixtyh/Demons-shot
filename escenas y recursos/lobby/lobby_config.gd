class_name LobbyConfig
extends Resource
## Configuración de un lobby. to_dict()/from_dict() sirven para mandarla por RPC
## a los clientes y mostrarla en la sala de espera.

## Config del lobby actual: se completa al crear/unirse y la lee la sala de espera.
static var current: LobbyConfig

const TEAM_SIZES := [1, 2, 3, 4]

## EDITAR: nombre visible -> ruta de la escena del mapa.
const MAPS := {
	"Barrio": "res://mapas/Barrio-ch13.tscn",
}

@export var lobby_name: String = ""
@export_range(1, 4) var team_size: int = 1
@export_range(1, 20) var points_to_win_round: int = 3
@export_range(1, 15) var rounds_to_win: int = 3
@export_range(1, 5) var upgrades_per_round: int = 3  # opciones (cartas) que se ofrecen
@export_range(0, 10) var rerolls: int = 1
@export var map_name: String = ""


func max_players() -> int:
	return team_size * 2


func map_path() -> String:
	return MAPS.get(map_name, "")


func team_label() -> String:
	return "%dvs%d" % [team_size, team_size]


func is_valid() -> bool:
	return not lobby_name.strip_edges().is_empty() \
		and team_size in TEAM_SIZES \
		and MAPS.has(map_name)


func to_dict() -> Dictionary:
	return {
		"lobby_name": lobby_name,
		"team_size": team_size,
		"points_to_win_round": points_to_win_round,
		"rounds_to_win": rounds_to_win,
		"upgrades_per_round": upgrades_per_round,
		"rerolls": rerolls,
		"map_name": map_name,
	}


static func from_dict(d: Dictionary) -> LobbyConfig:
	var c := LobbyConfig.new()
	c.lobby_name = str(d.get("lobby_name", ""))
	c.team_size = clampi(int(d.get("team_size", 1)), 1, 4)
	c.points_to_win_round = maxi(1, int(d.get("points_to_win_round", 3)))
	c.rounds_to_win = maxi(1, int(d.get("rounds_to_win", 3)))
	c.upgrades_per_round = maxi(1, int(d.get("upgrades_per_round", 3)))
	c.rerolls = maxi(0, int(d.get("rerolls", 1)))
	c.map_name = str(d.get("map_name", ""))
	return c
