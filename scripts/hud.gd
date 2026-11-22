extends CanvasLayer

const MATH_FONT := preload("res://assets/fonts/math_font.ttf")
## Ekrandaki bilgiler: can, ulti bari, ortadaki mesajlar.

@onready var hp_label: Label = $HPLabel
@onready var ulti_bar: ProgressBar = $UltiBar
@onready var ulti_label: Label = $UltiLabel
@onready var center_label: Label = $CenterLabel
@onready var hint_label: Label = $HintLabel
@onready var boss_panel: Control = $BossPanel
@onready var boss_name: Label = $BossPanel/BossName
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var objective_label: Label = $ObjectiveLabel
@onready var boss_formula: Control = $BossFormula

var _msg_id := 0
var _hint_id := 0
var boss_mode := false
var _ulti_v := 0
var _ulti_m := 1


func _ready() -> void:
	center_label.hide()
	hint_label.hide()
	boss_panel.hide()
	objective_label.hide()


func set_hp(hp: int, max_hp: int) -> void:
	hp_label.text = "Can: %d / %d" % [hp, max_hp]


func set_ulti(value: int, max_value: int) -> void:
	_ulti_v = value
	_ulti_m = max_value
	ulti_bar.max_value = max_value
	ulti_bar.value = value
	if value >= max_value:
		ulti_label.text = "ULTİ HAZIR!  [Q] Atlama   [E] Logaritma" if boss_mode else "ULTİ HAZIR! [Q]"
		ulti_label.modulate = Color(1, 0.85, 0.2)
	else:
		ulti_label.text = "Ulti"
		ulti_label.modulate = Color.WHITE


## duration 0 ise mesaj ekranda kalir.
func show_message(text: String, duration := 2.0) -> void:
	_msg_id += 1
	var my_id := _msg_id
	center_label.text = text
	center_label.show()
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		if my_id == _msg_id:
			center_label.hide()


## Ekranin altinda kucuk ipucu satiri.
func show_hint(text: String, duration := 2.0) -> void:
	_hint_id += 1
	var my_id := _hint_id
	hint_label.text = text
	hint_label.show()
	await get_tree().create_timer(duration).timeout
	if my_id == _hint_id:
		hint_label.hide()


func show_boss(title: String, max_lives: int) -> void:
	boss_name.text = "BOSS:  " + title
	boss_bar.max_value = max_lives
	boss_bar.value = max_lives
	boss_panel.show()


func set_boss_hp(lives: int, max_lives: int) -> void:
	boss_bar.max_value = max_lives
	boss_bar.value = lives


func hide_boss() -> void:
	boss_panel.hide()


func set_boss_mode(on: bool) -> void:
	boss_mode = on
	set_ulti(_ulti_v, _ulti_m)


## Boss dovusunde ekranin ustunde surekli duran "simdi ne yapmali" satiri. Bos metin = gizle.
func set_objective(text: String) -> void:
	objective_label.text = text
	objective_label.visible = text != ""


## Ust uste usler: ["f(x) = e", "e", "P"] -> f(x) = e^(e^(P)) gibi, her kat daha kucuk ve daha yukarida.
## Bos liste = formulu gizle (boss adi geri gelir).
func set_boss_formula(levels: Array) -> void:
	for c in boss_formula.get_children():
		c.queue_free()
	if levels.is_empty():
		boss_name.show()
		return
	boss_name.hide()
	var x := 0.0
	var y := 30.0 if levels.size() > 1 else 22.0
	var size := 28.0 if levels.size() > 1 else 22.0
	var made: Array[Label] = []
	for i in levels.size():
		var l := Label.new()
		l.text = levels[i]
		l.add_theme_font_override("font", MATH_FONT)
		l.add_theme_font_size_override("font_size", int(size))
		var last := i == levels.size() - 1
		l.add_theme_color_override("font_color", Color(1, 0.95, 0.7) if last else Color(1, 0.5, 0.45))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		boss_formula.add_child(l)
		l.position = Vector2(x, y)
		made.append(l)
		x += l.get_minimum_size().x - 3.0
		y -= size * 0.45            # bir sonraki kat yukari
		size = maxf(size * 0.68, 17.0)  # ve kuculur
	var off := (boss_formula.size.x - x) / 2.0
	for l in made:
		l.position.x += off
