extends Area2D
class_name Bullet

@export var speed : int = 400
@export var damage: int = 1
var target_position: Vector2
var despawn_time: float = 2.0
var element: String = ""
var knockback: float = 0.0
var _data: WeaponData
var _is_staff_shot: bool = false
var _hit_claimed: bool = false
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
	body_entered.connect(_on_body_entered)
	despawn()

func _physics_process(delta: float) -> void:
	position += target_position * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Damageable bodies receive the shot through their hurtboxes.
	if body.is_in_group("crate") or body.get_script() == ENEMY_SCRIPT:
		return
	claim_target_hit()

func claim_target_hit() -> bool:
	if _hit_claimed:
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
