extends Area2D
## Logaritma ultisi: bossa kilitlenen "ln" mermisi. Iskalamaz.

@export var speed := 650.0
@export var turn_rate := 8.0

var target = null
var velocity := Vector2.ZERO
var done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(5.0).timeout.connect(queue_free)
	var tw := create_tween().set_loops()
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	var desired: Vector2 = global_position.direction_to(target.global_position) * speed
	if velocity == Vector2.ZERO:
		velocity = desired
	velocity = velocity.lerp(desired, clampf(turn_rate * delta, 0.0, 1.0))
	position += velocity * delta


func _on_body_entered(body: Node) -> void:
	if done or body != target:
		return   # yoldaki kagitlarin icinden gecer
	done = true
	if body.has_method("take_log"):
		body.take_log()
	queue_free()
