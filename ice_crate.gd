extends StaticBody2D

@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var hurt_box: Area2D = $HurtBox

const ICE_SPIKE = preload("uid://cxwa3e3rclnta")

@export var spike_count = 8
@export var status_effect: StatusEffect

var is_broken: bool = false

func _ready() -> void:
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)

func _on_hurt_box_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	if area is Bullet:
		if area.claim_target_hit():
			break_from_impact()
	elif area is WeaponHitbox:
		if area.claim_target_hit(self):
			break_from_impact()
	elif area.is_in_group("enemy_attack"):
		break_from_impact()

func _break_crate() -> void:
	if is_broken:
		return
	is_broken = true

	collision_shape_2d.set_deferred("disabled", true)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("collision_layer", 0)
	sprite_2d.hide()

	for i in spike_count:
		var angle = (TAU / spike_count) * i
		var dir = Vector2(cos(angle), sin(angle))

		var spike = ICE_SPIKE.instantiate()
		spike.visible = false
		spike.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

		get_tree().current_scene.add_child(spike)
		spike.global_position = global_position
		spike.reset_physics_interpolation()

		spike.status_effect = status_effect
		spike.setup(dir)
		spike.visible = true

	await get_tree().create_timer(0.1).timeout
	queue_free()

func break_from_impact() -> void:
	_break_crate.call_deferred()

func break_from_explosion() -> void:
	break_from_impact()
