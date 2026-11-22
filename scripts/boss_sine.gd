extends CharacterBody2D
## BOSS 2: (sin x)ˣ  -  iki ulti gerektirir (logaritmik turev).
## 1) (sin x)ˣ iken duz turev islemez. Logaritma (E):  ln y = x · ln(sin x)
## 2) Carpim kurali lazim: yakindan Agir Atlama (Q):   y′/y = ln(sin x) + x · cot x
## 3) Artik acik: turev mermileriyle bitir -> bir can gider. 3 can.
## Tanim kumesi: sin x ≤ 0 iken fonksiyon TANIMSIZ -> boss belli araliklarla
## hayalete doner, mermiler icinden gecer ve spiral saldiri yapar.

signal lives_changed(lives: int, max_lives: int)
signal summon_requested(polys: Array)
signal hint(text: String, duration: float)
signal defeated
signal objective(text: String)

enum State { DEFINED, UNDEFINED, LOGGED, OPEN, HURT, DEAD }

const BULLET := preload("res://scenes/enemy_bullet.tscn")
const MATH_FONT := preload("res://assets/fonts/math_font.ttf")
const C_IMMUNE := Color(1, 0.35, 0.3)
const C_LOGGED := Color(1, 0.85, 0.2)
const C_OPEN := Color(0.4, 1, 0.5)
const C_UNDEF := Color(0.75, 0.7, 0.85)

@export var boss_title := "(sin x)ˣ"
@export var max_lives := 3
@export var minion_reward := 3         # bu bossun kagitlari ulti barini 3 doldurur
@export var defined_time := 6.0        # tanimli kalma suresi
@export var undefined_time := 2.5      # tanimsiz (hayalet) kalma suresi
@export var open_time := 6.0           # atlamadan sonra savunmasiz kalma suresi
@export var open_hits := 4             # acikken kac turev gerekir
@export var fan_interval := 1.8        # dalgali mermi yelpazesi araligi
@export var summon_interval := 7.0
@export var max_minions := 3
@export var contact_radius := 100.0
@export var sway := 180.0              # sinus yolunda saga sola gezinme
@export var hit_radius := 115.0        # Agir Atlama menziline eklenir (buyuk govde)

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var timer_label: Label = $TimerLabel
@onready var shape: CollisionShape2D = $CollisionShape2D

var state := State.DEFINED
var lives: int
var t := 0.0
var anim_t := 0.0
var phase_timer := 0.0
var fan_timer := 1.5
var spiral_timer := 0.0
var spiral_angle := 0.0
var summon_timer := 0.5
var open_left := 0.0
var hits_left := 0
var home := Vector2.ZERO
var base_scale := Vector2.ONE
var taunt_cd := 0.0
var hinted_log := false
var hinted_slam := false
var player = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("log_targets")
	lives = max_lives
	home = global_position
	base_scale = sprite.scale
	player = get_tree().get_first_node_in_group("player")
	phase_timer = defined_time
	timer_label.hide()
	_set_formula("(sin x)ˣ", C_IMMUNE, 54)
	lives_changed.emit(lives, max_lives)
	_objective()
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
	anim_t += delta * 8.0
	var frames := sprite.hframes * sprite.vframes
	if frames > 1:
		sprite.frame = int(anim_t) % frames
	else:
		# tek kare: hayalet gibi suzul ve dalgalan
		sprite.position.y = sin(t * 2.2) * 6.0
		sprite.skew = sin(t * 1.6) * 0.06

	match state:
		State.DEFINED, State.LOGGED:
			_move_on_sine()
			_attack_fan(delta)
			_summon(delta)
			phase_timer -= delta
			if phase_timer <= 0.0:
				_go_undefined()
		State.UNDEFINED:
			_move_on_sine()
			_attack_spiral(delta)
			sprite.modulate.a = 0.2 + 0.35 * absf(sin(t * 25.0))   # titreyen hayalet
			sprite.offset.x = randf_range(-4.0, 4.0)
			phase_timer -= delta
			if phase_timer <= 0.0:
				_go_defined()
		State.OPEN:
			sprite.rotation = sin(t * 22.0) * 0.04
			open_left -= delta
			timer_label.text = "%d vuruş · %d sn" % [hits_left, ceili(open_left)]
			if open_left <= 0.0:
				_reset_to_defined("Kaçırdın! Baştan.")

	if state != State.UNDEFINED:
		_contact_damage()


