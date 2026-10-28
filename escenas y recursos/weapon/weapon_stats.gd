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

@export_group("Balas")
## Multiplicador del tamaño de la bala (afecta también su colisión)
@export var bullet_scale: float = 1.0
## Balas por disparo (triple shot, escopeta...)
@export var bullets_per_shot: int = 1
## Ángulo entre bala y bala cuando se disparan varias a la vez
@export var fan_angle_degrees: float = 10.0

@export_group("Recarga y cargador")
## true = cada disparo vacía el cargador entero (escopeta)
@export var empties_magazine: bool = false
## Multiplica el efecto de las mejoras de recarga que se agarren desde ahora.
## 1 = normal, -0.5 = cada mejora de recarga hace el efecto contrario a la mitad (escopeta)
@export var reload_upgrade_multiplier: float = 1.0

@export_group("Veneno")
## Daño por tick = daño del arma × este valor (0 = sin veneno)
@export var poison_ratio: float = 0.0
@export var poison_duration: float = 3.0
## Segundos entre tick y tick
@export var poison_interval: float = 0.5

@export_group("Balas explosivas")
@export var explosive_bullets: bool = false
@export var explosion_radius: float = 0.0
## Daño de la explosión = daño de la bala × este valor
@export var explosion_damage_ratio: float = 0.0

@export_group("Apariencia")
## Cambia el dibujo del arma: "revolver" (por defecto) o "escopeta"
@export var weapon_style: StringName = &"revolver"
