extends Area2D
class_name Bullet

@export var speed : int = 400
@export var damage: int = 1
var target_position: Vector2
var despawn_time: float = 2.0
var pierce: int = 0
var hit_count: int = 0
var element: String = ""
var knockback: float = 0.0
var _data: WeaponData
const DEFAULT_PROJECTILE_TEXTURE: Texture2D = preload("res://sprites/Bullet.png")
const ENEMY_SCRIPT: Script = preload("res://scripts/enemy.gd")
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
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	despawn()

func _physics_process(delta: float) -> void:
	position += target_position * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.get_script() != ENEMY_SCRIPT:
		_spawn_impact_burst()
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().get_script() != ENEMY_SCRIPT:
		_spawn_impact_burst()
	_hit()

func _spawn_impact_burst() -> void:
	if _data != null and _data.id in ["laser_gun", "railgun", "frost_staff"]:
		return
	var particles := GPUParticles2D.new()
	particles.amount = 9
	particles.lifetime = 0.24
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.global_position = global_position

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(-target_position.x, -target_position.y, 0.0)
	process_material.spread = 45.0
	process_material.initial_velocity_min = 30.0
	process_material.initial_velocity_max = 70.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 1.0
	process_material.scale_max = 1.0
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
