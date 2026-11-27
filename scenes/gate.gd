extends Node2D

var is_closed := false
var sprites: Array[AnimatedSprite2D] = []
var collisions: Array[CollisionShape2D] = []

func _ready() -> void:
	for child in get_children():
		_collect(child)
	# start open
	for sprite in sprites:
		sprite.play("open")
	for col in collisions:
		col.disabled = true

func _collect(node: Node) -> void:
	if node is AnimatedSprite2D:
		sprites.append(node)
	elif node is CollisionShape2D:
		collisions.append(node)
	for child in node.get_children():
		_collect(child)

func set_closed(closed: bool) -> void:
	if is_closed == closed:
		return
	is_closed = closed
	
	for sprite in sprites:
		if closed:
			sprite.play("close")
		else:
			sprite.play("open")
	
	for col in collisions:
		col.set_deferred("disabled", not closed)
