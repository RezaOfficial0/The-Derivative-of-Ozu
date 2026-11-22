extends CharacterBody2D
## BOSS 3 (FINAL):  f(x) = e^(e^(0.01x¹² − 0.55x¹⁰ + 10.23x⁸ − 76.45x⁶ + 210.76x⁴ − 140))
## 1) Cift e kalkani: turev islemez. [E] Logaritma iki kez:  e^(e^P) -> e^P -> P
## 2) Polinom: her turev dereceyi 1 dusurur.  4 turev mermisi = 1 turev,  [Q] = aninda 1 turev.
## 3) Belli araliklarla KENDINI INTEGRALLER (∫ P dx): derece geri artar (baslangic derecesini gecemez).
## 4) Sabite inince son turev: 0  ->  Q.E.D.
## Derece ne kadar yuksekse saldirilari o kadar guclu.

signal lives_changed(lives: int, max_lives: int)
signal summon_requested(polys: Array)
signal hint(text: String, duration: float)
signal objective(text: String)
signal formula_changed(levels: Array)   # HUD'daki ust uste usler: ["f(x) = e", "e", "P"]
signal defeated

enum State { EXP, POLY, DEAD }

const BULLET := preload("res://scenes/enemy_bullet.tscn")
const MATH_FONT := preload("res://assets/fonts/math_font.ttf")
const SUP := {"0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
		"5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"}
const INK := Color(0.12, 0.15, 0.45)
const INK_EXP := Color(0.6, 0.1, 0.1)
const MINUS := "−"

@export var boss_title := "f(x)"
## Katsayilar sabit terimden baslar: [x⁰, x¹, x², ...]
## Orijinal (x¹⁰'lu) hali: [-140, 0, 210.76, 0, -76.45, 0, 10.23, 0, -0.55, 0, 0.01]
@export var start_poly: Array = [-140, 0, 0, 0, 210.76, 0, -76.45, 0, 10.23, 0, -0.55, 0, 0.01]
@export var exp_layers := 2                       # kac kat e^( ) kalkani
@export var hits_per_derivative := 4              # kac turev mermisi = 1 turev
@export var integral_interval := 16.0             # kac saniyede bir kendini integraller
@export var minion_reward := 2
@export var summon_interval := 7.0
@export var max_minions := 3
@export var contact_radius := 140.0
@export var hit_radius := 150.0                   # Agir Atlama menziline eklenir
@export var sway := 140.0
@export var fan_interval := 2.4                  # nisanli yelpaze araligi
@export var fan_max := 5                         # yelpazede en fazla kac mermi
@export var ring_interval := 4.5                 # halka saldirisi araligi
@export var ring_max := 12                       # halkada en fazla kac mermi

@onready var sprite: Sprite2D = $Sprite2D
@onready var panel: Label = $Sprite2D/Panel
@onready var bar_label: Label = $TimerLabel
@onready var shape: CollisionShape2D = $CollisionShape2D

var coeffs: Array = []        # her eleman [pay, payda] (kesin hesap, yuvarlama hatasi yok)
var layers := 0               # kalan e kalkani
var state := State.EXP
var hits := 0
var max_degree := 0
var integral_timer := 0.0
var fan_timer := 1.5
var ring_timer := 3.0
var summon_timer := 0.5
var t := 0.0
var home := Vector2.ZERO
var base_scale := Vector2.ONE
var taunt_cd := 0.0
var max_lives := 1
var player = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("log_targets")
	home = global_position
	base_scale = sprite.scale
	player = get_tree().get_first_node_in_group("player")
	for c in start_poly:
		coeffs.append(_from_number(c))
	max_degree = _degree()
	layers = exp_layers
	state = State.EXP if layers > 0 else State.POLY
	integral_timer = integral_interval
	max_lives = _steps_left()
	_refresh()
	sprite.scale = base_scale * 0.2
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "scale", base_scale, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.5)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	t += delta
	taunt_cd -= delta
	global_position = home + Vector2(sin(t * 0.5) * sway, sin(t * 1.0) * 30.0)
	sprite.scale = base_scale * (1.0 + sin(t * 2.5) * 0.025)

	match state:
		State.POLY:
			integral_timer -= delta
			bar_label.text = "türev  %d / %d      ∫ %d sn" % [hits, hits_per_derivative, ceili(integral_timer)]
			if integral_timer <= 0.0:
				_cast_integral()
		State.EXP:
			bar_label.text = "kalkan: %d kat e^( )   →   [E]" % layers
	_attacks(delta)
	_summon(delta)
	_contact_damage()


