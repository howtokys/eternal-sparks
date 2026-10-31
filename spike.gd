extends Area2D
@export var damage_amount: int = 1
@export var retracted_duration: float = 3.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var player_in_range: Node2D = null
var is_retracted: bool = false

func _ready() -> void:
	animated_sprite_2d.frame = 0
	animated_sprite_2d.stop()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exit)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		
		if not is_retracted:
			damage_player()
			retract_trap()
func _on_body_exit(body: Node2D) -> void:
	
func damage_player() -> void:

func retract_trap() -> void:
	
