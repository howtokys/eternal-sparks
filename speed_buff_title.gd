extends Area2D

@export var speed_multiplier: float = 1.5   
@export var duration: float = 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	if body.has_method("apply_speed_effect"):
		body.apply_speed_effect(speed_multiplier, duration)
