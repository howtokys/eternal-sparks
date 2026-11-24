class_name Weapon
extends Sprite2D

@onready var marker_2d: Marker2D = $Marker2D
@onready var attack_hitbox: WeaponHitbox = $AttackHitbox
@onready var player: Node2D = $".."
const BULLET = preload("uid://bjlscu3tlwgwo")
const LASER_BEAM = preload("res://scripts/laser_beam.gd")
const HAMMER_SHOCKWAVE = preload("res://scripts/hammer_shockwave.gd")
const RECOIL_RECOVERY_SECONDS := 0.1

@export var data: WeaponData
var muzzle_flash: Sprite2D
var muzzle_flash_tween: Tween
var cooldown_remaining: float = 0.0
var base_position: Vector2
var swing_rotation_offset: float = 0.0
var poke_position_offset: float = 0.0
var recoil_offset: float = 0.0
var attack_in_progress: bool = false
var attack_facing_sign: float = 1.0
var attack_elapsed: float = 0.0
var buffered_attack: bool = false
var burst_shots_left: int = 0
var burst_timer: float = 0.0
var burst_cooldown_remaining: float = 0.0
var trigger_held: bool = false
var laser_beam: LASER_BEAM
var hammer_shockwave: HAMMER_SHOCKWAVE

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
	attack_hitbox.area_entered.connect(_on_hammer_contact)
	attack_hitbox.collision_mask |= 8
	attack_hitbox.area_entered.connect(_on_strike_overlap)
	_create_muzzle_flash()
	_update_weapon_data()

func _on_strike_overlap(area: Area2D) -> void:
	if area is Bullet and attack_phase == AttackPhase.STRIKE and player.buff_manager.get_buff_level(&"reflect") > 0:
		area.reflect_projectile()

func set_weapon_data(value: WeaponData) -> void:
	data = value
	_update_weapon_data()

func cancel_attack() -> void:
	_stop_laser_beam()
	hammer_shockwave = null
	attack_phase = AttackPhase.IDLE
	attack_in_progress = false
	attack_elapsed = 0.0
	buffered_attack = false
	burst_shots_left = 0
	burst_timer = 0.0
	burst_cooldown_remaining = 0.0
	swing_rotation_offset = 0.0
	poke_position_offset = 0.0
	recoil_offset = 0.0
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
	if recoil_offset > 0.0:
		recoil_offset = move_toward(recoil_offset, 0.0, delta * data.recoil_px / RECOIL_RECOVERY_SECONDS)

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
	position = base_position + Vector2.RIGHT.rotated(rotation) * (poke_position_offset - recoil_offset)
	_update_hammer_shockwave()

	if trigger_held and data != null:
		if data.kind == WeaponData.WeaponKind.MELEE:
			shoot()
		elif data.fire_mode == WeaponData.FireMode.BEAM:
			shoot()

func _physics_process(_delta: float) -> void:
	if data == null or data.fire_mode != WeaponData.FireMode.CONTINUOUS_BEAM or not trigger_held:
		_stop_laser_beam()
		return

	var damage_tick := cooldown_remaining <= 0.0
	if damage_tick:
		if not player.use_mana(data.mana_cost):
			_stop_laser_beam()
			return
		cooldown_remaining = 1.0 / data.fire_rate
		recoil_offset = data.recoil_px

	if not is_instance_valid(laser_beam):
		if not damage_tick:
			return
		laser_beam = LASER_BEAM.new()
		laser_beam.top_level = true
		add_child(laser_beam)
		laser_beam.start_sound(data.fire_sound)
	laser_beam.trace(global_position, marker_2d.global_position, global_transform.x.normalized(), data, damage_tick)

func _stop_laser_beam() -> void:
	if is_instance_valid(laser_beam):
		laser_beam.stop()
		laser_beam = null

func _update_hammer_shockwave() -> void:
	if not attack_hitbox.monitoring or data.id != "war_hammer":
		hammer_shockwave = null
		return

	# Follow the live damage circle until it hits something or the strike ends.
	var hit_shape := attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(hammer_shockwave):
		var circle := hit_shape.shape as CircleShape2D
		hammer_shockwave = HAMMER_SHOCKWAVE.new()
		hammer_shockwave.radius = circle.radius * hit_shape.global_scale.x
		get_tree().current_scene.add_child(hammer_shockwave)
	if not hammer_shockwave.locked_on_impact:
		hammer_shockwave.global_position = hit_shape.global_position

