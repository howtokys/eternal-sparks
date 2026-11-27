extends Area2D

@export var speed: float = 180.0
@export var status_effect: StatusEffect

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var has_hit: bool = false

func _ready() -> void:
	animated_sprite_2d.play("fly")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if has_hit:
		return
	position += direction * speed * delta

func setup(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle() + deg_to_rad(90)
func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return
	has_hit = true
	_apply_hit.call_deferred(body)

func _apply_hit(body: Node2D) -> void:
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		_explode()
		return
	if body.has_method("take_damage"):
		body.take_damage(1)

	if body.is_in_group("player") or body.is_in_group("enemy"):
		var component = body.get_node_or_null("StatusEffectComponent")
		if component and status_effect:
			component.apply_effect(status_effect, self)

	_explode()
func _explode() -> void:
	animated_sprite_2d.play("explode")
	set_deferred("monitoring", false)
	await animated_sprite_2d.animation_finished
	queue_free()
