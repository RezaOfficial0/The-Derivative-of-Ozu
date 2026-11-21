extends CharacterBody2D
## Sinav kagidi dusman. Cani = ustundeki polinom.
## coeffs[i] = x^i katsayisi.  [0, 0, 1] = x²   [0, 3] = 3x   [5] = 5
## Her turev vurusu dereceyi 1 dusurur, polinom 0 olunca kagit yok olur.
## x³ -> 3x² -> 6x -> 6 -> 0  (derece + 1 vurus)
## Polinom kagidin icine yazilir (Label), sprite 2x2 sheet: paper_walk.png

signal died

const BULLET := preload("res://scenes/enemy_bullet.tscn")
const SUP := {"0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
		"5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"}

@export var coeffs: Array[float] = [0.0, 0.0, 1.0]
@export var speed := 90.0
@export var fire_interval := 1.6
@export var keep_distance := 280.0   # oyuncuya bu mesafede durup ates eder
@export var ulti_reward := 1
@export var walk_fps := 8.0          # yurume animasyonu hizi (kare / saniye)

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var player = null
var fire_timer := 0.0
var strafe_dir := 1.0
var flip_cd := 0.0
var dying := false
var anim_time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	fire_timer = randf_range(0.8, fire_interval + 0.8)  # hepsi ayni anda ates etmesin
	strafe_dir = [-1.0, 1.0].pick_random()
	label.pivot_offset = label.size / 2.0
	label.rotation = deg_to_rad(randf_range(-6.0, 6.0))  # el yazisi gibi hafif egik
	_update_label()
	# dogma animasyonu
	var base := sprite.scale
	sprite.scale = base * 0.1
	create_tween().tween_property(sprite, "scale", base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)

	if dist > keep_distance + 40.0:
		velocity = dir * speed
	elif dist < keep_distance - 40.0:
		velocity = -dir * speed
	else:
		velocity = dir.orthogonal() * strafe_dir * speed * 0.6
	move_and_slide()
	_animate(delta)

	flip_cd -= delta
	if get_slide_collision_count() > 0 and flip_cd <= 0.0:
		strafe_dir *= -1.0
		flip_cd = 0.6

	fire_timer -= delta
	if fire_timer <= 0.0 and not player.is_dead:
		fire_timer = fire_interval * randf_range(0.85, 1.15)
		_shoot(dir)


## Hareket ederken 4 kareli yurume animasyonu, dururken ilk kare.
func _animate(delta: float) -> void:
	if get_real_velocity().length() > 10.0:
		anim_time += delta * walk_fps
		sprite.frame = int(anim_time) % 4
	else:
		sprite.frame = 0


func _shoot(dir: Vector2) -> void:
	var b = BULLET.instantiate()
	b.direction = dir
	get_parent().add_child(b)
	b.global_position = global_position


## Turev mermisi ve Agir Atlama bunu cagirir.
func take_derivative() -> void:
	if dying:
		return
	var new_c: Array[float] = []
	for i in range(1, coeffs.size()):
		new_c.append(coeffs[i] * i)
	coeffs = new_c
	_hit_flash()
	if _is_zero():
		_die()
	else:
		_update_label()


## Boss yenilince kalan kagitlari temizlemek icin.
func kill() -> void:
	if not dying:
		_die()


func _die() -> void:
	dying = true
	remove_from_group("enemies")
	label.text = "0"
	$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	if player != null and is_instance_valid(player) and player.has_method("add_ulti"):
		player.add_ulti(ulti_reward)
	died.emit()
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "scale", sprite.scale * 1.5, 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)


func _is_zero() -> bool:
	for c in coeffs:
		if not is_zero_approx(c):
			return false
	return true


func _hit_flash() -> void:
	sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	label.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.2)


func _update_label() -> void:
	var t := poly_to_string()
	label.text = t
	# uzun polinomlar kagida sigsin
	var fs := 30 if t.length() <= 4 else (22 if t.length() <= 7 else 17)
	label.add_theme_font_size_override("font_size", fs)


func poly_to_string() -> String:
	var parts: PackedStringArray = []
	for i in range(coeffs.size() - 1, -1, -1):
		var c: float = coeffs[i]
		if is_zero_approx(c):
			continue
		var cs := _num(c)
		var one := is_equal_approx(c, 1.0)
		if i == 0:
			parts.append(cs)
		elif i == 1:
			parts.append(("" if one else cs) + "x")
		else:
			parts.append(("" if one else cs) + "x" + _sup(i))
	return " + ".join(parts) if parts.size() > 0 else "0"


func _num(c: float) -> String:
	if is_equal_approx(c, roundf(c)):
		return str(int(roundf(c)))
	return str(snappedf(c, 0.01))


func _sup(n: int) -> String:
	var s := ""
	for ch in str(n):
		s += SUP[ch]
	return s
