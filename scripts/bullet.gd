extends Area2D
class_name Bullet

@export var speed : int = 400
@export var damage: int = 1
@export var hostile := false
var bounces_left := 0
var sweep_walls := false
var target_position: Vector2
var despawn_time: float = 2.0
var element: String = ""
var knockback: float = 0.0
var _data: WeaponData
var _is_staff_shot: bool = false
var _hit_claimed: bool = false
var _hit_targets: Dictionary[int, bool] = {}
const DEFAULT_PROJECTILE_TEXTURE: Texture2D = preload("res://sprites/Bullet.png")
var data: WeaponData:
	get:
		return _data
	set(value):
		_data = value
		if value == null:
			return
		speed = value.projectile_speed
		damage = value.damage
		despawn_time = value.projectile_lifetime
		element = value.element
		knockback = value.knockback
		_is_staff_shot = value.kind == WeaponData.WeaponKind.STAFF
		var projectile_texture := value.projectile_texture
		if projectile_texture == null:
			projectile_texture = DEFAULT_PROJECTILE_TEXTURE
		var sprite := $Sprite2D as Sprite2D
		sprite.texture = projectile_texture
		sprite.modulate = Color.WHITE if _is_staff_shot else _impact_color()

		var collision_shape := $CollisionShape2D as CollisionShape2D
		var rectangle_shape := collision_shape.shape as RectangleShape2D
		if rectangle_shape == null:
			rectangle_shape = RectangleShape2D.new()
			collision_shape.shape = rectangle_shape
		collision_shape.position = Vector2.ZERO
		rectangle_shape.size = value.projectile_hitbox_size
		if _is_staff_shot:
			# Anchor the bolt's bright tip over the hitbox. The tapered tail is visual only.
			sprite.material = null
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.offset.x = 5.0 - projectile_texture.get_width() * 0.5
		sprite.scale = value.projectile_scale

func _ready() -> void:
	sweep_walls = bounces_left > 0
	if hostile:
		collision_layer = 8
		collision_mask = 3
	body_entered.connect(_on_body_entered)
	despawn()

func _physics_process(delta: float) -> void:
	var step := target_position * speed * delta
	if sweep_walls and not step.is_zero_approx():
		var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 2)
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and _is_wall(hit.collider) and not Vector2(hit.normal).is_zero_approx():
			if bounces_left == 0:
				_spawn_impact_burst()
				queue_free()
				return
			target_position = target_position.bounce(hit.normal)
			rotation = target_position.angle()
			global_position = hit.position + target_position * 2
			bounces_left -= 1
			return
	position += step

func _is_wall(body: Node) -> bool:
	return body is TileMapLayer or (body is StaticBody2D and not body.is_in_group("crate"))

func reflect_projectile() -> bool:
	if not hostile or (data != null and (data.fire_mode == WeaponData.FireMode.BEAM or data.id == "laser_gun")):
		return false
	hostile = false
	target_position = -target_position
	rotation = target_position.angle()
	set_deferred("collision_layer", 4)
	set_deferred("collision_mask", 2)
	return true

func _damage_player(player: DungeonPlayer) -> void:
	if hostile and not is_queued_for_deletion() and is_instance_valid(player):
		player.take_damage(damage)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if hostile:
		if body is DungeonPlayer:
			_damage_player.call_deferred(body)
		elif not body.is_in_group("enemy"):
			queue_free()
		return
	# Targets accept damage through their hurtboxes. The sweep handles wall ricochets.
	if body is DungeonPlayer or body.is_in_group("crate") or body.is_in_group("enemy") or (sweep_walls and _is_wall(body)):
		return
	claim_target_hit()

func hit_enemy(enemy: Node2D) -> bool:
	var target_id := enemy.get_instance_id()
	if _hit_targets.has(target_id):
		return false
	if bounces_left <= 0:
		return claim_target_hit()
	if hostile or _hit_claimed or is_queued_for_deletion():
		return false
	_hit_targets[target_id] = true
	bounces_left -= 1
	var normal := enemy.global_position.direction_to(global_position)
	target_position = target_position.bounce(normal) if not normal.is_zero_approx() else -target_position
	rotation = target_position.angle()
	return true

func claim_target_hit() -> bool:
	if hostile or _hit_claimed or is_queued_for_deletion():
		return false
	# Several hurtboxes can report the same overlap before queue_free takes effect.
	_hit_claimed = true
	_spawn_impact_burst.call_deferred()
	queue_free()
	return true

func _spawn_impact_burst() -> void:
	if _data != null and _data.id in ["laser_gun", "railgun"]:
		return
	var particles := GPUParticles2D.new()
	particles.amount = 8 if _is_staff_shot else 12
	particles.lifetime = 0.24
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.global_position = global_position

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(-target_position.x, -target_position.y, 0.0)
	process_material.spread = 60.0
	process_material.initial_velocity_min = 40.0
	process_material.initial_velocity_max = 90.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.6
	process_material.scale_max = 1.4
	process_material.damping_min = 20.0
	process_material.damping_max = 40.0
	process_material.color = _impact_color()
	particles.process_material = process_material

	var particle_gradient := Gradient.new()
	particle_gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var particle_texture := GradientTexture2D.new()
	particle_texture.gradient = particle_gradient
	particle_texture.width = 4
	particle_texture.height = 4
	particles.texture = particle_texture
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func _impact_color() -> Color:
	match element:
		"burn":
			return Color(1.0, 0.6, 0.2)
		"frost":
			return Color(0.6, 0.85, 1.0)
		"storm":
			return Color(0.75, 0.5, 1.0)
		_:
			return Color.WHITE

func despawn() -> void:
	await get_tree().create_timer(despawn_time).timeout
	queue_free()