func _on_hammer_contact(area: Area2D) -> void:
	if not is_instance_valid(hammer_shockwave) or hammer_shockwave.locked_on_impact:
		return
	var target := area.get_parent()
	if target.is_in_group("enemy") or target.is_in_group("crate"):
		var hit_shape := attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
		hammer_shockwave.global_position = hit_shape.global_position
		hammer_shockwave.locked_on_impact = true

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

	if data.fire_mode in [WeaponData.FireMode.BURST, WeaponData.FireMode.CONTINUOUS_BEAM]:
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

	Audio.play_sfx(data.fire_sound, 0.0, randf_range(0.95, 1.05))

	if not bypass_cooldown and data.fire_rate > 0.0:
		cooldown_remaining = 1.0 / data.fire_rate

	recoil_offset = data.recoil_px
	_trigger_muzzle_flash()
	var is_staff := data.kind == WeaponData.WeaponKind.STAFF
	var base_direction := (get_global_mouse_position() - marker_2d.global_position).normalized()
	if is_staff:
		base_direction = global_transform.x.normalized()
	var deadly: int = player.buff_manager.get_buff_level(&"deadly_strike")
	var pellet_count := maxi(data.pellet_count, 1)
	for pellet_index in range(pellet_count):
		var spread_ratio := 0.0
		if pellet_count > 1:
			spread_ratio = float(pellet_index) / float(pellet_count - 1) * 2.0 - 1.0
		var direction := base_direction.rotated(
			deg_to_rad(data.spread_degrees * spread_ratio * (1.0 - 0.2 * deadly))
		)
		var new_bullet: Bullet = BULLET.instantiate()
		new_bullet.data = data
		new_bullet.bounces_left = player.buff_manager.get_buff_level(&"ricochet")
		if deadly > 0 and randf() < 0.1 * deadly:
			new_bullet.damage *= 2
		new_bullet.position = marker_2d.global_position
		new_bullet.target_position = direction
		new_bullet.rotation = direction.angle()
		get_tree().current_scene.add_child(new_bullet)
	return true

func _create_muzzle_flash() -> void:
	muzzle_flash = Sprite2D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.visible = false
	muzzle_flash.z_index = 2
	var flash_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	flash_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(32):
		for x in range(32):
			var offset := Vector2(x, y) - Vector2(16, 16)
			var distance := offset.length()
			var pixel_is_flash := distance <= 4.0
			pixel_is_flash = pixel_is_flash or (
				offset.x >= 2.0
				and offset.x <= 14.0
				and absf(offset.y) <= 2.0
			)
			pixel_is_flash = pixel_is_flash or (
				absf(offset.x) <= 1.0
				and absf(offset.y) <= 8.0
			)
			pixel_is_flash = pixel_is_flash or (
				absf(absf(offset.x) - absf(offset.y)) <= 1.0
				and absf(offset.x) <= 6.0
			)
			if pixel_is_flash:
				flash_image.set_pixel(x, y, Color(1.0, 1.0, 0.95, 1.0))
	muzzle_flash.texture = ImageTexture.create_from_image(flash_image)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	muzzle_flash.material = material
	add_child(muzzle_flash)

func _trigger_muzzle_flash() -> void:
	if muzzle_flash == null:
		return
	if muzzle_flash_tween != null:
		muzzle_flash_tween.kill()
	muzzle_flash.position = marker_2d.position
	muzzle_flash.rotation = randf_range(-0.2, 0.2)
	var flash_tint := Color(1.0, 0.9, 0.6)
	if data != null:
		match data.element:
			"burn":
				flash_tint = Color(1.0, 0.6, 0.2)
			"frost":
				flash_tint = Color(0.6, 0.85, 1.0)
			"storm":
				flash_tint = Color(0.75, 0.5, 1.0)
	muzzle_flash.modulate = flash_tint
	muzzle_flash.scale = Vector2.ONE * randf_range(0.65, 0.80)
	muzzle_flash.visible = true
	muzzle_flash.modulate.a = 1.0
	muzzle_flash_tween = create_tween()
	muzzle_flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.06)
	muzzle_flash_tween.tween_callback(func() -> void: muzzle_flash.visible = false)

func _draw() -> void:
	if data == null or data.kind == WeaponData.WeaponKind.RANGED or data.id == "war_hammer":
		return
	if attack_phase != AttackPhase.STRIKE:
		return
	var strike_progress := clampf(
		(attack_elapsed - data.windup_duration) / data.anim_duration,
		0.0,
		1.0
	)
	var effect_color := Color(0.8, 0.9, 1.0, 0.9 * (1.0 - strike_progress))
	if data.attack_anim == WeaponData.AttackAnim.POKE:
		var tip := Vector2(22, 0)
		var streak_length := lerpf(6.0, 18.0, strike_progress)
		draw_line(tip, tip + Vector2(streak_length, 0), effect_color, 3.0)
		var ring_radius := lerpf(3.0, 10.0, strike_progress)
		draw_arc(tip, ring_radius, 0.0, TAU, 24, effect_color, 2.0)
		return

	draw_arc(Vector2.ZERO, 20.0, -0.7, 0.7, 24, effect_color, 3.0)

func _start_melee_attack() -> void:
	if attack_in_progress or not is_instance_valid(attack_hitbox):
		return

	if not data.play_sound_on_strike:
		Audio.play_sfx(data.fire_sound, 0.0, randf_range(0.95, 1.05))

	attack_hitbox.begin_swing()
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
		if attack_phase != AttackPhase.STRIKE and data.play_sound_on_strike:
			Audio.play_sfx(data.fire_sound, 0.0, randf_range(0.95, 1.05))
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
