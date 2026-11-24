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
var _visual_age := 0.0
var _last_step := 0.0
const WEAPON_SPARK := preload("res://scripts/weapon_spark.gd")
const DEFAULT_PROJECTILE_TEXTURE: Texture2D = preload("res://sprites/Bullet.png")
const STAFF_BOLT_MATERIAL := preload("res://sprites/projectiles/staff_bolt_material.tres")
const BOLT_FRAME_TIME := 0.035
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
		sprite.hframes = maxi(value.projectile_frames, 1)
		sprite.frame = 0
		_visual_age = 0.0
		set_process(sprite.hframes > 1)
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
			sprite.material = STAFF_BOLT_MATERIAL
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.offset.x = 5.0 - float(projectile_texture.get_width()) / sprite.hframes * 0.5
		sprite.scale = value.projectile_scale

func _ready() -> void:
	sweep_walls = bounces_left > 0
	set_process($Sprite2D.hframes > 1)
	if hostile:
		collision_layer = 8
		collision_mask = 3
	body_entered.connect(_on_body_entered)
	despawn()

func _process(delta: float) -> void:
	_visual_age += delta
	var sprite := $Sprite2D as Sprite2D
	sprite.frame = int(_visual_age / BOLT_FRAME_TIME) % sprite.hframes

func _physics_process(delta: float) -> void:
	var step := target_position * speed * delta
	_last_step = step.length()
	if sweep_walls and not step.is_zero_approx():
		var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 2)
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and _is_wall(hit.collider) and not Vector2(hit.normal).is_zero_approx():
			if bounces_left == 0:
				_spawn_impact_burst(hit.position)
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
	claim_target_hit(body)

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

func claim_target_hit(body: Node2D = null) -> bool:
	if hostile or _hit_claimed or is_queued_for_deletion():
		return false
	# Several hurtboxes can report the same overlap before queue_free takes effect.
	_hit_claimed = true
	_spawn_impact_burst.call_deferred(global_position, body)
	queue_free()
	return true

func _spawn_impact_burst(at: Vector2, body: Node2D = null) -> void:
	if _data != null and _data.id in ["laser_gun", "railgun"]:
		return
	var room := get_tree().current_scene
	if room == null:
		return
	var spark := WEAPON_SPARK.new()
	var rifle_shot := _data != null and _data.id == "auto_rifle"
	if rifle_shot and is_instance_valid(body) and _is_wall(body):
		# A fast bullet's center can already be inside the wall when overlap fires.
		var query := PhysicsRayQueryParameters2D.create(
			at - target_position * (_last_step + 8.0), at + target_position * 8.0, collision_mask
		)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.get("collider") == body:
			at = hit.position - target_position
	room.add_child(spark)
	spark.global_position = at
	spark.rotation = target_position.angle()
	spark.reset_physics_interpolation()
	spark.play_spark(_data.id if _data else "", true, 0.025 if rifle_shot else 0.045)
	spark.animation.finished.connect(spark.queue_free)

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
