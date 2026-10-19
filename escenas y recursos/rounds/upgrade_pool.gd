class_name UpgradePool
extends RefCounted
## Catálogo de todas las mejoras posibles. Para agregar una nueva,
## sumá una línea a la lista: título, descripción, categoría y efecto.
## Con .with_icon("archivo.png") le ponés el icono que se ve en su carta
## (se busca en ICON_DIR; si el archivo no existe se usa un icono de reemplazo).
## Todas se pueden acumular (elegirlas varias veces).

## Carpeta de los iconos de las mejoras (PNG)
const ICON_DIR := "res://sprites/mejoras/"


static func create_all() -> Array:
	var C := Upgrade.Category
	return [
		
	]
