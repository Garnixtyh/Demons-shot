class_name ComboHud
extends CanvasLayer
## HUD del combo (arriba a la derecha): kills, rango, barra de tiempo y puntos acumulados.
## Al terminar el combo muestra un cartel con el resultado. También muestra los puntos de la tienda.
## Se arma por código; lo crea el ComboTracker.

const RANK_COLORS := {
	"FC": Color(0.45, 1.0, 0.95),
	"S": Color(1.0, 0.85, 0.2),
	"A": Color(1.0, 0.55, 0.15),
	"B": Color(0.4, 0.9, 0.4),
	"C": Color(0.4, 0.7, 1.0),
	"D": Color(0.75, 0.75, 0.75),
}

var tracker: ComboTracker = null

var _box: VBoxContainer
var _count_label: Label
var _rank_label: Label
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat
var _bar_tween: Tween
var _pot_label: Label
var _points_label: Label
var _banner: Label
var _banner_tween: Tween
var _pop_tween: Tween


func _ready() -> void:
	layer = 6
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_box.offset_left = -240.0
	_box.offset_right = -20.0
	_box.offset_top = 20.0
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)

	_points_label = _make_label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	_points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_box.add_child(_points_label)

	_count_label = _make_label(34, HORIZONTAL_ALIGNMENT_RIGHT)
	_count_label.pivot_offset = Vector2(220, 20)
	_box.add_child(_count_label)
	_rank_label = _make_label(72, HORIZONTAL_ALIGNMENT_RIGHT)
	_box.add_child(_rank_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(220, 16)
	_bar.max_value = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Estilos propios para que la barra se vea siempre (aunque el tema del proyecto la oculte)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.6)
	bar_bg.set_border_width_all(2)
	bar_bg.border_color = Color(1, 1, 1, 0.8)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = Color.WHITE
	_bar.add_theme_stylebox_override("background", bar_bg)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	_box.add_child(_bar)
	_pot_label = _make_label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	_box.add_child(_pot_label)

	# Cartel del resultado (centro, arriba)
	_banner = _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400.0
	_banner.offset_right = 400.0
	_banner.offset_top = 90.0
	_banner.offset_bottom = 150.0
	_banner.pivot_offset = Vector2(400, 30)
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	if tracker != null:
		tracker.combo_changed.connect(_on_combo_changed)
		tracker.combo_ended.connect(_on_combo_ended)
		tracker.combo_broken.connect(_on_combo_broken)
		tracker.time_extended.connect(_on_time_extended)
		tracker.time_reduced.connect(_on_time_reduced)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if tracker == null or tracker.player == null:
		return
	# Solo el jugador de ESTA PC ve el HUD (en red, las copias de los demás no)
	var mine: bool = tracker.player.is_multiplayer_authority()
	_box.visible = mine
	_banner.visible = mine
	if not mine:
		return
	_points_label.text = "Puntos: %d" % tracker.player.points
	var active := tracker.is_active()
	_count_label.visible = active
	_rank_label.visible = active
	_bar.visible = active
	_pot_label.visible = active
	if not active:
		return
	var rank := tracker.current_rank()
	var color: Color = RANK_COLORS.get(rank, Color.WHITE)
	_count_label.text = "COMBO x%d" % tracker.kills
	_count_label.add_theme_color_override("font_color", color)
	_rank_label.text = rank
	_rank_label.add_theme_color_override("font_color", color)
	var full := maxf(tracker.max_time, tracker.combo_time)
	_bar.value = clampf(tracker.time_left / full, 0.0, 1.0)
	_bar_fill.bg_color = color
	_pot_label.text = "+%d pts  ·  %.1f s" % [tracker.pot, tracker.time_left]


## Cada kill: el contador "salta"
func _on_combo_changed(_kills: int, _pot: int) -> void:
	if _pop_tween != null:
		_pop_tween.kill()
	_count_label.scale = Vector2.ONE * 1.4
	_pop_tween = create_tween()
	_pop_tween.tween_property(_count_label, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un golpe sumó tiempo: la barra destella
func _on_time_extended(_time_left: float) -> void:
	if _bar_tween != null:
		_bar_tween.kill()
	_bar.modulate = Color(2.5, 2.5, 2.5)
	_bar_tween = create_tween()
	_bar_tween.tween_property(_bar, "modulate", Color.WHITE, 0.2)


## El jugador recibió daño: la barra destella en rojo
func _on_time_reduced(_time_left: float) -> void:
	if _bar_tween != null:
		_bar_tween.kill()
	_bar.modulate = Color(2.5, 0.4, 0.4)
	_bar_tween = create_tween()
	_bar_tween.tween_property(_bar, "modulate", Color.WHITE, 0.3)


func _on_combo_ended(kills: int, points: int, rank: String) -> void:
	var color: Color = RANK_COLORS.get(rank, Color.WHITE)
	_show_banner("¡COMBO x%d!  Rango %s  +%d puntos" % [kills, rank, points], color)


func _on_combo_broken(kills: int, lost_points: int) -> void:
	_show_banner("¡Combo roto! (x%d, -%d pts)" % [kills, lost_points], Color(1.0, 0.35, 0.35))


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.scale = Vector2.ONE * 1.3
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	return label
