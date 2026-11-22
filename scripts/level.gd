extends Node2D
## Bolum akisi. Bu script'i her level sahnesinin kok node'una (Level1, Level2...) takmak yeterli.
## Sahnede olmasi gerekenler: arka plan Sprite2D'si, PlayerStart (Marker2D),
## adi "Spawn" ile baslayan Marker2D'ler (Spawn1, Spawn2...) ve istege bagli BossStart.

const Controls := preload("res://scripts/controls.gd")
const PLAYER := preload("res://scenes/player.tscn")
const PAPER := preload("res://scenes/paper_enemy.tscn")
const HUD := preload("res://scenes/hud.tscn")
const GameState := preload("res://scripts/game_state.gd")

## Dalga setleri. Her dalga = o dalgada dogacak kagitlarin polinomlari.
## [0, 0, 1] = x²   [0, 3] = 3x   [0, 1, 0, 1] = x³ + x   [0, 0, 0, 0, 1] = x⁴
const WAVE_SETS := {
	1: [
		[[0, 0, 1], [0, 0, 1], [0, 3]],
		[[0, 0, 0, 1], [0, 0, 1], [0, 2], [0, 0, 1]],
		[[0, 1, 0, 1], [0, 0, 0, 0, 1], [0, 0, 0, 1], [0, 0, 1], [0, 0, 1]],
	],
	2: [
		[[0, 0, 1], [0, 0, 0, 1], [0, 3], [0, 0, 1]],
		[[0, 1, 0, 1], [0, 0, 0, 1], [0, 0, 2], [0, 0, 0, 0, 1]],
		[[0, 0, 0, 0, 1], [0, 1, 0, 1], [0, 0, 0, 1], [0, 0, 0, 1], [0, 0, 1], [0, 2]],
	],
	3: [
		[[0, 0, 0, 1], [0, 0, 0, 1], [0, 1, 0, 1], [0, 0, 1]],
		[[0, 0, 0, 0, 1], [0, 0, 0, 0, 1], [0, 1, 0, 1], [0, 0, 0, 1], [0, 0, 1]],
		[[0, 0, 0, 0, 0, 1], [0, 0, 0, 0, 1], [0, 1, 0, 1], [0, 1, 0, 1], [0, 0, 0, 1], [0, 0, 1]],
	],
}
var waves: Array = []

@export var level_name := "Öğrenci Merkezi"
@export_range(1, 3) var wave_set := 1       # 1 kolay, 2 orta, 3 zor
@export var spawn_interval := 0.7
@export_file("*.tscn") var next_level := ""   # sonraki bolum (bos ise burada biter)
## Dalgalardan sonra gelecek boss. Bos birakilirsa boss olmadan biter.
@export var boss_scene: PackedScene = preload("res://scenes/boss_exp.tscn")

var player = null
var hud = null
var camera: Camera2D
var spawn_points: Array[Marker2D] = []
var wave_index := -1
var alive := 0
var spawning := false
var waiting := false
var level_over := false
var boss_phase := false
var boss = null
var music: AudioStreamPlayer


func _ready() -> void:
	Controls.setup()
	GameState.set_last_level(scene_file_path)   # Game Over -> Tekrar Dene buraya doner
	music = GameState.play_music(self, GameState.MUSIC_LEVEL)
	waves = WAVE_SETS.get(wave_set, WAVE_SETS[1])
	for m in find_children("Spawn*", "Marker2D", true, false):
		spawn_points.append(m)
	_setup_camera()

	hud = HUD.instantiate()
	add_child(hud)

	player = PLAYER.instantiate()
	player.hp_changed.connect(hud.set_hp)
	player.ulti_changed.connect(hud.set_ulti)
	player.died.connect(_on_player_died)
	player.slammed.connect(_shake)
	player.hint.connect(hud.show_hint)
	add_child(player)
	player.global_position = _marker_pos("PlayerStart", _map_center())

	hud.show_message("Bugün Özyeğin'i kurtarmaya geldim!", 2.0)
	await get_tree().create_timer(2.2).timeout
	_next_wave()


# ---------------------------------------------------------------- kamera
func _setup_camera() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)


## Arka plan Sprite2D'sini bul (adi Background ya da background olabilir).
func _background() -> Sprite2D:
	for n in ["Background", "background"]:
		var s := get_node_or_null(n) as Sprite2D
		if s:
			return s
	for c in get_children():
		if c is Sprite2D and c.texture:
			return c
	return null


