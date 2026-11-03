class_name Weapon
extends Sprite2D

@onready var marker_2d: Marker2D = $Marker2D
@onready var attack_hitbox: WeaponHitbox = $AttackHitbox
@onready var player: Node2D = $".."
const BULLET = preload("uid://bjlscu3tlwgwo")
const DEFAULT_PROJECTILE_TEXTURE: Texture2D = preload("res://sprites/Bullet.png")

@export var data: WeaponData
var muzzle_flash: Sprite2D
var cooldown_remaining: float = 0.0
var base_position: Vector2
var swing_rotation_offset: float = 0.0
var poke_position_offset: float = 0.0
var attack_in_progress: bool = false
var attack_facing_sign: float = 1.0
var attack_elapsed: float = 0.0
var buffered_attack: bool = false
var burst_shots_left: int = 0
var burst_timer: float = 0.0
var burst_cooldown_remaining: float = 0.0
var trigger_held: bool = false

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
	_create_muzzle_flash()
	_update_weapon_data()

func set_weapon_data(value: WeaponData) -> void:
	data = value
	_update_weapon_data()

func cancel_attack() -> void:
	attack_phase = AttackPhase.IDLE
	attack_in_progress = false
	attack_elapsed = 0.0
	buffered_attack = false
	burst_shots_left = 0
	burst_timer = 0.0
	burst_cooldown_remaining = 0.0
	swing_rotation_offset = 0.0
	poke_position_offset = 0.0
	position = base_position
	attack_hitbox.collision_layer = 0
	attack_hitbox.monitoring = false
	queue_redraw()

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
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if burst_cooldown_remaining > 0.0:
		burst_cooldown_remaining = maxf(burst_cooldown_remaining - delta, 0.0)

	if burst_shots_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			if not _fire_ranged_shot(true):
				burst_shots_left = 0
				burst_timer = 0.0
			else:
				burst_shots_left -= 1
				if burst_shots_left == 0:
					burst_cooldown_remaining = data.burst_cooldown
					burst_timer = 0.0
				else:
					burst_timer = data.burst_interval

	look_at(get_global_mouse_position())

	if global_rotation > PI / 2 or global_rotation < -PI / 2:
		flip_v = true
	else:
		flip_v = false

	_update_attack_cycle(delta)
	rotation += swing_rotation_offset
	position = base_position + Vector2.RIGHT.rotated(rotation) * poke_position_offset

	if trigger_held and data != null:
		if data.kind == WeaponData.WeaponKind.MELEE:
			shoot()
		elif data.fire_mode == WeaponData.FireMode.BEAM:
			shoot()

func trigger_pressed() -> void:
	if data == null:
		return

	if data.kind == WeaponData.WeaponKind.MELEE:
		shoot()
	elif data.fire_mode == WeaponData.FireMode.SEMI:
		shoot()
	elif data.fire_mode == WeaponData.FireMode.BURST:
		if burst_shots_left == 0 and burst_cooldown_remaining <= 0.0:
			_start_burst()

func shoot() -> void:
	look_at(get_global_mouse_position())
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

	if data.fire_mode == WeaponData.FireMode.BURST:
		return

	_fire_ranged_shot(false)

func _start_burst() -> void:
	burst_shots_left = maxi(data.burst_count, 1)
	burst_timer = 0.0
	if not _fire_ranged_shot(true):
		burst_shots_left = 0
		return
	burst_shots_left -= 1
	if burst_shots_left == 0:
		burst_cooldown_remaining = data.burst_cooldown
	else:
		burst_timer = data.burst_interval

func _fire_ranged_shot(bypass_cooldown: bool) -> bool:
	if cooldown_remaining > 0.0:
		if not bypass_cooldown:
			return false

	if not player.use_mana(data.mana_cost):
		return false

	if not bypass_cooldown and data.fire_rate > 0.0:
		cooldown_remaining = 1.0 / data.fire_rate

	_trigger_muzzle_flash()
	var base_direction := (get_global_mouse_position() - marker_2d.global_position).normalized()
	var projectile_texture := data.projectile_texture
	if projectile_texture == null:
		projectile_texture = DEFAULT_PROJECTILE_TEXTURE
	var projectile_length := projectile_texture.get_size().x * data.projectile_scale.x
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
		new_bullet.position = (
			marker_2d.global_position
			+ direction * projectile_length * 0.5
		)
		new_bullet.target_position = direction
		new_bullet.rotation = direction.angle()
		get_tree().current_scene.add_child(new_bullet)
	return true

func _create_muzzle_flash() -> void:
	muzzle_flash = Sprite2D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.visible = false
	muzzle_flash.z_index = 2
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.75, 0.25, 1.0),
		Color(1.0, 0.35, 0.05, 0.0),
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 32
	gradient_texture.height = 32
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	muzzle_flash.texture = gradient_texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	muzzle_flash.material = material
	add_child(muzzle_flash)

func _trigger_muzzle_flash() -> void:
	if muzzle_flash == null:
		return
	muzzle_flash.position = marker_2d.position
	muzzle_flash.rotation = -rotation
	muzzle_flash.visible = true
	muzzle_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.06)
	tween.tween_callback(func() -> void: muzzle_flash.visible = false)

func _draw() -> void:
	if data == null or data.kind == WeaponData.WeaponKind.RANGED:
		return
	if attack_phase != AttackPhase.STRIKE:
		return
	var radius := maxf(data.range_px, 12.0)
	var arc_color := Color(0.8, 0.9, 1.0, 0.8)
	draw_arc(Vector2.ZERO, radius, -0.7, 0.7, 24, arc_color, 2.0)

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
	queue_redraw()

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
	queue_redraw()

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
	queue_redraw()
	if buffered_attack:
		buffered_attack = false
		shoot()

func _ease_in_out(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)
