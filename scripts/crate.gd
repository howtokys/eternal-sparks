extends StaticBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $Collision
@onready var hurt_box: Area2D = $HurtBox

const PICKUP = preload("uid://ddfou1e6ljx0n")
const DEBRIS = preload("uid://bm3q8tehrkl51")

@export var possible_loot: Array[ItemData] = []

var is_broken: bool = false

func _ready() -> void:
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)

func _on_hurt_box_area_entered(area: Area2D) -> void:
	if is_broken:
		return
		
	if area is Bullet or area.is_in_group("enemy_attack"):
		call_deferred("_break_crate", area)


func _break_crate(area: Area2D) -> void:
	if is_broken:		
		return
	is_broken = true
	
	# Get the direction the bullet was moving
	var hit_direction := Vector2.RIGHT
	if area is Bullet:
		hit_direction = area.target_position.normalized()
	elif area and area.global_position != global_position:
		hit_direction = global_position.direction_to(area.global_position)
	
	collision.set_deferred("disabled", true)
	hurt_box.set_deferred("monitoring", false)
	sprite_2d.hide()
	
	# Sample the main color from the sprite texture
	var base_color = Color(0.55, 0.35, 0.17) # hardcoded	
	if sprite_2d.texture:
		var img = sprite_2d.texture.get_image()
		if img:
			base_color = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	
	# Spawn debris
	for i in range(randi_range(3, 5)):
		var debris = DEBRIS.instantiate()
		debris.visible = false
		get_tree().current_scene.add_child(debris)
		
		debris.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		
		var spawn_center = sprite_2d.global_position
		var scatter = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		var shoot_dir = (hit_direction + scatter).normalized()
		
		debris.setup(shoot_dir, base_color, spawn_center)
		debris.reset_physics_interpolation()
		debris.visible = true
	
	if area is Bullet and is_instance_valid(area):
		area.queue_free()
	
	# Spawn pickup
	if possible_loot.size() > 0:
		var valid_loot: Array[ItemData] = []
		for item in possible_loot:
			if randf() * 100.0 < item.drop_chance_weight:
				valid_loot.append(item)
		
		if valid_loot.size() > 0:
			var pickup = PICKUP.instantiate()	
			pickup.visible = false
			
			get_tree().current_scene.add_child(pickup)
			
			pickup.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			pickup.global_position = sprite_2d.global_position
			pickup.reset_physics_interpolation()
			pickup.data = valid_loot[randi() % valid_loot.size()]
			
			await get_tree().process_frame
			pickup.visible = true
	
	GlobalData.drop_money(global_position, 0.03) #3%
	await get_tree().create_timer(0.2).timeout
	queue_free()
	
func break_from_explosion() -> void:
	if is_broken:
		return
	_break_crate(null)
