extends CharacterBody2D
## Can Deha. Sprite: can_deha_dirs.png (4 yon). WASD ile yuru, fare ile nisan al, sol tik = turev, Q / Space = Agir Atlama.

signal hp_changed(hp: int, max_hp: int)
signal ulti_changed(value: int, max_value: int)
signal died
signal slammed
signal hint(text: String, duration: float)

const BULLET := preload("res://scenes/derivative_bullet.tscn")
const LOG_BULLET := preload("res://scenes/log_bullet.tscn")

## can_deha_dirs.png (2x2) karelerinin anlami
const FRAME_BACK := 0    # arkadan (yukari bakiyor)
const FRAME_SIDE := 1    # yandan (saga bakiyor, sola icin aynalanir)
const FRAME_FRONT := 2   # onden (asagi bakiyor)

@export var speed := 260.0
@export var max_hp := 5
@export var fire_cooldown := 0.25
@export var ulti_max := 8           # kac kagit oldurunce ulti dolar
@export var slam_radius := 190.0
@export var invuln_time := 0.7      # vurulduktan sonra kisa sure hasar almaz
@export var bob_height := 5.0       # yururken zipla-sallan miktari
@export var bob_speed := 14.0

@onready var sprite: Sprite2D = $Sprite2D

var hp: int
var ulti := 0
var fire_timer := 0.0
var invuln_timer := 0.0
var is_slamming := false
var is_dead := false
var base_scale := Vector2.ONE
var base_y := 0.0
var walk_t := 0.0


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	base_scale = sprite.scale
	base_y = sprite.position.y
	hp_changed.emit(hp, max_hp)
	ulti_changed.emit(ulti, ulti_max)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	fire_timer -= delta
	invuln_timer -= delta

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()

	_update_facing()
	_walk_bob(delta)

	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		_shoot()
	if Input.is_action_just_pressed("ulti_slam") and ulti >= ulti_max and not is_slamming:
		_heavy_slam()
	if Input.is_action_just_pressed("ulti_log"):
		_try_log()


## Can Deha farenin oldugu yone bakar.
func _update_facing() -> void:
	var aim := get_global_mouse_position() - global_position
	if absf(aim.x) > absf(aim.y):
		sprite.frame = FRAME_SIDE
		sprite.flip_h = aim.x < 0.0
	elif aim.y < 0.0:
		sprite.frame = FRAME_BACK
		sprite.flip_h = false
	else:
		sprite.frame = FRAME_FRONT
		sprite.flip_h = aim.x < 0.0


## Yurume karesi olmadigi icin koddan yurume hissi: hafif ziplama + sallanma.
func _walk_bob(delta: float) -> void:
	if velocity.length() > 10.0:
		walk_t += delta * bob_speed
		sprite.position.y = base_y - absf(sin(walk_t)) * bob_height
		sprite.rotation = sin(walk_t) * 0.07
	else:
		walk_t = 0.0
		sprite.position.y = lerpf(sprite.position.y, base_y, 0.3)
		sprite.rotation = lerpf(sprite.rotation, 0.0, 0.3)


func _shoot() -> void:
	fire_timer = fire_cooldown
	var b = BULLET.instantiate()
	b.direction = global_position.direction_to(get_global_mouse_position())
	get_parent().add_child(b)
	b.global_position = global_position


## Ustten gorunumde sahte ziplama: sprite buyuyup kuculur, inince etraftaki herkesin turevi alinir.
func _heavy_slam() -> void:
	is_slamming = true
	ulti = 0
	ulti_changed.emit(ulti, ulti_max)

	var tw := create_tween()
	tw.tween_property(sprite, "scale", base_scale * 1.8, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", base_scale, 0.12).set_ease(Tween.EASE_IN)
	await tw.finished

	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node2D
		if n and n.global_position.distance_to(global_position) <= slam_radius:
			if n.has_method("take_derivative"):
				n.take_derivative()
	_shockwave()
	slammed.emit()
	is_slamming = false


func _shockwave() -> void:
	var ring := Line2D.new()
	ring.width = 20.0
	ring.default_color = Color(1, 1, 1, 0.9)
	for i in 33:
		var a := TAU * i / 32.0
		ring.add_point(Vector2(cos(a), sin(a)) * slam_radius)
	get_parent().add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector2(0.2, 0.2)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2.ONE, 0.25)
	tw.tween_property(ring, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)


## Logaritma ultisi (E): sadece logaritmaya acik bir hedef (boss) varken calisir.
func _try_log() -> void:
	if ulti < ulti_max:
		hint.emit("Ulti barı dolmadı! Kâğıt yok et.", 1.5)
		return
	var target = null
	for n in get_tree().get_nodes_in_group("log_targets"):
		if n.has_method("can_take_log") and n.can_take_log():
			target = n
			break
	if target == null:
		hint.emit("Logaritmanın işe yarayacağı bir hedef yok.", 1.8)
		return
	ulti = 0
	ulti_changed.emit(ulti, ulti_max)
	var b = LOG_BULLET.instantiate()
	b.target = target
	get_parent().add_child(b)
	b.global_position = global_position


func add_ulti(amount: int) -> void:
	ulti = mini(ulti + amount, ulti_max)
	ulti_changed.emit(ulti, ulti_max)


func take_damage(amount: int) -> void:
	if is_dead or is_slamming or invuln_timer > 0.0:
		return
	hp = maxi(hp - amount, 0)
	invuln_timer = invuln_time
	hp_changed.emit(hp, max_hp)
	sprite.modulate = Color(1, 0.3, 0.3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, invuln_time)
	if hp == 0:
		is_dead = true
		sprite.modulate = Color(0.4, 0.4, 0.4)
		died.emit()
