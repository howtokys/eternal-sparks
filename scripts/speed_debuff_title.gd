extends Area2D

@export var speed_multiplier: float = 0.5   
@export var duration: float = 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("apply_temporary_speed"):
		body.apply_temporary_speed(speed_multiplier, duration)
