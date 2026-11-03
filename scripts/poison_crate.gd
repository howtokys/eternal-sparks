extends StaticBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $Collision
@onready var hurt_box: Area2D = $HurtBox

const GAS_CLOUD = preload("uid://b3p5nwjj5sfyf")

var is_broken: bool = false

func _ready() -> void:
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)

func _on_hurt_box_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	if area is Bullet:
		call_deferred("_break_crate", area)

func _break_crate(area: Area2D) -> void:
	if is_broken:
		return
	is_broken = true
	
	collision.set_deferred("disabled", true)
	hurt_box.set_deferred("monitoring", false)
	sprite_2d.hide()
	
	var gas = GAS_CLOUD.instantiate()
	gas.visible = false
	get_tree().current_scene.add_child(gas)
	
	gas.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	gas.global_position = global_position
	gas.reset_physics_interpolation()
	
	await get_tree().process_frame
	gas.visible = true
	
	if is_instance_valid(area):
		area.queue_free()
	
	await get_tree().create_timer(0.1).timeout
	queue_free()
