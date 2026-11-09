class_name WavePool
extends RefCounted
## Lista de oleadas del modo un jugador. Para agregar una oleada, sumá una línea a WAVES.
##
## Formato de cada oleada:  "id_de_la_oleada": [ ["id_del_enemigo", Vector2(x, y)], ... ]
## La posición es LOCAL a la sala donde se pelea (esquina superior izquierda = (0, 0); el piso
## de la sala principal está en y ≈ 656).
##
## Para sumar un enemigo nuevo: ponelo en ENEMIES (id -> escena) y usá ese id en las oleadas.

## id de enemigo -> escena
const ENEMIES := {
	"prueba": "res://escenas y recursos/enemigos/enemigo_prueba.tscn",
}

## Oleadas normales (cada oleada de la run se sortea de acá)
const WAVES := {
	"oleada0001": [["prueba", Vector2(320, 600)], ["prueba", Vector2(960, 600)]],
	"oleada0002": [["prueba", Vector2(220, 600)], ["prueba", Vector2(640, 600)], ["prueba", Vector2(1060, 600)]],
	"oleada0003": [["prueba", Vector2(420, 600)], ["prueba", Vector2(860, 600)]],
	"oleada0004": [["prueba", Vector2(200, 600)], ["prueba", Vector2(500, 600)], ["prueba", Vector2(780, 600)], ["prueba", Vector2(1080, 600)]],
	"oleada0005": [["prueba", Vector2(640, 600)]],
}

## PARA EL FUTURO - oleadas especiales: enemigos con efectos random.
## Formato: "id": { "spawns": [ [enemigo, Vector2], ... ], "effects": ["id_efecto", ...] }
## Los efectos se le pasan a cada enemigo con enemy.apply_wave_effect(effect) (si lo tiene).
const SPECIAL_WAVES := {
}


## Sortea una oleada. Devuelve { "id": String, "spawns": Array, "effects": Array }.
## `exclude_id` evita repetir la oleada anterior (si hay más de una para elegir).
static func pick(rng: RandomNumberGenerator, special: bool = false, exclude_id: String = "") -> Dictionary:
	var source: Dictionary = SPECIAL_WAVES if special and not SPECIAL_WAVES.is_empty() else WAVES
	var ids: Array = source.keys()
	if ids.size() > 1:
		ids.erase(exclude_id)
	if ids.is_empty():
		return {"id": "", "spawns": [], "effects": []}
	var id: String = ids[rng.randi() % ids.size()]
	var entry: Variant = source[id]
	if entry is Dictionary:
		return {"id": id, "spawns": entry.get("spawns", []), "effects": entry.get("effects", [])}
	return {"id": id, "spawns": entry, "effects": []}
