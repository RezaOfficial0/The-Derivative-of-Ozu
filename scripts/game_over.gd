extends Control
## Game Over ekrani (ui/game_over.tscn).
## TEKRAR DENE (StartButton) -> olunen bolum bastan, ANA MENU (QuitButton) -> ana menu.

const GameState := preload("res://scripts/game_state.gd")


func _ready() -> void:
	var retry := find_child("StartButton", true, false) as Button
	var menu := find_child("QuitButton", true, false) as Button
	if retry:
		retry.pressed.connect(func(): get_tree().change_scene_to_file(GameState.get_last_level()))
		retry.grab_focus()
	if menu:
		menu.pressed.connect(func(): get_tree().change_scene_to_file(GameState.MAIN_MENU))
	GameState.play_music(self, GameState.MUSIC_MENU, -16.0)
