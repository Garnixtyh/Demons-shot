class_name WeaponStats
extends Resource
## Atributos del arma. Las mejoras de cada ronda van a modificar estos valores.

@export var damage: float = 20.0
@export var bullet_speed: float = 900.0
@export var bullet_lifetime: float = 1.5
## Disparos por segundo
@export var fire_rate: float = 4.0
@export var magazine_size: int = 12
## Segundos que tarda la recarga
@export var reload_time: float = 1.2
## Dispersión máxima en grados (0 = puntería perfecta)
@export var spread_degrees: float = 1.5
## true = mantener click dispara en ráfaga; false = un disparo por click
@export var automatic: bool = true
