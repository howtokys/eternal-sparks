class_name Weapon
extends Sprite2D

@onready var marker_2d: Marker2D = $Marker2D
@onready var attack_hitbox: WeaponHitbox = $AttackHitbox
@onready var player: Node2D = $".."
const BULLET = preload("uid://bjlscu3tlwgwo")

@export var data: WeaponData
var cooldown_remaining: float = 0.0
var base_position: Vector2
var swing_rotation_offset: float = 0.0
var poke_position_offset: float = 0.0
var attack_in_progress: bool = false
var attack_facing_sign: float = 1.0

func _ready() -> void:
	if data == null:
		push_error("Weapon data is not assigned.")
		return

	texture = data.texture
	marker_2d.position = data.muzzle_offset
	base_position = position
	attack_hitbox.collision_layer = 0
	attack_hitbox.monitoring = false
	_update_weapon_data()

func set_weapon_data(value: WeaponData) -> void:
	data = value
	_update_weapon_data()

func _update_weapon_data() -> void:
	if data == null or not is_instance_valid(attack_hitbox):
		return

	texture = data.texture
	marker_2d.position = data.muzzle_offset
	attack_hitbox.position = data.hitbox_offset
	attack_hitbox.damage = data.damage
	attack_hitbox.element = data.element
	attack_hitbox.knockback = data.knockback
	var collision_shape := attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	if data.hitbox_size != Vector2.ZERO:
		var rectangle_shape := RectangleShape2D.new()
		rectangle_shape.size = data.hitbox_size
		collision_shape.shape = rectangle_shape
	else:
		var circle_shape := CircleShape2D.new()
		circle_shape.radius = data.hitbox_radius
		collision_shape.shape = circle_shape

func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta

	look_at(get_global_mouse_position())
	
	if global_rotation > PI / 2 or global_rotation < -PI / 2:
		flip_v = true
	else:
		flip_v = false

	rotation += swing_rotation_offset
	position = base_position + Vector2.RIGHT.rotated(rotation) * poke_position_offset
	
func shoot() -> void:
	if data == null or cooldown_remaining > 0.0:
		return

	if player.use_mana(data.mana_cost):
		if data.fire_rate > 0.0:
			cooldown_remaining = 1.0 / data.fire_rate

		if data.kind == WeaponData.WeaponKind.MELEE:
			_swing()
			return

		var base_direction := (get_global_mouse_position() - marker_2d.global_position).normalized()
		var pellet_count := maxi(data.pellet_count, 1)
		for pellet_index in range(pellet_count):
			var spread_ratio := 0.0
			if pellet_count > 1:
				spread_ratio = float(pellet_index) / float(pellet_count - 1) * 2.0 - 1.0
			var direction := base_direction.rotated(
				deg_to_rad(data.spread_degrees * spread_ratio)
			)
			var new_bullet: Bullet = BULLET.instantiate()
			new_bullet.data = data
			new_bullet.position = marker_2d.global_position
			new_bullet.target_position = direction
			new_bullet.rotation = direction.angle()
			get_tree().current_scene.add_child(new_bullet)

func _swing() -> void:
	if attack_in_progress or not is_instance_valid(attack_hitbox):
		return

	attack_in_progress = true
	swing_rotation_offset = 0.0
	poke_position_offset = 0.0
	attack_facing_sign = -1.0 if flip_v else 1.0
	var duration := maxf(data.anim_duration, 0.01)
	var tween := create_tween()
	tween.tween_method(_set_attack_progress, 0.0, 1.0, duration)

	var hitbox_duration := minf(0.1, duration)
	var hitbox_start_delay := (duration - hitbox_duration) * 0.5
	if hitbox_start_delay > 0.0:
		await get_tree().create_timer(hitbox_start_delay).timeout
	if not is_instance_valid(attack_hitbox):
		attack_in_progress = false
		return
	attack_hitbox.collision_layer = 1
	attack_hitbox.monitoring = true
	await get_tree().create_timer(hitbox_duration).timeout
	if is_instance_valid(attack_hitbox):
		attack_hitbox.collision_layer = 0
		attack_hitbox.monitoring = false
	var remaining_duration := duration - hitbox_start_delay - hitbox_duration
	if remaining_duration > 0.0:
		await get_tree().create_timer(remaining_duration).timeout
	swing_rotation_offset = 0.0
	poke_position_offset = 0.0
	attack_in_progress = false

func _set_attack_progress(progress: float) -> void:
	var motion_progress := progress * 2.0 if progress <= 0.5 else (1.0 - progress) * 2.0
	if data.attack_anim == WeaponData.AttackAnim.POKE:
		poke_position_offset = data.poke_distance * motion_progress
		return

	swing_rotation_offset = deg_to_rad(data.swing_angle_degrees) * attack_facing_sign * motion_progress