# ---------------------------------------------------------------- polinom matematigi
func _degree() -> int:
	for i in range(coeffs.size() - 1, -1, -1):
		if coeffs[i][0] != 0:
			return i
	return -1


func _steps_left() -> int:
	return maxi(_degree() + 1, 0) + layers


func _derive() -> void:
	var out: Array = []
	for i in range(1, coeffs.size()):
		out.append(_frac(coeffs[i][0] * i, coeffs[i][1]))
	coeffs = out if out.size() > 0 else [[0, 1]]


func _integrate() -> void:
	var out: Array = [[0, 1]]          # + C (sayisal olarak 0)
	for i in coeffs.size():
		out.append(_frac(coeffs[i][0], coeffs[i][1] * (i + 1)))
	coeffs = out


## 210.76 -> [5269, 25]  (ondalikli sayilari kesre cevirir)
func _from_number(v) -> Array:
	if typeof(v) == TYPE_INT:
		return [v, 1]
	return _frac(int(roundf(float(v) * 100.0)), 100)


@warning_ignore("integer_division")
func _frac(n: int, d: int) -> Array:
	var a := absi(n)
	var b := absi(d)
	while b != 0:
		var r := a % b
		a = b
		b = r
	if a == 0:
		return [0, 1]
	if d < 0:
		n = -n
		d = -d
	return [n / a, d / a]


func _num_text(n: int, d: int) -> String:
	if d == 1:
		return str(absi(n))
	var s := "%.2f" % (absf(float(n)) / d)
	s = s.rstrip("0").rstrip(".")
	return s


func _poly_text() -> String:
	var out := ""
	var first := true
	for i in range(coeffs.size() - 1, -1, -1):
		var n: int = coeffs[i][0]
		var d: int = coeffs[i][1]
		if n == 0:
			continue
		var xs := "" if i == 0 else ("x" if i == 1 else "x" + _sup(i))
		var mag := _num_text(n, d)
		if i > 0 and mag == "1":
			mag = ""
		var term := mag + xs
		if first:
			out = (MINUS if n < 0 else "") + term
			first = false
		else:
			out += (" " + MINUS + " " if n < 0 else " + ") + term
	return out if out != "" else "0"


func _sup(n: int) -> String:
	var s := ""
	for ch in str(n):
		s += SUP[ch]
	return s


# ---------------------------------------------------------------- oyuncunun araclari
## Turev mermisi: 4 vurusta bir turev.
func take_derivative() -> void:
	match state:
		State.POLY:
			hits += 1
			_flash(Color(1.4, 1.4, 1.4))
			if hits >= hits_per_derivative:
				hits = 0
				_apply_derivative("d/dx")
		State.EXP:
			_flash(Color(1, 0.6, 0.6))
			_taunt("(e^u)′ = u′·e^u  →  daha da büyüdü!")


## Agir Atlama: aninda bir turev.
func take_slam() -> void:
	match state:
		State.POLY:
			hits = 0
			_apply_derivative("Ağır Atlama: d/dx!")
		State.EXP:
			_taunt("Kalkan! Önce [E] Logaritma.")


func wants_slam() -> bool:
	return state == State.POLY


func can_take_log() -> bool:
	return state == State.EXP


func take_log() -> void:
	if state != State.EXP:
		return
	layers -= 1
	_float_text("ln(e^u) = u", Color(1, 0.85, 0.2))
	if layers <= 0:
		state = State.POLY
		hint.emit("Kalkanlar kırıldı! Şimdi türev!", 2.0)
	else:
		hint.emit("Bir kat kaldı! Barı doldur, bir [E] daha.", 2.5)
		summon_timer = 0.2
	_refresh()


func _apply_derivative(msg: String) -> void:
	if _degree() <= 0:           # sabit -> son turev
		coeffs = [[0, 1]]
		_refresh()
		_die()
		return
	_derive()
	_float_text(msg, Color(0.4, 1, 0.5))
	_refresh()


func _cast_integral() -> void:
	integral_timer = integral_interval
	if _degree() >= max_degree:
		return
	_integrate()
	_float_text("∫ P dx  (+C)", Color(1, 0.4, 0.35))
	hint.emit("Boss kendini integralledi! Derecesi arttı, hızlı ol!", 2.5)
	_refresh()


