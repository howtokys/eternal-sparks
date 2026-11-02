class_name Weapon
extends Sprite2D

@onready var marker_2d: Marker2D = $Marker2D
@onready var attack_hitbox: WeaponHitbox = $AttackHitbox
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
	attack_hitbox.position = data.muzzle_offset
	attack_hitbox.damage = data.damage
	attack_hitbox.element = data.element
	attack_hitbox.knockback = data.knockback
	var shape := attack_hitbox.get_node("CollisionShape2D").shape as CircleShape2D
	shape.radius = maxf(data.range_px, 1.0)

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
	if not is_instance_valid(attack_hitbox):
		return
	attack_hitbox.collision_layer = 1
	attack_hitbox.monitoring = true
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(attack_hitbox):
		attack_hitbox.collision_layer = 0
		attack_hitbox.monitoring = false
