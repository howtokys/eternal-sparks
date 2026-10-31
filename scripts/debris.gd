extends Node2D

@onready var color_rect: ColorRect = $ColorRect

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.35

func setup(direction: Vector2, base_color: Color, spawn_pos: Vector2) -> void:
	global_position = spawn_pos # Set position immediately so it never flashes at (0,0)
	
	color_rect.color = base_color.lightened(randf_range(-0.1, 0.1))
	var random_size = randf_range(8.0, 14.0)
	color_rect.size = Vector2(random_size, random_size)
	color_rect.position = -color_rect.size / 2 
	
	velocity = direction * randf_range(180.0, 280.0)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, lifetime).from_current()
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()
	
func _process(delta: float) -> void:
	position = position + velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
