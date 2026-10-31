extends Node2D
## Script para las versiones de PRUEBA de un mapa (igual que el de la sala de pruebas):
## - Muestra munición, vida, ronda y mejoras elegidas en el HUD.
## - N salta a la siguiente ronda (abre el selector de mejoras a mano).
## Necesita en la escena: un nodo Player y un RoundManager.
## El HUD (con AmmoLabel, HealthLabel, RoundLabel y UpgradesLabel) es OPCIONAL:
## si falta alguno de esos nodos, simplemente no se muestra ese dato.

@onready var _player = $Player
@onready var _weapon: Weapon = $Player.get_weapon()
@onready var _ammo_label := get_node_or_null("HUD/AmmoLabel") as Label
@onready var _health_label := get_node_or_null("HUD/HealthLabel") as Label
@onready var _round_label := get_node_or_null("HUD/RoundLabel") as Label
@onready var _upgrades_label := get_node_or_null("HUD/UpgradesLabel") as Label
@onready var _round_manager: RoundManager = $RoundManager

var _taken: Dictionary = {}


func _ready() -> void:
	_weapon.ammo_changed.connect(_on_ammo_changed)
	_weapon.reload_started.connect(func(): _set_text(_ammo_label, "Recargando..."))
	_on_ammo_changed(_weapon.ammo, _weapon.stats.magazine_size)
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(func(): _set_text(_health_label, "Muerto, reapareciendo..."))
	_on_health_changed(_player.health, _player.max_health)
	_round_manager.round_started.connect(_on_round_started)
	_round_manager.upgrade_applied.connect(_on_upgrade_applied)
	_set_text(_round_label, "Ronda   (N: siguiente ronda)")


## Escribe en un Label del HUD solo si existe en la escena.
func _set_text(label: Label, text: String) -> void:
	if label != null:
		label.text = text


func _unhandled_input(event: InputEvent) -> void:
	# Solo para pruebas: N salta a la siguiente ronda
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		_round_manager.start_round()


func _on_round_started(round_number: int) -> void:
	_set_text(_round_label, "Ronda %d   (N: siguiente ronda)" % round_number)


func _on_upgrade_applied(upgrade: Upgrade) -> void:
	_taken[upgrade.title] = _taken.get(upgrade.title, 0) + 1
	var lines := PackedStringArray()
	for title in _taken:
		lines.append("%s x%d" % [title, _taken[title]])
	_set_text(_upgrades_label, "Mejoras:\n" + "\n".join(lines))


func _on_health_changed(current: float, maximum: float) -> void:
	_set_text(_health_label, "Vida: %d / %d" % [current, maximum])


func _on_ammo_changed(current: int, maximum: int) -> void:
	_set_text(_ammo_label, "Munición: %d / %d" % [current, maximum])
