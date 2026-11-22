extends Control
## Ana menu (ui/main_menu.tscn). BASLA -> Level 1, CIKIS -> oyundan cik.

const GameState := preload("res://scripts/game_state.gd")


func _ready() -> void:
	var start := find_child("StartButton", true, false) as Button
	var quit := find_child("QuitButton", true, false) as Button
	if start:
		start.pressed.connect(_on_start)
		start.grab_focus()   # Enter / bosluk ile de baslasin
	if quit:
		if OS.has_feature("web"):
			quit.hide()      # tarayicida "cikis" anlamsiz
		else:
			quit.pressed.connect(func(): get_tree().quit())
	GameState.play_music(self, GameState.MUSIC_MENU)


func _on_start() -> void:
	get_tree().change_scene_to_file(GameState.FIRST_LEVEL)
