extends Area2D
class_name Bullet

@export var speed : int = 400
@export var damage: int = 1
var target_position: Vector2
var despawn_time: float = 2.0
var pierce: int = 0
var hit_count: int = 0
var _data: WeaponData
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
		$Sprite2D.texture = value.projectile_texture

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	despawn()

func _physics_process(delta: float) -> void:
	position += target_position * speed * delta

func _on_body_entered(body: Node2D) -> void:
	_hit()

func _on_area_entered(_area: Area2D) -> void:
	_hit()

func _hit() -> void:
	hit_count += 1
	if hit_count > pierce:
		queue_free()

func despawn() -> void:
	await get_tree().create_timer(despawn_time).timeout
	queue_free()
