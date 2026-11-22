extends CharacterBody2D
## BOSS 1: eˣ
## - eˣ iken turev islemez, cunku (eˣ)′ = eˣ.
## - Logaritma ultisi (E) onu x'e cevirir: ln(eˣ) = x. Birkac saniye savunmasiz kalir.
## - Sonra turev: x -> 1 -> 0 ve boss bir can kaybeder. Sure dolarsa eˣ'e geri doner.
## - Kucuk kagitlar cagirir; onlari oldurmek ulti barini doldurur (oyuncu sikismaz).
## - Saldirisi ustel: 4, 8, 16 mermilik halkalar (2², 2³, 2⁴).

signal lives_changed(lives: int, max_lives: int)
signal summon_requested(polys: Array)
signal hint(text: String, duration: float)
signal defeated
signal objective(text: String)

enum State { EXP, X, ONE, HURT, DEAD }

const BULLET := preload("res://scenes/enemy_bullet.tscn")
const MATH_FONT := preload("res://assets/fonts/math_font.ttf")
const COLOR_IMMUNE := Color(1, 0.35, 0.3)
const COLOR_WEAK := Color(0.4, 1, 0.5)

@export var boss_title := "eˣ"
@export var max_lives := 3
@export var vulnerable_time := 7.0     # logaritmadan sonra kac saniye savunmasiz
@export var ring_interval := 2.4       # halka saldirisi araligi (can azaldikca hizlanir)
@export var summon_interval := 7.0
@export var max_minions := 3
@export var contact_radius := 95.0     # bu kadar yaklasirsan hasar alirsin
@export var hover_amount := 30.0
@export var hit_radius := 100.0        # Agir Atlama menziline eklenir

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var timer_label: Label = $TimerLabel

var state := State.EXP
var lives: int
var ring_timer := 1.5
var summon_timer := 0.5
var ring_step := 0
var vuln_left := 0.0
var t := 0.0
var home := Vector2.ZERO
var base_scale := Vector2.ONE
var taunt_cd := 0.0
var first_taunt := true
var player = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("log_targets")
	lives = max_lives
	home = global_position
	base_scale = sprite.scale
	player = get_tree().get_first_node_in_group("player")
	_set_formula("eˣ", COLOR_IMMUNE)
	timer_label.hide()
	lives_changed.emit(lives, max_lives)
	objective.emit("Türev işlemez  →  ulti dolunca [E] Logaritma")
	# giris animasyonu
	sprite.scale = base_scale * 0.2
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "scale", base_scale, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.4)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	t += delta
	taunt_cd -= delta

	match state:
		State.EXP:
			global_position = home + Vector2(sin(t * 0.8) * hover_amount, sin(t * 1.6) * hover_amount * 0.5)
			sprite.scale = base_scale * (1.0 + sin(t * 3.0) * 0.04)   # nefes alma
			ring_timer -= delta
			if ring_timer <= 0.0:
				ring_timer = ring_interval * (0.6 + 0.4 * float(lives) / max_lives)
				_fire_ring()
			summon_timer -= delta
			if summon_timer <= 0.0:
				summon_timer = summon_interval
				_try_summon()
		State.X, State.ONE:
			sprite.rotation = sin(t * 22.0) * 0.03   # sersemlemis titreme
			vuln_left -= delta
			timer_label.text = "%d sn" % ceili(vuln_left)
			if vuln_left <= 0.0:
				_back_to_exp(false)

	_contact_damage()


# ---------------------------------------------------------------- saldirilar
func _fire_ring() -> void:
	var counts := [4, 8, 16]
	var labels := ["2²", "2³", "2⁴"]
	var n: int = counts[ring_step]
	_float_text(labels[ring_step], Color(1, 0.55, 0.3))
	ring_step = (ring_step + 1) % counts.size()
	var offset := randf() * TAU
	for i in n:
		var a := offset + TAU * i / n
		var b = BULLET.instantiate()
		b.direction = Vector2(cos(a), sin(a))
		get_parent().add_child(b)
		b.global_position = global_position


func _try_summon() -> void:
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self:
			count += 1
	var polys := [[0, 0, 1], [0, 2]]   # x² ve 2x
	var n := mini(polys.size(), max_minions - count)
	if n > 0:
		summon_requested.emit(polys.slice(0, n))


func _contact_damage() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) < contact_radius:
		player.take_damage(1)


# ---------------------------------------------------------------- matematik
## Turev mermisi ve Agir Atlama bunu cagirir.
func take_derivative() -> void:
	match state:
		State.EXP:
			_flash(Color(0.6, 0.8, 1.0))
			if taunt_cd <= 0.0:
				taunt_cd = 1.0
				_float_text("(eˣ)′ = eˣ", Color.WHITE)
			if first_taunt:
				first_taunt = false
				hint.emit("Türev işlemiyor! Ulti dolunca [E] ile Logaritma at.", 3.5)
		State.X:
			state = State.ONE
			_set_formula("1", COLOR_WEAK)
			_flash(Color.WHITE)
			_float_text("(x)′ = 1", COLOR_WEAK)
		State.ONE:
			_float_text("(1)′ = 0", COLOR_WEAK)
			_lose_life()


func can_take_log() -> bool:
	return state == State.EXP


## Logaritma ultisi bunu cagirir.
func take_log() -> void:
	if state != State.EXP:
		return
	state = State.X
	vuln_left = vulnerable_time
	_set_formula("x", COLOR_WEAK)
	_float_text("ln(eˣ) = x", Color(1, 0.85, 0.2))
	timer_label.show()
	sprite.modulate = Color(0.75, 0.85, 1.0)
	create_tween().tween_property(sprite, "scale", base_scale * 0.8, 0.25)
	hint.emit("Savunmasız! Şimdi türev at!", 1.8)
	objective.emit("Savunmasız!  Türev at:  x → 1 → 0")


func _lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives, max_lives)
	timer_label.hide()
	if lives <= 0:
		_die()
		return
	state = State.HURT
	_set_formula("0", Color.WHITE)
	_flash(Color(1, 0.3, 0.3))
	await get_tree().create_timer(1.2).timeout
	if state == State.HURT:
		_back_to_exp(true)


func _back_to_exp(after_hit: bool) -> void:
	state = State.EXP
	_set_formula("eˣ", COLOR_IMMUNE)
	objective.emit("Türev işlemez  →  ulti dolunca [E] Logaritma")
	timer_label.hide()
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	_float_text("Daha bitmedi!" if after_hit else "eˣ geri döndü!", COLOR_IMMUNE)
	ring_timer = 1.0
	summon_timer = 0.3   # hemen kagit cagir ki ulti tekrar dolsun


func _die() -> void:
	state = State.DEAD
	objective.emit("")
	remove_from_group("enemies")
	remove_from_group("log_targets")
	$CollisionShape2D.set_deferred("disabled", true)
	_set_formula("0", Color.WHITE)
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "rotation", 1.6, 1.2)
	tw.tween_property(sprite, "scale", base_scale * 0.1, 1.2)
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	await tw.finished
	defeated.emit()
	queue_free()


# ---------------------------------------------------------------- gorsel
func _set_formula(text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.25)


func _flash(color: Color) -> void:
	var back := Color(0.75, 0.85, 1.0) if state == State.X or state == State.ONE else Color.WHITE
	sprite.modulate = color
	create_tween().tween_property(sprite, "modulate", back, 0.2)


func _float_text(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", MATH_FONT)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(320, 50)
	get_parent().add_child(l)
	l.global_position = global_position + Vector2(-160, -215 + randf_range(-15, 15))
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
