class_name LevelMusic
extends Node
## Música de un nivel, en loop, por el bus "Musica" (el slider de Música del menú de opciones).
## Arrastrá level_music.tscn a cualquier nivel y elegí la canción en `stream`.
## Sigue sonando aunque el juego esté en pausa (por ejemplo, al elegir una mejora).

@export var stream: AudioStream
@export var bus: StringName = &"Musica"
@export var volume_db: float = 0.0
@export var autoplay: bool = true

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = bus
	_player.volume_db = volume_db
	if stream != null:
		# Copia propia para activar el loop sin tocar el recurso importado
		var looped := stream.duplicate() as AudioStream
		if looped is AudioStreamOggVorbis:
			(looped as AudioStreamOggVorbis).loop = true
		elif looped is AudioStreamMP3:
			(looped as AudioStreamMP3).loop = true
		elif looped is AudioStreamWAV:
			(looped as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_player.stream = looped
	# Por si el formato no loopea solo: al terminar, arranca de nuevo
	_player.finished.connect(_player.play)
	add_child(_player)
	if autoplay and _player.stream != null:
		_player.play()


func play() -> void:
	if _player != null and _player.stream != null and not _player.playing:
		_player.play()


func stop() -> void:
	if _player != null:
		_player.stop()
