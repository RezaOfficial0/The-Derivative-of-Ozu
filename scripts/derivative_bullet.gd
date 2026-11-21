extends Area2D
## Can Deha'nin d/dx mermisi. Kagida carparsa turevini alir, duvara carparsa kaybolur.

@export var speed := 620.0
@export var lifetime := 1.2

var direction := Vector2.RIGHT
var hit := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if hit:
		return
	hit = true
	if body.has_method("take_derivative"):
		body.take_derivative()
	queue_free()
