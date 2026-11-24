extends Area2D
class_name Bullet

@export var speed : int = 400
@export var damage: int = 1
@export var hostile := false
var bounces_left := 0
var sweep_walls := false
var target_position: Vector2
var despawn_time: float = 2.0
var pierce: int = 0
var hit_count: int = 0
var element: String = ""
var knockback: float = 0.0
var _data: WeaponData
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
		pierce = value.pierce
		element = value.element
		knockback = value.knockback
		var projectile_texture := value.projectile_texture
		if projectile_texture == null:
			projectile_texture = DEFAULT_PROJECTILE_TEXTURE
		$Sprite2D.texture = projectile_texture
		match value.element:
			"burn":
				$Sprite2D.modulate = Color(1.0, 0.6, 0.2)
			"frost":
				$Sprite2D.modulate = Color(0.6, 0.85, 1.0)
			"storm":
				$Sprite2D.modulate = Color(0.75, 0.5, 1.0)
			_:
				$Sprite2D.modulate = Color.WHITE

		var collision_shape := $CollisionShape2D as CollisionShape2D
		var rectangle_shape := collision_shape.shape as RectangleShape2D
		if rectangle_shape == null:
			rectangle_shape = RectangleShape2D.new()
			collision_shape.shape = rectangle_shape
		var texture_size := projectile_texture.get_size()
		rectangle_shape.size = Vector2(
			minf(texture_size.x, 32.0),
			minf(maxf(4.0, texture_size.y), 32.0)
		)
		scale = value.projectile_scale

func _ready() -> void:
	sweep_walls = bounces_left > 0
	if hostile:
		collision_layer = 8
		collision_mask = 3
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
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
	return body is TileMapLayer or (body is StaticBody2D and not body.has_method("break_from_explosion"))

func reflect_projectile() -> bool:
	if not hostile or (data != null and (data.fire_mode == WeaponData.FireMode.BEAM or data.id == "laser_gun")):
		return false
	hostile = false
	target_position = -target_position
	rotation = target_position.angle()
	set_deferred("collision_layer", 4)
	set_deferred("collision_mask", 2)
	return true

func hit_enemy(enemy: Node2D) -> void:
	if bounces_left > 0:
		bounces_left -= 1
		var normal := enemy.global_position.direction_to(global_position)
		target_position = target_position.bounce(normal) if not normal.is_zero_approx() else -target_position
		rotation = target_position.angle()
	else:
		_hit()

func _damage_player(player: DungeonPlayer) -> void:
	if hostile and not is_queued_for_deletion() and is_instance_valid(player):
		player.take_damage(damage)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if hostile:
		if body is DungeonPlayer:
			_damage_player.call_deferred(body)
		elif _is_wall(body):
			queue_free()
		return
	if body is DungeonPlayer or body.is_in_group("enemy") or (sweep_walls and _is_wall(body)):
		return
	_spawn_impact_burst()
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if hostile or area.get_parent().is_in_group("enemy") or area.get_parent() is DungeonPlayer or area is WeaponHitbox:
		return
	_spawn_impact_burst()
	_hit()

func _spawn_impact_burst() -> void:
	if _data != null and _data.id in ["laser_gun", "railgun", "frost_staff"]:
		return
	var particles := GPUParticles2D.new()
	particles.amount = 12
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

func _hit() -> void:
	hit_count += 1
	if hit_count > pierce:
		queue_free()

func despawn() -> void:
	await get_tree().create_timer(despawn_time).timeout
	queue_free()
