extends Node2D
## Script para las versiones de PRUEBA de un mapa (igual que el de la sala de pruebas):
## - Muestra munición, vida, ronda y mejoras elegidas en el HUD.
## - N salta a la siguiente ronda (abre el selector de mejoras a mano).
## Necesita en la escena: un nodo Player, un RoundManager y un HUD con
## AmmoLabel, HealthLabel, RoundLabel y UpgradesLabel.

@onready var _player = $Player
@onready var _weapon: Weapon = $Player.get_weapon()
@onready var _ammo_label: Label = $HUD/AmmoLabel
@onready var _health_label: Label = $HUD/HealthLabel
@onready var _round_label: Label = $HUD/RoundLabel
@onready var _upgrades_label: Label = $HUD/UpgradesLabel
@onready var _round_manager: RoundManager = $RoundManager

var _taken: Dictionary = {}


func _ready() -> void:
	_weapon.ammo_changed.connect(_on_ammo_changed)
	_weapon.reload_started.connect(func(): _ammo_label.text = "Recargando...")
	_on_ammo_changed(_weapon.ammo, _weapon.stats.magazine_size)
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(func(): _health_label.text = "Muerto, reapareciendo...")
	_on_health_changed(_player.health, _player.max_health)
	_round_manager.round_started.connect(_on_round_started)
	_round_manager.upgrade_applied.connect(_on_upgrade_applied)
	_round_label.text = "Ronda   (N: siguiente ronda)"


func _unhandled_input(event: InputEvent) -> void:
	# Solo para pruebas: N salta a la siguiente ronda
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		_round_manager.start_round()


func _on_round_started(round_number: int) -> void:
	_round_label.text = "Ronda %d   (N: siguiente ronda)" % round_number


func _on_upgrade_applied(upgrade: Upgrade) -> void:
	_taken[upgrade.title] = _taken.get(upgrade.title, 0) + 1
	var lines := PackedStringArray()
	for title in _taken:
		lines.append("%s x%d" % [title, _taken[title]])
	_upgrades_label.text = "Mejoras:\n" + "\n".join(lines)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_label.text = "Vida: %d / %d" % [current, maximum]


func _on_ammo_changed(current: int, maximum: int) -> void:
	_ammo_label.text = "Munición: %d / %d" % [current, maximum]