## Sinus yolunda gezinir (tabii ki).
func _move_on_sine() -> void:
	global_position = home + Vector2(sin(t * 0.6) * sway, sin(t * 1.2) * 25.0)


# ---------------------------------------------------------------- tanim kumesi
func _go_undefined() -> void:
	var was_logged := state == State.LOGGED
	state = State.UNDEFINED
	phase_timer = undefined_time
	shape.set_deferred("disabled", true)       # mermiler icinden gecer
	_set_formula("tanımsız!", C_UNDEF, 40)
	_float_text("sin x ≤ 0", C_UNDEF)
	set_meta("was_logged", was_logged)
	_objective()


func _go_defined() -> void:
	sprite.modulate.a = 1.0
	sprite.offset.x = 0.0
	shape.set_deferred("disabled", false)
	phase_timer = defined_time
	if get_meta("was_logged", false):
		state = State.LOGGED
		_set_formula("x · ln(sin x)", C_LOGGED, 40)
	else:
		state = State.DEFINED
		_set_formula("(sin x)ˣ", C_IMMUNE, 54)
	_objective()


## Ekranin ustunde surekli duran "simdi ne yapmali" satiri.
func _objective() -> void:
	match state:
		State.DEFINED:
			objective.emit("1/3   Düz türev işlemez  →  ulti dolunca [E] Logaritma")
		State.LOGGED:
			objective.emit("2/3   Çarpım kuralı: barı doldur, bossa yaklaş, [Q] Ağır Atlama")
		State.UNDEFINED:
			objective.emit("Tanımsız! (sin x ≤ 0)  Mermiler geçer, bekle...")
		State.OPEN:
			objective.emit("3/3   Açıldı! Türevle bitir!")
		_:
			objective.emit("")


## Agir Atlama'yi bekliyor mu? (player.gd iskalama uyarisi icin)
func wants_slam() -> bool:
	return state == State.LOGGED


# ---------------------------------------------------------------- saldirilar
func _attack_fan(delta: float) -> void:
	fan_timer -= delta
	if fan_timer > 0.0 or player == null or not is_instance_valid(player):
		return
	fan_timer = fan_interval * (0.65 + 0.35 * float(lives) / max_lives)
	var base: Vector2 = global_position.direction_to(player.global_position)
	for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		_shoot(base.rotated(a), 200.0, 30.0)


func _attack_spiral(delta: float) -> void:
	spiral_timer -= delta
	if spiral_timer > 0.0:
		return
	spiral_timer = 0.13
	spiral_angle += 0.4
	for k in 2:
		var a := spiral_angle + PI * k
		_shoot(Vector2(cos(a), sin(a)), 180.0, 0.0)


func _shoot(dir: Vector2, spd: float, wave: float) -> void:
	var b = BULLET.instantiate()
	b.direction = dir
	b.speed = spd
	b.wave_amp = wave
	get_parent().add_child(b)
	b.global_position = global_position


func _summon(delta: float) -> void:
	summon_timer -= delta
	if summon_timer > 0.0:
		return
	summon_timer = summon_interval
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self:
			count += 1
	var polys := [[0, 0, 1], [0, 3]]   # x² ve 3x
	var n := mini(polys.size(), max_minions - count)
	if n > 0:
		summon_requested.emit(polys.slice(0, n))


func _contact_damage() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) < contact_radius:
		player.take_damage(1)


