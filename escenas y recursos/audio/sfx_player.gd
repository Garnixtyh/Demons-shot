class_name SfxPlayer
extends Node
## Reproduce efectos de sonido en el bus "Efectos" (el slider de Efectos del menú de opciones).
## Con varios sonidos va rotando de forma semi aleatoria: nunca repite el que acaba de sonar
## (si sonó el 1, el próximo es el 2 o el 3, pero no el 1). Tiene varias "voces" para que
## sonidos seguidos (disparos rápidos) no se corten entre sí.

## Sonidos a rotar
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"Efectos"
@export var volume_db: float = 0.0
## Variación aleatoria del tono (0.04 = ±4%) para que no suene siempre idéntico
@export_range(0.0, 0.5) var pitch_jitter: float = 0.04
## Cuántos sonidos pueden sonar a la vez
@export var voices: int = 6

var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_index: int = -1


func _ready() -> void:
	for i in maxi(voices, 1):
		var player := AudioStreamPlayer.new()
		player.bus = bus
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)


## Agrega a `streams` los archivos que existan de la lista (los que falten se ignoran).
func load_paths(paths: Array) -> void:
	for path: String in paths:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				streams.append(stream)


## Reproduce el siguiente sonido (distinto al anterior si hay más de uno).
func play() -> void:
	if streams.is_empty() or _players.is_empty():
		return
	var index := _pick_index()
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = streams[index]
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _pick_index() -> int:
	var count := streams.size()
	if count == 1:
		return 0
	var index: int
	if _last_index < 0:
		index = randi() % count
	else:
		# Se elige entre los OTROS (saltea el último)
		index = randi() % (count - 1)
		if index >= _last_index:
			index += 1
	_last_index = index
	return index
