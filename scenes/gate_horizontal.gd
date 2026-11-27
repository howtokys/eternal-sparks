extends StaticBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_closed := false

func _ready() -> void:
	anim.play("open")
	collision.disabled = true

func set_closed(closed: bool) -> void:
	if is_closed == closed:
		return
	is_closed = closed
	
	if closed:
		anim.play("close")
		if collision:
			collision.set_deferred("disabled", false)
	else:
		anim.play("open")
		if collision:
			collision.set_deferred("disabled", true)
