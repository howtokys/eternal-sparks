extends StaticBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	unlock()

func lock() -> void:
	collision.set_deferred("disabled", false)
	anim.play("close")

func unlock() -> void:
	collision.set_deferred("disabled", true)
	anim.play("open")
