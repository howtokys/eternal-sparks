extends Area2D
class_name Bullet

@export var speed : int = 400
var target_position: Vector2
var despawn_time = 2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	despawn()

func _physics_process(delta: float) -> void:
	position += target_position * speed * delta

func _on_body_entered(body: Node2D) -> void:
	queue_free()

func _on_area_entered(_area: Area2D) -> void:
	queue_free()

func despawn() -> void:
	await get_tree().create_timer(despawn_time).timeout
	queue_free()
