extends Area2D

@export var status_effect: StatusEffect
@export var explosion_damage: int = 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	animated_sprite.play("kaboom")
	animated_sprite.animation_finished.connect(queue_free)
	
	
	await get_tree().physics_frame
	
	for body in get_overlapping_bodies():
		_hit_body(body)

func _hit_body(body: Node2D) -> void:
	print("[Explosion] Hit: ", body.name, " | Groups: ", body.get_groups())
	
	if body.has_method("take_damage"):
		body.take_damage(explosion_damage)
	
	if body.is_in_group("player") or body.is_in_group("enemy"):
		var component = body.get_node_or_null("StatusEffectComponent")
		if component and status_effect:
			component.apply_effect(status_effect, self)
	
	if body.is_in_group("crate"):
		print("  -> is crate, has break method: ", body.has_method("break_from_explosion"))
		if body.has_method("break_from_explosion"):
			body.break_from_explosion()
