class_name EnemyBase
extends CharacterBody2D
## Base de los enemigos del modo un jugador (pollito, murciélago, cangrejo, velador...).
##
## Ya trae lo común:
##  - Recibir daño (las balas llaman take_damage): destello blanco y barra de vida.
##  - Cada golpe alarga el combo del jugador (register_hit) y cada muerte suma un kill (register_kill).
##  - Daño por contacto opcional (nodo Area2D "Contacto" + contact_damage > 0).
##  - Atraviesa al jugador (no se empujan): solo el daño/retroceso lo afecta.
##  - Reproduce animaciones del AnimationPlayer del enemigo (_play / _play_loop).
##
## Estructura esperada de la escena: CharacterBody2D (este script) con un nodo "Visual" (Node2D con
## los sprites; se voltea según hacia dónde mira), un AnimationPlayer en cualquier lado, un
## CollisionShape2D para el cuerpo y, si hace daño por contacto, un Area2D "Contacto".
## Para hacer un enemigo nuevo: extender esta clase y sobreescribir _ai().

const BleedEffect := preload("res://escenas y recursos/weapon/bleed_effect.gd")

signal died(enemy: EnemyBase)

@export var max_health: float = 40.0
@export var gravity: float = 1800.0
@export_group("Daño por contacto")
## Daño al tocar al jugador (0 = no daña por contacto)
@export var contact_damage: float = 0.0
## Segundos entre un daño por contacto y el siguiente
@export var contact_cooldown: float = 0.8
## Multiplicador del retroceso que le da al jugador
@export var knockback_scale: float = 1.0
@export_group("Aspecto")
## El sprite original mira a la derecha (false = mira a la izquierda)
@export var faces_right: bool = true
@export var show_health_bar: bool = true
@export var health_bar_size: Vector2 = Vector2(70, 7)
## Posición de la barra de vida (relativa a los pies del enemigo)
@export var health_bar_offset: Vector2 = Vector2(0, -150)
@export_group("")

var health: float = 0.0
## true mientras recibe daño que NO alarga el combo (carta The Death): ni el golpe ni el kill suman tiempo
var combo_silent: bool = false
var dead: bool = false
## Hacia dónde mira: 1 = derecha, -1 = izquierda
var facing: float = 1.0
## false para enemigos voladores
var uses_gravity: bool = true

var _visual: Node2D
var _anim: AnimationPlayer
var _contact_area: Area2D
var _contact_timer: float = 0.0
var _ignored: Dictionary = {}


func _ready() -> void:
	# "targets": Panchu y otras cosas lo persiguen
	add_to_group("targets")
	add_to_group("enemies")
	health = max_health
	_visual = get_node_or_null("Visual") as Node2D
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_contact_area = get_node_or_null("Contacto") as Area2D


func _physics_process(delta: float) -> void:
	if dead:
		return
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	var player := _find_player()
	if player != null:
		_ignore_player(player)
	if uses_gravity:
		velocity.y = minf(velocity.y + gravity * delta, 1200.0)
	_ai(delta, player)
	move_and_slide()
	if player != null:
		_check_contact()


## Lógica del enemigo (la escribe cada enemigo). Solo cambia `velocity`: el movimiento lo aplica la base.
func _ai(_delta: float, _player: Node2D) -> void:
	pass


## true si ahora mismo puede dañar por contacto (el cangrejo solo daña al embestir)
func _can_hurt_on_contact() -> bool:
	return true


## Se llama después de dañar al jugador por contacto
func _on_contact_hit(_player: Node) -> void:
	pass


## Se llama cuando recibe un golpe sin morir
func _on_hurt() -> void:
	pass


## Se llama al morir (antes de desaparecer)
func _on_died() -> void:
	pass


# ---------------------------------------------------------------- Daño

func take_damage(amount: float) -> void:
	if dead:
		return
	health -= amount
	queue_redraw()
	_flash()
	# Cada golpe alarga el combo del jugador
	get_tree().call_group("players", "register_hit", self)
	if health <= 0.0:
		_die()
		return
	_on_hurt()


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	queue_redraw()
	died.emit(self)
	# Suma un kill al combo del jugador
	get_tree().call_group("players", "register_kill", self)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
	_on_died()
	var target: CanvasItem = _visual if _visual != null else self
	var tween := create_tween().set_parallel(true)
	tween.tween_property(target, "modulate:a", 0.0, 0.35)
	tween.tween_property(target, "scale", target.scale * 0.8, 0.35)
	await tween.finished
	queue_free()


## Daña al jugador (con retroceso desde la posición del enemigo)
func hurt_player(player: Node, amount: float, knockback_mult: float = 1.0) -> void:
	if player.has_method("take_damage"):
		player.take_damage(amount, global_position, knockback_mult, self)


## Sangrado (carta Justice): daño cada `interval` s durante `duration` s, con tinte rojo.
func apply_bleed(damage: float, duration: float, interval: float) -> void:
	if dead:
		return
	var effect := get_node_or_null("BleedEffect")
	if effect == null:
		effect = BleedEffect.new()
		effect.name = "BleedEffect"
		effect.refresh(damage, duration, interval)
		add_child(effect)
	else:
		effect.refresh(damage, duration, interval)


func _check_contact() -> void:
	if _contact_area == null or contact_damage <= 0.0 or _contact_timer > 0.0 or not _can_hurt_on_contact():
		return
	for body in _contact_area.get_overlapping_bodies():
		if body.is_in_group("players"):
			hurt_player(body, contact_damage, knockback_scale)
			_contact_timer = contact_cooldown
			_on_contact_hit(body)
			break


func _flash() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(2, 2, 2)
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(self) and not dead:
		_visual.modulate = Color.WHITE


# ---------------------------------------------------------------- Utilidades

## Mira hacia `dir` (<0 izquierda, >0 derecha): voltea el nodo Visual
func face(dir: float) -> void:
	if is_zero_approx(dir):
		return
	facing = signf(dir)
	if _visual != null:
		var sign_x := facing if faces_right else -facing
		_visual.scale.x = absf(_visual.scale.x) * sign_x


## Reproduce una animación del AnimationPlayer (si existe). `speed` = velocidad de reproducción.
func _play(anim_name: StringName, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed
	if _anim.current_animation != anim_name or not _anim.is_playing():
		_anim.play(anim_name)


## Igual que _play pero fuerza que la animación se repita
func _play_loop(anim_name: StringName, speed: float = 1.0) -> void:
	if _anim != null and _anim.has_animation(anim_name):
		var animation := _anim.get_animation(anim_name)
		if animation.loop_mode == Animation.LOOP_NONE:
			animation.loop_mode = Animation.LOOP_LINEAR
	_play(anim_name, speed)


func _pause_anim() -> void:
	if _anim != null:
		_anim.pause()


## Jugador vivo más cercano (modo un jugador: el único)
func _find_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("players") as Node2D
	if player == null or ("is_dead" in player and player.is_dead):
		return null
	return player


## El enemigo y el jugador se atraviesan (no se empujan ni se traban)
func _ignore_player(player: Node2D) -> void:
	if not _ignored.has(player):
		_ignored[player] = true
		add_collision_exception_with(player)


func _draw() -> void:
	if not show_health_bar or dead or health >= max_health:
		return
	var rect := Rect2(health_bar_offset - Vector2(health_bar_size.x * 0.5, 0.0), health_bar_size)
	draw_rect(rect, Color(0, 0, 0, 0.7))
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), Color(0.85, 0.2, 0.2))
