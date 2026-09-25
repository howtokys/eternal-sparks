extends CharacterBody2D
class_name Bullet

@export var speed : int = 400
var target_position
var despawn_time = 2

func _ready() -> void:
	despawn()

func _physics_process(delta: float) -> void:
	velocity = target_position * speed
	move_and_slide()

func despawn() -> void:
	await get_tree().create_timer(despawn_time).timeout
	queue_free()
