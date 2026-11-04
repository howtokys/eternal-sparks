extends Area2D

@export var duration: float = 6.0
@export var status_effect: StatusEffect
@export var grow_time: float = 0.25
@export var shrink_time: float = 0.4

var targets_inside: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, grow_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	
	await get_tree().create_timer(duration - shrink_time).timeout
	var shrink_tween = create_tween()
	shrink_tween.tween_property(self, "scale", Vector2.ZERO, shrink_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await shrink_tween.finished
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.is_in_group("enemy")):
		return
	if targets_inside.has(body):
		return
	
	targets_inside.append(body)
	
	var component = body.get_node_or_null("StatusEffectComponent")
	if component and status_effect:
		component.apply_effect(status_effect, self)

func _on_body_exited(body: Node2D) -> void:
	if not targets_inside.has(body):
		return
	
	targets_inside.erase(body)
	
	var component = body.get_node_or_null("StatusEffectComponent")
	if component and status_effect:
		component.remove_source(status_effect.id, self)
