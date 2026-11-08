class_name ComboTracker
extends Node
## Combo de kills estilo Pizza Tower. Es hijo del jugador (lo crea player.gd).
##
## - Cada enemigo que muere suma al combo y reinicia la barra de tiempo.
## - Cada kill vale (puntos_por_kill × número de kill dentro del combo): 1, 2, 3, 4...
##   así un combo de 5 kills da 1+2+3+4+5 = 15 puntos. Más kills seguidos = mucho más premio.
## - Cada golpe a un enemigo (aunque no lo mate) suma tiempo a la barra, hasta `max_time`
##   (que es más que el tiempo base: así, mientras seguís pegando, el combo aguanta más).
## - Cuando la barra de tiempo se acaba, el combo TERMINA y se cobran los puntos
##   (player.add_points) para gastarlos en la tienda. También se ve un RANGO (D a S).
## - Si el jugador recibe daño, la barra pierde `damage_time_penalty` segundos (si llega a 0 el combo
##   termina y se cobra igual). Si el jugador muere, el combo se ROMPE y se pierde lo acumulado.
##
## Los enemigos avisan con get_tree().call_group("players", "register_kill", self).

## Todos los cambios de estado relevantes para el HUD
signal combo_changed(kills: int, pot: int)
signal combo_ended(kills: int, points: int, rank: String)
signal combo_broken(kills: int, lost_points: int)
## Un golpe a un enemigo sumó tiempo a la barra
signal time_extended(time_left: float)
## El jugador recibió daño y la barra perdió tiempo
signal time_reduced(time_left: float)

## Rangos según la cantidad de kills (de mayor a menor)
const RANKS := [
	{"min": 12, "rank": "S"},
	{"min": 8, "rank": "A"},
	{"min": 5, "rank": "B"},
	{"min": 3, "rank": "C"},
	{"min": 1, "rank": "D"},
]

## Segundos que dura el combo desde el último kill (la barra se llena hasta acá con cada kill)
@export var combo_time: float = 3.0
## Segundos que suma a la barra cada golpe a un enemigo (con el combo activo)
@export var hit_time_bonus: float = 0.6
## Tope de tiempo de la barra: los golpes pueden alargarla por encima de combo_time hasta acá
@export var max_time: float = 5.0
## Puntos base por kill (se multiplican por el número de kill dentro del combo)
@export var points_per_kill: int = 1
## Segundos que pierde la barra cada vez que el jugador recibe daño
@export var damage_time_penalty: float = 1.0

var kills: int = 0
## Puntos acumulados en este combo (se cobran al terminar)
var pot: int = 0
var time_left: float = 0.0
var player: Node = null


func _ready() -> void:
	player = get_parent()
	var hud := ComboHud.new()
	hud.tracker = self
	add_child(hud)


func _process(delta: float) -> void:
	if kills <= 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish()


func is_active() -> bool:
	return kills > 0


func register_kill() -> void:
	kills += 1
	pot += points_per_kill * kills
	# Llena la barra hasta el tiempo base (si los golpes la tenían más alta, no se la achica)
	time_left = maxf(time_left, combo_time)
	combo_changed.emit(kills, pot)


## Golpeaste a un enemigo: alarga el combo (sin pasar de max_time).
func register_hit() -> void:
	if kills > 0:
		time_left = minf(time_left + hit_time_bonus, maxf(max_time, combo_time))
		time_extended.emit(time_left)


## Rango actual del combo ("" si no hay)
func current_rank() -> String:
	return rank_for(kills)


static func rank_for(kill_count: int) -> String:
	for entry in RANKS:
		if kill_count >= entry["min"]:
			return entry["rank"]
	return ""


## El jugador recibió daño: la barra baja, pero el combo no se rompe (si se queda sin tiempo, termina).
func on_player_hit() -> void:
	if kills <= 0:
		return
	time_left -= damage_time_penalty
	if time_left <= 0.0:
		_finish()
	else:
		time_reduced.emit(time_left)


## Rompe el combo sin cobrar nada.
func break_combo() -> void:
	if kills <= 0:
		return
	var lost := pot
	var count := kills
	_reset()
	combo_broken.emit(count, lost)


## Se acabó el tiempo: se cobran los puntos.
func _finish() -> void:
	var count := kills
	var points := pot
	var rank := rank_for(count)
	_reset()
	if player != null and player.has_method("add_points"):
		player.add_points(points)
	combo_ended.emit(count, points, rank)


func _reset() -> void:
	kills = 0
	pot = 0
	time_left = 0.0
