extends RefCounted
## Oyun genelindeki sabitler ve sahneler arasi bilgi. Kullanim:
##   const GameState := preload("res://scripts/game_state.gd")

const MAIN_MENU := "res://ui/main_menu.tscn"
const GAME_OVER := "res://ui/game_over.tscn"
const FIRST_LEVEL := "res://levels/level_1.tscn"

## Eren'in ekledigi muzikler (assets/sounds)
const MUSIC_MENU := "res://assets/sounds/reganati-chillcalming-chiptune-loop-527182.mp3"
const MUSIC_LEVEL := "res://assets/sounds/ayitsmatt-overworld-melody-199744.mp3"
const MUSIC_BOSS := "res://assets/sounds/psychronic-fight-for-the-future-336841.mp3"


## Game Over'da "Tekrar Dene" hangi bolume donecek.
static func set_last_level(path: String) -> void:
	Engine.set_meta("last_level", path)


static func get_last_level() -> String:
	return Engine.get_meta("last_level", FIRST_LEVEL)


## Sahneye dongulu calan bir muzik ekler. Dosya yoksa sessizce gecer.
static func play_music(owner: Node, path: String, volume_db := -10.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = volume_db
	owner.add_child(p)
	switch_music(p, path)
	return p


static func switch_music(p: AudioStreamPlayer, path: String) -> void:
	if p == null or not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if "loop" in stream:
		stream.loop = true
	p.stream = stream
	p.play()
