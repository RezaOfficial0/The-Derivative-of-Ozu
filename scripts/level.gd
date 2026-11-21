extends Node2D
## Bolum akisi. Bu script'i her level sahnesinin kok node'una (Level1, Level2...) takmak yeterli.
## Sahnede su node'lar olmali: Background (Sprite2D), PlayerStart (Marker2D),
## SpawnPoints (altinda Spawn1, Spawn2... Marker2D'ler).

const Controls := preload("res://scripts/controls.gd")
const PLAYER := preload("res://scenes/player.tscn")
const PAPER := preload("res://scenes/paper_enemy.tscn")
const HUD := preload("res://scenes/hud.tscn")

## Her dalga = o dalgada dogacak kagitlarin polinomlari.
## [0, 0, 1] = x²   [0, 3] = 3x   [0, 1, 0, 1] = x³ + x
var waves: Array = [
	[[0, 0, 1], [0, 0, 1], [0, 3]],
	[[0, 0, 0, 1], [0, 0, 1], [0, 2], [0, 0, 1]],
	[[0, 1, 0, 1], [0, 0, 0, 0, 1], [0, 0, 0, 1], [0, 0, 1], [0, 0, 1]],
]

@export var level_name := "Öğrenci Merkezi"
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


func _ready() -> void:
	Controls.setup()
	for m in $SpawnPoints.get_children():
		if m is Marker2D and String(m.name).begins_with("Spawn"):
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
	player.global_position = $PlayerStart.global_position

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


## Haritanin tamami ekrana sigsin.
func _fit_camera() -> void:
	var bg: Sprite2D = $Background
	var map_size: Vector2 = bg.texture.get_size()
	camera.global_position = bg.global_position + map_size / 2.0
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
	var pos: Vector2 = $PlayerStart.global_position + Vector2(500, 0)
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
	_shake(22.0)
	await get_tree().create_timer(2.0).timeout
	if level_over:
		return
	boss = boss_scene.instantiate()
	boss.position = _boss_position()   # _ready'den once konum ver
	boss.lives_changed.connect(hud.set_boss_hp)
	boss.summon_requested.connect(_on_boss_summon)
	boss.hint.connect(hud.show_hint)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)
	hud.show_boss(boss.boss_title, boss.max_lives)
	hud.set_boss_mode(true)


func _boss_position() -> Vector2:
	var m := find_child("BossStart", true, false) as Node2D
	if m:
		return m.global_position
	var bg: Sprite2D = $Background
	return bg.global_position + bg.texture.get_size() / 2.0


## Boss kagit cagirir: bunlar 2 kat ulti doldurur.
func _on_boss_summon(polys: Array) -> void:
	if level_over:
		return
	for p in polys:
		_spawn_paper(p, 2)


func _on_boss_defeated() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("kill"):
			e.kill()
	hud.hide_boss()
	hud.set_boss_mode(false)
	_shake(18.0)
	_level_clear()


# ---------------------------------------------------------------- bitis
func _level_clear() -> void:
	level_over = true
	hud.show_message("BÖLÜM TAMAM!\n%s kurtarıldı." % level_name, 0)
	if next_level != "":
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file(next_level)


func _on_player_died() -> void:
	if level_over:
		return
	level_over = true
	hud.show_message("GAME OVER\nBütünleme haftası seni bekliyor.", 0)
	await get_tree().create_timer(2.5).timeout
	get_tree().reload_current_scene()
