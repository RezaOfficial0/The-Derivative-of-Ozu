extends CanvasLayer
## Ekrandaki bilgiler: can, ulti bari, ortadaki mesajlar.

@onready var hp_label: Label = $HPLabel
@onready var ulti_bar: ProgressBar = $UltiBar
@onready var ulti_label: Label = $UltiLabel
@onready var center_label: Label = $CenterLabel
@onready var hint_label: Label = $HintLabel
@onready var boss_panel: Control = $BossPanel
@onready var boss_name: Label = $BossPanel/BossName
@onready var boss_bar: ProgressBar = $BossPanel/BossBar

var _msg_id := 0
var _hint_id := 0
var boss_mode := false
var _ulti_v := 0
var _ulti_m := 1


func _ready() -> void:
	center_label.hide()
	hint_label.hide()
	boss_panel.hide()


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