func _map_rect() -> Rect2:
	var bg := _background()
	if bg == null or bg.texture == null:
		return Rect2(Vector2.ZERO, get_viewport_rect().size)
	var size: Vector2 = bg.texture.get_size() * bg.scale
	var pos: Vector2 = bg.global_position - (size / 2.0 if bg.centered else Vector2.ZERO)
	return Rect2(pos, size)


func _map_center() -> Vector2:
	return _map_rect().get_center()


func _marker_pos(marker_name: String, fallback: Vector2) -> Vector2:
	var m := find_child(marker_name, true, false) as Node2D
	return m.global_position if m else fallback


## Haritanin tamami ekrana sigsin.
func _fit_camera() -> void:
	var r := _map_rect()
	var map_size: Vector2 = r.size
	camera.global_position = r.get_center()
	var vp: Vector2 = get_viewport_rect().size
	var z: float = minf(vp.x / map_size.x, vp.y / map_size.y)
	camera.zoom = Vector2(z, z)


func _shake(strength := 14.0) -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.03)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.03)


# ---------------------------------------------------------------- dalgalar
func _next_wave() -> void:
	if level_over:
		return
	wave_index += 1
	if wave_index >= waves.size():
		if boss_scene:
			_start_boss()
		else:
			_level_clear()
		return
	hud.show_message("Dalga %d / %d" % [wave_index + 1, waves.size()], 1.5)
	spawning = true
	for poly in waves[wave_index]:
		if level_over:
			return
		_spawn_paper(poly)
		await get_tree().create_timer(spawn_interval).timeout
	spawning = false
	_check_wave_done()


func _spawn_paper(poly: Array, reward := 1) -> void:
	var e = PAPER.instantiate()
	var c: Array[float] = []
	for v in poly:
		c.append(float(v))
	e.coeffs = c
	e.ulti_reward = reward
	e.died.connect(_on_enemy_died)
	add_child(e)
	var pos: Vector2 = _map_center()
	if spawn_points.size() > 0:
		var sp: Marker2D = spawn_points.pick_random()
		pos = sp.global_position
	e.global_position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	alive += 1


func _on_enemy_died() -> void:
	alive -= 1
	_check_wave_done()


func _check_wave_done() -> void:
	if boss_phase or alive > 0 or spawning or waiting or level_over:
		return
	waiting = true
	await get_tree().create_timer(1.2).timeout
	waiting = false
	_next_wave()


# ---------------------------------------------------------------- boss
func _start_boss() -> void:
	boss_phase = true
	hud.show_message("BOSS GELİYOR!", 2.0)
	GameState.switch_music(music, GameState.MUSIC_BOSS)
	_shake(22.0)
	await get_tree().create_timer(2.0).timeout
	if level_over:
		return
	boss = boss_scene.instantiate()
	boss.position = _boss_position()   # _ready'den once konum ver
	boss.lives_changed.connect(hud.set_boss_hp)
	boss.summon_requested.connect(_on_boss_summon)
	boss.hint.connect(hud.show_hint)
	if boss.has_signal("objective"):
		boss.objective.connect(hud.set_objective)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)
	hud.show_boss(boss.boss_title, boss.max_lives)
	hud.set_boss_mode(true)


func _boss_position() -> Vector2:
	return _marker_pos("BossStart", _map_center())


## Boss kagit cagirir: bunlar 2 kat ulti doldurur.
func _on_boss_summon(polys: Array) -> void:
	if level_over:
		return
	var reward = boss.get("minion_reward") if boss else null
	for p in polys:
		_spawn_paper(p, reward if reward != null else 2)


func _on_boss_defeated() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("kill"):
			e.kill()
	hud.hide_boss()
	hud.set_objective("")
	hud.set_boss_mode(false)
	_shake(18.0)
	_level_clear()


# ---------------------------------------------------------------- bitis
func _level_clear() -> void:
	level_over = true
	hud.show_message("BÖLÜM TAMAM!\n%s kurtarıldı." % level_name, 0)
	await get_tree().create_timer(3.5).timeout
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
	else:
		get_tree().change_scene_to_file(GameState.MAIN_MENU)   # son bolum: ana menuye don


func _on_player_died() -> void:
	if level_over:
		return
	level_over = true
	hud.show_message("GAME OVER\nBütünleme haftası seni bekliyor.", 0)
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file(GameState.GAME_OVER)
