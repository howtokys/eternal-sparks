extends Sprite2D

@onready var marker_2d: Marker2D = $Marker2D
const BULLET = preload("uid://bjlscu3tlwgwo")

func _process(delta: float) -> void:
	look_at(get_global_mouse_position())
	
	if global_rotation > PI / 2 or global_rotation < -PI / 2:
		flip_v = true
	else:
		flip_v = false
	
func shoot() -> void:
	var new_bullet = BULLET.instantiate()
	new_bullet.position = marker_2d.global_position
	new_bullet.target_position = (get_global_mouse_position() - marker_2d.global_position).normalized()
	new_bullet.rotation = (get_global_mouse_position() - marker_2d.global_position).angle()
	GlobalData.world.add_child(new_bullet)
