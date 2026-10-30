extends RefCounted
## MOLDE de los stats base de un personaje (no se usa solo: cada personaje lo extiende).
##
## Para crear un personaje nuevo, por ejemplo "bruja":
##   1. Carpeta nueva:  personajes/bruja/
##   2. bruja_stats.gd  -> extends "../character_stats.gd" (copiá band_stats.gd)
##   3. bruja_pool.gd   -> su pool de mejoras (copiá band_pool.gd)
##   4. En el Inspector del jugador: Personaje > character = "bruja"
## El nombre del personaje define los archivos: <nombre>/<nombre>_stats.gd y <nombre>_pool.gd.

var display_name: String = "Personaje"

## Cambios a variables del jugador. Lo que NO esté acá usa lo que tenga el player.tscn.
## Ejemplo: {"max_health": 80.0, "max_speed": 420.0}
var player_overrides: Dictionary = {}

## Cambios a los stats del arma (WeaponStats).
## Ejemplo: {"damage": 30.0, "fire_rate": 3.0, "magazine_size": 8}
var weapon_overrides: Dictionary = {}

## Script de la habilidad de la tecla E (debe extender abilities/ability.gd)
var ability_script: Script = null

## OPCIONAL: pasiva del personaje. Es un script que extiende Node; el jugador lo agrega como
## nodo hijo "Passive" (y se consulta con player.get_passive()). Null = sin pasiva.
var passive_script: Script = null


## La llama el jugador al empezar.
func apply(player: Node, weapon_stats: Resource) -> void:
	for key in player_overrides:
		if key in player:
			player.set(key, player_overrides[key])
		else:
			push_warning("%s: el jugador no tiene la variable '%s'" % [display_name, key])
	for key in weapon_overrides:
		if key in weapon_stats:
			weapon_stats.set(key, weapon_overrides[key])
		else:
			push_warning("%s: WeaponStats no tiene la variable '%s'" % [display_name, key])
