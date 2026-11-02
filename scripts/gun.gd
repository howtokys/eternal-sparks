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
var attack_elapsed: float = 0.0
var buffered_attack: bool = false

enum AttackPhase {
	IDLE,
	WINDUP,
	STRIKE,
	RECOVERY,
}

var attack_phase: AttackPhase = AttackPhase.IDLE

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

func cancel_attack() -> void:
	attack_phase = AttackPhase.IDLE
	attack_in_progress = false
	attack_elapsed = 0.0
	buffered_attack = false
	swing_rotation_offset = 0.0
	poke_position_offset = 0.0
	position = base_position
	attack_hitbox.collision_layer = 0
	attack_hitbox.monitoring = false

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

	_update_attack_cycle(delta)
	rotation += swing_rotation_offset
	position = base_position + Vector2.RIGHT.rotated(rotation) * poke_position_offset

func shoot() -> void:
	if data == null:
		return

	if data.kind == WeaponData.WeaponKind.MELEE:
		if attack_in_progress:
			if attack_phase == AttackPhase.RECOVERY:
				var recovery_remaining := data.attack_cycle_duration() - attack_elapsed
				if recovery_remaining <= 0.15:
					buffered_attack = true
			return

		if player.use_mana(data.mana_cost):
			_start_melee_attack()
		return

	if cooldown_remaining > 0.0:
		return

	if player.use_mana(data.mana_cost):
		if data.fire_rate > 0.0:
			cooldown_remaining = 1.0 / data.fire_rate

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

func _start_melee_attack() -> void:
	if attack_in_progress or not is_instance_valid(attack_hitbox):
		return

	attack_in_progress = true
	buffered_attack = false
	attack_elapsed = 0.0
	attack_phase = AttackPhase.WINDUP
	attack_facing_sign = -1.0 if flip_v else 1.0
	attack_hitbox.collision_layer = 0
	attack_hitbox.monitoring = false

func _update_attack_cycle(delta: float) -> void:
	if not attack_in_progress or data == null:
		return

	attack_elapsed += delta
	var windup_duration := data.windup_duration
	var strike_duration := data.anim_duration
	var recovery_duration := data.recovery_duration
	var cycle_duration := data.attack_cycle_duration()

	if attack_elapsed >= cycle_duration:
		_finish_melee_attack()
		return

	if attack_elapsed < windup_duration:
		attack_phase = AttackPhase.WINDUP
		_set_windup_progress(attack_elapsed / windup_duration)
	elif attack_elapsed < windup_duration + strike_duration:
		attack_phase = AttackPhase.STRIKE
		var strike_progress := (attack_elapsed - windup_duration) / strike_duration
		_set_strike_progress(strike_progress)
	else:
		attack_phase = AttackPhase.RECOVERY
		var recovery_progress := (
			attack_elapsed - windup_duration - strike_duration
		) / recovery_duration
		_set_recovery_progress(recovery_progress)

	var strike_elapsed := attack_elapsed - windup_duration
	var hitbox_start := minf(0.025, strike_duration * 0.2)
	var hitbox_end := minf(strike_duration - 0.025, hitbox_start + 0.1)
	var should_enable_hitbox := (
		strike_elapsed >= hitbox_start
		and strike_elapsed < hitbox_end
	)
	if should_enable_hitbox and attack_phase == AttackPhase.STRIKE:
		attack_hitbox.collision_layer = 1
		attack_hitbox.monitoring = true
	else:
		attack_hitbox.collision_layer = 0
		attack_hitbox.monitoring = false

func _set_windup_progress(progress: float) -> void:
	var eased_progress := _ease_in_out(clampf(progress, 0.0, 1.0))
	if data.attack_anim == WeaponData.AttackAnim.POKE:
		poke_position_offset = -data.poke_distance * 0.35 * eased_progress
		swing_rotation_offset = 0.0
		return

	swing_rotation_offset = (
		-deg_to_rad(data.swing_angle_degrees)
		* attack_facing_sign
		* 0.35
		* eased_progress
	)
	poke_position_offset = 0.0

func _set_strike_progress(progress: float) -> void:
	var eased_progress := _ease_in_out(clampf(progress, 0.0, 1.0))
	var strike_offset: float
	if eased_progress <= 0.5:
		strike_offset = lerpf(-0.35, 1.0, eased_progress * 2.0)
	else:
		strike_offset = lerpf(1.0, 0.35, (eased_progress - 0.5) * 2.0)
	if data.attack_anim == WeaponData.AttackAnim.POKE:
		poke_position_offset = data.poke_distance * strike_offset
		swing_rotation_offset = 0.0
		return

	swing_rotation_offset = (
		deg_to_rad(data.swing_angle_degrees)
		* attack_facing_sign
		* strike_offset
	)
	poke_position_offset = 0.0

func _set_recovery_progress(progress: float) -> void:
	var eased_progress := _ease_in_out(clampf(progress, 0.0, 1.0))
	var recovery_offset := 0.35 * (1.0 - eased_progress)
	if data.attack_anim == WeaponData.AttackAnim.POKE:
		poke_position_offset = data.poke_distance * recovery_offset
		swing_rotation_offset = 0.0
		return

	swing_rotation_offset = (
		deg_to_rad(data.swing_angle_degrees)
		* attack_facing_sign
		* recovery_offset
	)
	poke_position_offset = 0.0

func _finish_melee_attack() -> void:
	attack_in_progress = false
	attack_phase = AttackPhase.IDLE
	attack_elapsed = 0.0
	swing_rotation_offset = 0.0
	poke_position_offset = 0.0
	attack_hitbox.collision_layer = 0
	attack_hitbox.monitoring = false
	if buffered_attack:
		buffered_attack = false
		shoot()

func _ease_in_out(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)