# ---------------------------------------------------------------- saldirilar
func _attacks(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var deg := maxi(_degree(), 0)
	fan_timer -= delta
	if fan_timer <= 0.0:
		fan_timer = fan_interval
		var terms := 0
		for c in coeffs:
			if c[0] != 0:
				terms += 1
		var n := mini(terms + 1, fan_max)
		var base: Vector2 = global_position.direction_to(player.global_position)
		for i in n:
			var a := lerpf(-0.6, 0.6, float(i) / maxf(n - 1, 1))
			_shoot(base.rotated(a), 220.0, 0.0)
	ring_timer -= delta
	if ring_timer <= 0.0:
		ring_timer = ring_interval
		var count := clampi(deg + 4, 6, ring_max)   # derece buyudukce halka yogunlasir
		var off := randf() * TAU
		for i in count:
			var a := off + TAU * i / count
			_shoot(Vector2(cos(a), sin(a)), 170.0, 18.0)


func _shoot(dir: Vector2, spd: float, wave: float) -> void:
	var b = BULLET.instantiate()
	b.direction = dir
	b.speed = spd
	b.wave_amp = wave
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(0, 20)


func _summon(delta: float) -> void:
	summon_timer -= delta
	if summon_timer > 0.0:
		return
	summon_timer = summon_interval
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self:
			count += 1
	var polys := [[0, 0, 1], [0, 3], [0, 0, 0, 1]]
	var n := mini(2, max_minions - count)
	if n > 0:
		var st := randi() % 2
		summon_requested.emit(polys.slice(st, st + n))


func _contact_damage() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) < contact_radius:
		player.take_damage(1)


func _die() -> void:
	state = State.DEAD
	objective.emit("")
	formula_changed.emit(["f′ = 0     Q.E.D."])
	remove_from_group("enemies")
	remove_from_group("log_targets")
	shape.set_deferred("disabled", true)
	bar_label.text = "Q.E.D."
	_float_text("(sabit)′ = 0     Q.E.D.", Color.WHITE)
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "rotation", 0.5, 1.6)
	tw.tween_property(sprite, "scale", base_scale * 0.1, 1.6)
	tw.tween_property(self, "modulate:a", 0.0, 1.6)
	await tw.finished
	defeated.emit()
	queue_free()


# ---------------------------------------------------------------- gorsel
## Pano, HUD formulu, boss cubugu ve hedef satirini birlikte gunceller.
func _refresh() -> void:
	var p := _poly_text()
	# bossun gogsundeki pano (kucuk): kalkan varken sembolik yaz
	var txt := p
	if state == State.EXP:
		txt = "e^(e^(P(x)))" if layers >= 2 else "e^(P(x))"
	panel.text = txt
	panel.add_theme_color_override("font_color", INK_EXP if state == State.EXP else INK)
	var L := txt.length()
	var fs := 34 if L <= 6 else (26 if L <= 9 else (18 if L <= 14 else (16 if L <= 40 else 13)))
	panel.add_theme_font_size_override("font_size", fs)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25)

	# HUD: ust uste usler (f(x) = e^(e^(P)))
	var levels: Array = []
	if state == State.EXP:
		levels.append("f(x) = e")
		for k in layers - 1:
			levels.append("e")
		levels.append(p)
	else:
		levels.append("P(x) = " + p)
	formula_changed.emit(levels)

	max_lives = maxi(max_lives, _steps_left())
	lives_changed.emit(_steps_left(), max_lives)

	match state:
		State.EXP:
			if layers >= 2:
				objective.emit("e^(e^P): türev işlemez  →  iki kez [E] Logaritma (ulti dolunca)")
			else:
				objective.emit("Bir kat kaldı: e^P  →  bir [E] Logaritma daha")
		State.POLY:
			objective.emit("%d türev = 1 türev,  [Q] = anında türev.  Boss ∫ ile büyür, hızlı ol!" % hits_per_derivative)


func _taunt(text: String) -> void:
	if taunt_cd <= 0.0:
		taunt_cd = 1.0
		_float_text(text, Color.WHITE)


func _flash(color: Color) -> void:
	sprite.modulate = color
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _float_text(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", MATH_FONT)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(560, 50)
	get_parent().add_child(l)
	l.global_position = global_position + Vector2(-280, -215 + randf_range(-15, 15))
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
