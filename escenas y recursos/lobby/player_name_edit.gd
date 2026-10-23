class_name PlayerNameEdit
extends LineEdit
## Poné un LineEdit en la escena de lobbys disponibles (y donde quieras editar el nombre)
## y asignale este script. Se sincroniza solo con PlayerProfile.


func _ready() -> void:
	max_length = PlayerProfile.MAX_LENGTH
	placeholder_text = "Tu nombre"
	text = PlayerProfile.player_name
	text_submitted.connect(_commit)
	focus_exited.connect(func(): _commit(text))
	PlayerProfile.name_changed.connect(func(n: String): if text != n: text = n)


func _commit(new_text: String) -> void:
	PlayerProfile.player_name = new_text
	text = PlayerProfile.player_name  # vuelve al valor válido si quedó vacío
