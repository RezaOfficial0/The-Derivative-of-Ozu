extends Area2D
## Kagitlarin firlattigi beyaz / kirmizi cizgi. Can Deha'ya carparsa can goturur.

@export var speed := 230.0
@export var damage := 1
@export var lifetime := 4.0
@export var wave_amp := 0.0     # 0 = duz gider, >0 = sinus dalgasi cizerek gider
@export var wave_freq := 6.0

var direction := Vector2.RIGHT
var _t := 0.0


func _ready() -> void:
	rotation = direction.angle()
	$Polygon2D.color = [Color.WHITE, Color(1, 0.2, 0.2)].pick_random()
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	var side := direction.orthogonal() * cos(_t * wave_freq) * wave_amp * wave_freq
	position += (direction * speed + side) * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()  # oyuncuya ya da duvara carpinca kaybolur
