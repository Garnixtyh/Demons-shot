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
## Total de enemigos de TODAS las fases y oleadas (se calcula al empezar la run; lo usa el full combo)
var total_enemies: int = 0

## Oleadas sorteadas de antemano: _plan[fase - 1][oleada - 1] = datos de WavePool.pick
var _plan: Array = []

var _rng := RandomNumberGenerator.new()
var _alive: int = 0
## Enemigos con la marca de aparición visible (todavía no salieron): el combo espera
var _pending_spawns: int = 0
var _event_running: bool = false
var _last_wave_id: String = ""
var _label: Label
var _banner: Label
## Presentación del modificador de la fase 3 (ícono + nombre + descripción)
var _mod_box: VBoxContainer
var _mod_icon: TextureRect
var _mod_name: Label
var _mod_desc: Label
## id del modificador activo ("" = ninguno)
var _active_modifier: String = ""

signal _enemies_gone


func _ready() -> void:
	_rng.randomize()
	_build_run_plan()
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
	_build_modifier_box(layer)


## Sortea de una vez todas las oleadas de todas las fases y cuenta los enemigos que van a aparecer.
## Después las fases juegan exactamente estas oleadas.
func _build_run_plan() -> void:
	_plan.clear()
	total_enemies = 0
	var last_id := ""
	for p in range(1, phases + 1):
		var phase_waves: Array = []
		for w in range(1, waves_per_phase + 1):
			var special := _rng.randf() < special_wave_chance
			var data := WavePool.pick(_rng, special, last_id, p)
			last_id = data["id"]
			total_enemies += data["spawns"].size()
			phase_waves.append(data)
		_plan.append(phase_waves)


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
	if phase == 1:
		get_tree().call_group("players", "combo_run_started", total_enemies)
	get_tree().call_group("players", "combo_phase_started")
	if phase == phases:
		# Última fase: sale un modificador
		await _show_modifier_intro()
	else:
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
		# El combo se congela al limpiar la oleada (y en la última, el full combo se evalúa)
		get_tree().call_group("players", "combo_wave_cleared", w >= waves_per_phase)
		if w < waves_per_phase:
			await get_tree().create_timer(wave_delay).timeout
	running = false
	_clear_modifier()
	_label.hide()
	_show_banner("¡FASE %d COMPLETADA!" % phase)
	phase_completed.emit(phase)
	if phase >= phases:
		all_phases_completed.emit()


## true mientras corre una oleada suelta (caja de Pandora) o una fase
func is_busy() -> bool:
	return running or _event_running


## Una oleada suelta en `room` (la caja de Pandora): sortea una oleada, la hace aparecer con
## sus marcas y espera a que mueran TODOS. No toca las fases ni el contador de oleadas.
func run_event_wave(room: Room) -> void:
	if is_busy():
		return
	_event_running = true
	var data := WavePool.pick(_rng, false, "", maxi(phase, 1))
	_alive = 0
	for spawn in data["spawns"]:
		_spawn_enemy(room, spawn[0], spawn[1], data["effects"])
	if _alive > 0:
		await _enemies_gone
	_event_running = false
	if not is_inside_tree():
		return


func _run_wave(room: Room) -> void:
	var data: Dictionary = _plan[phase - 1][wave - 1]
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
	_set_pending(1)
	await _show_spawn_marker(room, local_pos)
	_set_pending(-1)
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
	if _active_modifier != "":
		PhaseModifiers.apply_to_enemy(enemy, _active_modifier)
	get_tree().call_group("players", "register_fc_spawn")


## Suma o resta enemigos por aparecer y le avisa a los jugadores (el combo se pausa mientras hay alguno)
func _set_pending(delta: int) -> void:
	_pending_spawns = maxi(_pending_spawns + delta, 0)
	if is_inside_tree():
		get_tree().call_group("players", "set_combo_spawn_hold", _pending_spawns > 0)


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


func _exit_tree() -> void:
	_clear_modifier()


## Saca el modificador activo (y lo que le hizo al jugador)
func _clear_modifier() -> void:
	if _active_modifier == "":
		return
	var id := _active_modifier
	_active_modifier = ""
	if is_inside_tree():
		for player in get_tree().get_nodes_in_group("players"):
			PhaseModifiers.remove_from_player(player, id)


func _build_modifier_box(layer: CanvasLayer) -> void:
	_mod_box = VBoxContainer.new()
	_mod_box.set_anchors_preset(Control.PRESET_CENTER)
	_mod_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mod_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mod_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_mod_box.add_theme_constant_override("separation", 10)
	_mod_box.modulate.a = 0.0
	layer.add_child(_mod_box)
	_mod_icon = TextureRect.new()
	_mod_icon.custom_minimum_size = Vector2(128, 128)
	_mod_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mod_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mod_box.add_child(_mod_icon)
	_mod_name = Label.new()
	_mod_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mod_name.add_theme_font_size_override("font_size", 28)
	_mod_name.add_theme_constant_override("outline_size", 8)
	_mod_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_mod_box.add_child(_mod_name)
	_mod_desc = Label.new()
	_mod_desc.custom_minimum_size = Vector2(560, 0)
	_mod_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mod_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mod_desc.add_theme_font_size_override("font_size", 20)
	_mod_desc.add_theme_constant_override("outline_size", 6)
	_mod_desc.add_theme_color_override("font_outline_color", Color.BLACK)
	_mod_box.add_child(_mod_desc)


## Muestra "FASE 3"; a los instantes el texto sube y desde abajo sube el ícono del modificador
## con su descripción abajo. Elige y activa el modificador. Termina cuando todo se apagó.
func _show_modifier_intro() -> void:
	var mod := PhaseModifiers.pick(_rng)
	_active_modifier = mod["id"]
	for player in get_tree().get_nodes_in_group("players"):
		PhaseModifiers.apply_to_player(player, _active_modifier)
	_mod_icon.texture = mod["icon"]
	_mod_name.text = mod["name"]
	_mod_desc.text = mod["description"]
	# El banner se queda fijo (sin apagarse solo)
	_banner.text = "FASE %d" % phase
	_banner.modulate.a = 1.0
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	# Un frame para que el layout calcule la posición final de la caja
	await get_tree().process_frame
	var banner_y := _banner.position.y
	var final_pos := _mod_box.position + Vector2(0.0, 40.0)
	_mod_box.position = final_pos + Vector2(0.0, 320.0)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(_banner, "position:y", banner_y - 200.0, 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(_mod_box, "position", final_pos, 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(_mod_box, "modulate:a", 1.0, 0.5)
	await rise.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(3.5).timeout
	if not is_inside_tree():
		return
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_banner, "modulate:a", 0.0, 0.5)
	fade.tween_property(_mod_box, "modulate:a", 0.0, 0.5)
	await fade.finished
	if is_instance_valid(_banner):
		_banner.position.y = banner_y
