class_name ComboTracker
extends Node
## Combo de kills estilo Pizza Tower. Es hijo del jugador (lo crea player.gd).
##
## - Cada enemigo que muere suma al combo y le suma tiempo a la barra (kill_time_bonus).
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
@export var hit_time_bonus: float = 1.0
## Tope de tiempo de la barra: los golpes pueden alargarla por encima de combo_time hasta acá
@export var max_time: float = 5.0
## Segundos que suma a la barra cada kill (con el combo ya activo), hasta max_time
@export var kill_time_bonus: float = 1.0
## Puntos base por kill (se multiplican por el número de kill dentro del combo)
@export var points_per_kill: int = 2
## Segundos que pierde la barra cada vez que el jugador recibe daño
@export var damage_time_penalty: float = 1.0

var kills: int = 0
## Puntos acumulados en este combo (se cobran al terminar)
var pot: int = 0
var time_left: float = 0.0
var player: Node = null
## Segundos que le quedan al combo congelado (carta The World): la barra no baja ni recibe penalización
var _freeze_left: float = 0.0
## true mientras hay enemigos por aparecer (marca de spawn visible): la barra de tiempo se pausa
var spawn_hold: bool = false

## FULL COMBO (rango "FC"): se cuenta desde que el WaveDirector lo activa (tras la primera oleada).
## fc_total = enemigos que aparecieron en la lista; fc_kills = kills hechos mientras se cuenta.
## Si al terminar el combo fc_kills == fc_total, el rango es FC.
var fc_active: bool = false
var fc_total: int = 0
var fc_kills: int = 0


func _ready() -> void:
	player = get_parent()
	var hud := ComboHud.new()
	hud.tracker = self
	add_child(hud)


func _process(delta: float) -> void:
	if kills <= 0:
		return
	if _freeze_left > 0.0:
		_freeze_left -= delta
		return
	if spawn_hold:
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish()


func is_active() -> bool:
	return kills > 0


## `extend_time` = false: el kill cuenta (kills y puntos) pero NO le suma tiempo a la barra
## (lo usa la carta The Death).
func register_kill(extend_time: bool = true) -> void:
	var was_active := kills > 0
	kills += 1
	pot += points_per_kill * kills
	if fc_active:
		fc_kills += 1
	if not extend_time:
		if not was_active:
			time_left = combo_time
		combo_changed.emit(kills, pot)
		return
	if was_active:
		# Cada kill suma tiempo extra (sin pasar de max_time ni achicar la barra)
		time_left = maxf(time_left, minf(time_left + kill_time_bonus, maxf(max_time, combo_time)))
		time_left = maxf(time_left, combo_time)
	else:
		time_left = combo_time
	combo_changed.emit(kills, pot)
	if was_active:
		time_extended.emit(time_left)


## Golpeaste a un enemigo: alarga el combo (sin pasar de max_time).
func register_hit() -> void:
	if kills > 0 and _freeze_left <= 0.0:
		time_left = minf(time_left + hit_time_bonus, maxf(max_time, combo_time))
		time_extended.emit(time_left)


## Rango actual del combo ("" si no hay)
func current_rank() -> String:
	if is_full_combo():
		return "FC"
	return rank_for(kills)


## true si mataste TODOS los enemigos que aparecieron (desde que se cuenta) sin cortar el combo
func is_full_combo() -> bool:
	return fc_active and kills > 0 and fc_total > 0 and fc_kills == fc_total


## Apareció un enemigo (lo avisa el WaveDirector): entra a la lista del full combo.
func register_fc_spawn() -> void:
	if fc_active:
		fc_total += 1
		combo_changed.emit(kills, pot)


## Empieza (o deja de contar) el full combo. Al empezar la lista arranca vacía.
func set_fc_active(value: bool) -> void:
	if value and not fc_active:
		fc_total = 0
		fc_kills = 0
	fc_active = value


static func rank_for(kill_count: int) -> String:
	for entry in RANKS:
		if kill_count >= entry["min"]:
			return entry["rank"]
	return ""


## El jugador recibió daño: la barra baja, pero el combo no se rompe (si se queda sin tiempo, termina).
func on_player_hit() -> void:
	if kills <= 0 or _freeze_left > 0.0:
		return
	time_left -= damage_time_penalty
	if time_left <= 0.0:
		_finish()
	else:
		time_reduced.emit(time_left)


## Cobra YA los puntos acumulados del combo (player.add_points) sin terminarlo (carta The Fool).
## El pozo no se toca: el combo sigue igual y al terminar cobra todo de nuevo. Devuelve lo cobrado.
func cash_out() -> int:
	if kills <= 0 or pot <= 0:
		return 0
	if player != null and player.has_method("add_points"):
		player.add_points(pot)
	return pot


## Suma `amount` al contador "xN" del combo actual (carta The Hermit). No da puntos ni tiempo.
func add_multiplier(amount: int) -> void:
	if kills <= 0:
		return
	kills += amount
	combo_changed.emit(kills, pot)


## Congela el combo `seconds` segundos (carta The World). Si ya estaba congelado, se queda con el mayor.
func freeze(seconds: float) -> void:
	if kills <= 0:
		return
	_freeze_left = maxf(_freeze_left, seconds)
	time_extended.emit(time_left)


func is_frozen() -> bool:
	return _freeze_left > 0.0


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
	var rank := current_rank()
	_reset()
	if player != null and player.has_method("add_points"):
		player.add_points(points)
	combo_ended.emit(count, points, rank)


func _reset() -> void:
	_freeze_left = 0.0
	_reset_full_combo()
	kills = 0
	pot = 0
	time_left = 0.0


## La lista del full combo vuelve a empezar con los enemigos que siguen vivos
func _reset_full_combo() -> void:
	fc_kills = 0
	fc_total = 0
	if not fc_active or not is_inside_tree():
		return
	for enemy in get_tree().get_nodes_in_group("wave_enemies"):
		if is_instance_valid(enemy) and not ("dead" in enemy and enemy.dead):
			fc_total += 1