# ---------------------------------------------------------------- matematik
## Turev mermisi bunu cagirir.
func take_derivative() -> void:
	match state:
		State.DEFINED:
			_flash(Color(0.6, 0.8, 1.0))
			_taunt("Çok karmaşık! Önce ln al.")
			if not hinted_log:
				hinted_log = true
				hint.emit("Düz türev işlemez. Ulti dolunca [E] Logaritma!", 3.0)
		State.LOGGED:
			_flash(Color(1, 0.9, 0.5))
			_taunt("Çarpım kuralı = [Q] Ağır Atlama!")
			if not hinted_slam:
				hinted_slam = true
				hint.emit("x · ln(sin x) bir çarpım: yaklaş ve [Q] Ağır Atlama!", 3.0)
		State.OPEN:
			hits_left -= 1
			_flash(Color.WHITE)
			_float_text("-1 terim", C_OPEN)
			if hits_left <= 0:
				_lose_life()


## Agir Atlama bunu cagirir (player.gd).
func take_slam() -> void:
	match state:
		State.LOGGED:
			state = State.OPEN
			open_left = open_time
			hits_left = open_hits
			_set_formula("ln(sin x) + x · cot x", C_OPEN, 30)
			_float_text("Çarpım kuralı!", C_OPEN)
			timer_label.show()
			sprite.modulate = Color(0.7, 1.0, 0.8)
			hint.emit("Açıldı! Türevle bitir!", 1.8)
			_objective()
		State.UNDEFINED:
			_float_text("tanımsız noktada türev yok!", C_UNDEF)
		_:
			take_derivative()


func can_take_log() -> bool:
	return state == State.DEFINED


## Logaritma ultisi bunu cagirir.
func take_log() -> void:
	if state != State.DEFINED:
		return
	state = State.LOGGED
	_set_formula("x · ln(sin x)", C_LOGGED, 40)
	_float_text("ln y = x · ln(sin x)", C_LOGGED)
	summon_timer = 0.2   # hemen kagit: atlama icin bar dolsun
	hint.emit("Kâğıtlarla barı doldur, sonra yaklaş ve [Q] Ağır Atlama!", 3.0)
	_objective()


func _lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives, max_lives)
	timer_label.hide()
	if lives <= 0:
		_die()
		return
	state = State.HURT
	_set_formula("Q.E.D.", Color.WHITE, 44)
	_flash(Color(1, 0.3, 0.3))
	_objective()
	await get_tree().create_timer(1.3).timeout
	if state == State.HURT:
		_reset_to_defined("Daha bitmedi!")


func _reset_to_defined(msg: String) -> void:
	state = State.DEFINED
	set_meta("was_logged", false)
	phase_timer = defined_time
	timer_label.hide()
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	_set_formula("(sin x)ˣ", C_IMMUNE, 54)
	_float_text(msg, C_IMMUNE)
	_objective()
	fan_timer = 1.0
	summon_timer = 0.3


func _die() -> void:
	state = State.DEAD
	objective.emit("")
	remove_from_group("enemies")
	remove_from_group("log_targets")
	shape.set_deferred("disabled", true)
	_set_formula("Q.E.D.", Color.WHITE, 54)
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "rotation", -1.6, 1.2)
	tw.tween_property(sprite, "scale", base_scale * 0.1, 1.2)
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	await tw.finished
	defeated.emit()
	queue_free()


# ---------------------------------------------------------------- gorsel
func _set_formula(text: String, color: Color, font_size: int) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.25)


func _taunt(text: String) -> void:
	if taunt_cd <= 0.0:
		taunt_cd = 1.0
		_float_text(text, Color.WHITE)


func _flash(color: Color) -> void:
	var back := Color(0.7, 1.0, 0.8) if state == State.OPEN else Color.WHITE
	sprite.modulate = color
	create_tween().tween_property(sprite, "modulate", back, 0.2)


func _float_text(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", MATH_FONT)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(440, 50)
	get_parent().add_child(l)
	l.global_position = global_position + Vector2(-220, -230 + randf_range(-15, 15))
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
