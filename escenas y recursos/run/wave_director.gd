class_name WaveDirector
extends Node
## Lleva las fases y oleadas de la run. Lo crea el RunManager.
##
## Una FASE = `waves_per_phase` oleadas seguidas (cada una sorteada de WavePool). Se completa
## cuando se mata a todos los enemigos de la última oleada. La run tiene `phases` fases.
## Al terminar todas se emite `all_phases_completed` (ahí aparece el portal al jefe).

signal phase_started(phase: int)
signal wave_started(phase: int, wave: int, wave_id: String)
signal wave_cleared(phase: int, wave: int)
signal phase_completed(phase: int)
signal all_phases_completed

var waves_per_phase: int = 5
var phases: int = 3
## Probabilidad (0-1) de que una oleada sea especial (si hay oleadas especiales cargadas)
var special_wave_chance: float = 0.0
## Segundos de pausa entre oleadas
var wave_delay: float = 1.5
## Segundos que se ve el sprite de aparición antes de que salga el enemigo
var spawn_delay: float = 1.2
var spawn_marker_scale: Vector2 = Vector2.ONE
## Sprite de la marca (si es null se usa SPAWN_SPRITE)
var spawn_marker_texture: Texture2D = null

## Sprite que marca dónde va a aparecer cada enemigo
const SPAWN_SPRITE := "res://sprites/enemigos/penta_spawn.png"

var phase: int = 0
var wave: int = 0
var running: bool = false

var _rng := RandomNumberGenerator.new()
var _alive: int = 0
var _last_wave_id: String = ""
var _label: Label
var _banner: Label

signal _enemies_gone


func _ready() -> void:
	_rng.randomize()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.position.y = 14
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.hide()
	layer.add_child(_label)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_size_override("font_size", 48)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.modulate.a = 0.0
	layer.add_child(_banner)


## true si todavía se puede empezar una fase
func can_start() -> bool:
	return not running and phase < phases


## Empieza la siguiente fase en `room` (los enemigos aparecen ahí).
func start_phase(room: Room) -> void:
	if not can_start():
		return
	running = true
	phase += 1
	wave = 0
	phase_started.emit(phase)
	_show_banner("FASE %d" % phase)
	await get_tree().create_timer(1.5).timeout
	for w in range(1, waves_per_phase + 1):
		if not is_inside_tree():
			return
		wave = w
		_update_label()
		await _run_wave(room)
		if not is_inside_tree():
			return
		wave_cleared.emit(phase, wave)
		if w < waves_per_phase:
			await get_tree().create_timer(wave_delay).timeout
	running = false
	_label.hide()
	_show_banner("¡FASE %d COMPLETADA!" % phase)
	phase_completed.emit(phase)
	if phase >= phases:
		all_phases_completed.emit()


func _run_wave(room: Room) -> void:
	var special := _rng.randf() < special_wave_chance
	var data := WavePool.pick(_rng, special, _last_wave_id)
	_last_wave_id = data["id"]
	wave_started.emit(phase, wave, data["id"])
	_alive = 0
	for spawn in data["spawns"]:
		_spawn_enemy(room, spawn[0], spawn[1], data["effects"])
	if _alive > 0:
		await _enemies_gone


func _spawn_enemy(room: Room, enemy_id: String, local_pos: Vector2, effects: Array) -> void:
	var path: String = WavePool.ENEMIES.get(enemy_id, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("WaveDirector: no existe el enemigo '%s'." % enemy_id)
		return
	# Cuenta como vivo desde ya: la oleada no termina mientras haya enemigos por aparecer
	_alive += 1
	await _show_spawn_marker(room, local_pos)
	if not is_inside_tree() or not is_instance_valid(room):
		return
	var enemy := (load(path) as PackedScene).instantiate() as Node2D
	enemy.position = local_pos
	# Los enemigos de oleada no reaparecen solos
	if "respawn_time" in enemy:
		enemy.set("respawn_time", 0.0)
	enemy.add_to_group("wave_enemies")
	for effect in effects:
		if enemy.has_method("apply_wave_effect"):
			enemy.call("apply_wave_effect", effect)
	enemy.tree_exited.connect(_on_enemy_gone)
	room.add_child(enemy)


## Muestra el sprite penta_spawn en el lugar donde va a aparecer el enemigo (crece, gira y se apaga).
func _show_spawn_marker(room: Room, local_pos: Vector2) -> void:
	if spawn_delay <= 0.0:
		return
	var marker := Sprite2D.new()
	if spawn_marker_texture != null:
		marker.texture = spawn_marker_texture
	elif ResourceLoader.exists(SPAWN_SPRITE):
		marker.texture = load(SPAWN_SPRITE)
	else:
		# Sin el sprite: círculo violeta de reemplazo
		marker.texture = _fallback_texture()
	marker.position = local_pos
	marker.modulate.a = 0.0
	marker.scale = spawn_marker_scale * 0.4
	room.add_child(marker)
	var tween := marker.create_tween().set_parallel(true)
	tween.tween_property(marker, "modulate:a", 1.0, spawn_delay * 0.4)
	tween.tween_property(marker, "scale", spawn_marker_scale, spawn_delay * 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(marker, "rotation", 0.6, spawn_delay)
	tween.chain().tween_property(marker, "modulate:a", 0.0, 0.15)
	await get_tree().create_timer(spawn_delay).timeout
	if is_instance_valid(marker):
		marker.queue_free()


func _fallback_texture() -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for x in 96:
		for y in 96:
			var d := Vector2(x - 47.5, y - 47.5).length()
			if d < 46.0 and d > 40.0:
				image.set_pixel(x, y, Color(0.7, 0.2, 0.9, 1.0))
	return ImageTexture.create_from_image(image)


func _on_enemy_gone() -> void:
	_alive -= 1
	if _alive <= 0:
		_enemies_gone.emit()


func _update_label() -> void:
	_label.text = "FASE %d/%d  -  OLEADA %d/%d" % [phase, phases, wave, waves_per_phase]
	_label.show()


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
