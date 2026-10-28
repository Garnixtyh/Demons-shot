class_name StatsHud
extends CanvasLayer
## HUD con las stats ACTUALES del jugador (vida, velocidad, daño, cadencia, recarga...).
## Se actualiza solo: mejoras, vida máxima y cambios de arma se ven al instante.
## Ponelo en el mapa instanciando stats_hud.tscn. Se muestra/oculta con la tecla F2.

## Tecla para mostrar/ocultar
@export var toggle_key: Key = KEY_F2
## Segundos entre actualizaciones del texto
@export var refresh_time: float = 0.15
@export var panel_position: Vector2 = Vector2(12, 90)

var _label: Label
var _panel: PanelContainer
var _time: float = 0.0


func _ready() -> void:
	layer = 4
	_panel = PanelContainer.new()
	_panel.position = panel_position
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	if _time >= refresh_time:
		_time = 0.0
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		_panel.visible = not _panel.visible


## El jugador de ESTA PC (en red, el que controlás vos).
func _find_player() -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player
	return null


func _refresh() -> void:
	var player := _find_player()
	if player == null or not player.has_method("get_weapon"):
		_label.text = "Sin jugador"
		return
	var weapon := player.get_weapon() as Weapon
	var lines: PackedStringArray = []
	lines.append("— JUGADOR —")
	lines.append("Vida: %d / %d" % [roundi(player.health), roundi(player.max_health)])
	lines.append("Velocidad: %d" % roundi(player.max_speed))
	if weapon != null and weapon.stats != null:
		var s := weapon.stats
		lines.append("— ARMA —")
		lines.append("Daño: %s" % _num(s.damage))
		if s.bullets_per_shot > 1:
			lines.append("Balas por disparo: %d" % s.bullets_per_shot)
		lines.append("Cadencia: %s/s" % _num(s.fire_rate))
		lines.append("Cargador: %d / %d" % [weapon.ammo, s.magazine_size])
		lines.append("Recarga: %s s" % _num(s.reload_time))
		lines.append("Alcance: %s s" % _num(s.bullet_lifetime))
		lines.append("Vel. de bala: %d" % roundi(s.bullet_speed))
		lines.append("Tamaño de bala: x%s" % _num(s.bullet_scale))
		if s.poison_ratio > 0.0:
			lines.append("Veneno: %d%% del daño" % roundi(s.poison_ratio * 100.0))
		if s.explosive_bullets:
			lines.append("Explosión: radio %d, %d%% del daño" % [roundi(s.explosion_radius), roundi(s.explosion_damage_ratio * 100.0)])
	_label.text = "\n".join(lines)


func _num(value: float) -> String:
	return "%.2f" % value if absf(value - roundf(value)) > 0.005 else str(roundi(value))
