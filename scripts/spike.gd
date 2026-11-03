extends Area2D
@export var damage_amount: int = 1
@export var retracted_duration: float = 3.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var current_target: Node2D = null
var is_retracted: bool = false
var is_cycling: bool = false

func _ready() -> void:
	animated_sprite_2d.frame = 0
	animated_sprite_2d.stop()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy"):
		current_target = body
		
		if not is_retracted and not is_cycling:
			start_cycle()
			
func _on_body_exited(body: Node2D) -> void:
	if body == current_target:
		current_target = null
		
func apply_damage() -> void:
	current_target.take_damage(damage_amount)

func start_cycle() -> void:
	if is_cycling:
		return
	is_cycling = true
	_cycle()

func _cycle() -> void:
	if current_target and not is_retracted:
		apply_damage()
	
	is_retracted = true
	animated_sprite_2d.play("retract")
	await animated_sprite_2d.animation_finished
	
	await get_tree().create_timer(retracted_duration).timeout
	
	animated_sprite_2d.play("erect")
	await animated_sprite_2d.animation_finished
	is_retracted = false
	
	is_cycling = false
	if current_target and overlaps_body(current_target):
		start_cycle()
