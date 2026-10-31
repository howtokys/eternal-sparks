class_name Weapon
extends Sprite2D

@onready var marker_2d: Marker2D = $Marker2D
@onready var player: Node2D = $".."
const BULLET = preload("uid://bjlscu3tlwgwo")

@export var data: WeaponData
var cooldown_remaining: float = 0.0

func _ready() -> void:
	if data == null:
		push_error("Weapon data is not assigned.")
		return

	texture = data.texture
	marker_2d.position = data.muzzle_offset

func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta

	look_at(get_global_mouse_position())
	
	if global_rotation > PI / 2 or global_rotation < -PI / 2:
		flip_v = true
	else:
		flip_v = false
	
func shoot() -> void:
	if data == null or cooldown_remaining > 0.0:
		return

	if player.use_mana(data.mana_cost):
		if data.fire_rate > 0.0:
			cooldown_remaining = 1.0 / data.fire_rate
		var new_bullet = BULLET.instantiate()
		new_bullet.data = data
		new_bullet.position = marker_2d.global_position
		new_bullet.target_position = (get_global_mouse_position() - marker_2d.global_position).normalized()
		new_bullet.rotation = (get_global_mouse_position() - marker_2d.global_position).angle()
		get_tree().current_scene.add_child(new_bullet)
