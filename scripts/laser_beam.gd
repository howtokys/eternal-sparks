extends Node2D

const WEAPON_SPARK := preload("res://scripts/weapon_spark.gd")
const ENERGY_STRIP := preload("res://sprites/projectiles/laser_energy_strip.svg")
const TARGET_MASK := 2
const ENERGY_SCROLL_SPEED := 85.0

var endpoint: Vector2
var has_contact: bool = false
var energy_scroll := 0.0
var sound: AudioStreamPlayer
var sound_fade: Tween
var muzzle_spark := WEAPON_SPARK.new()
var contact_spark := WEAPON_SPARK.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(muzzle_spark)
	add_child(contact_spark)
	muzzle_spark.play_spark("laser_gun", false, 0.045, true)
	contact_spark.play_spark("laser_gun", true, 0.045, true)
	contact_spark.hide()

func _process(delta: float) -> void:
	energy_scroll = fposmod(energy_scroll + ENERGY_SCROLL_SPEED * delta, ENERGY_STRIP.get_width())
	queue_redraw()

func start_sound(stream: AudioStream) -> void:
	sound = AudioStreamPlayer.new()
	sound.stream = stream
	sound.bus = Audio.sfx_bus
	sound.volume_db = -34.0
	add_child(sound)
	sound.play()
	sound_fade = create_tween()
	sound_fade.tween_property(sound, "volume_db", 0.0, 0.025)

func stop() -> void:
	hide()
	sound_fade.kill()
	sound_fade = create_tween()
	sound_fade.tween_property(sound, "volume_db", -42.0, 0.035)
	sound_fade.tween_callback(queue_free)

func trace(origin: Vector2, muzzle: Vector2, direction: Vector2, weapon: WeaponData, damage_tick: bool) -> void:
	var limit := muzzle + direction * weapon.range_px
	var query := PhysicsRayQueryParameters2D.create(origin, limit, TARGET_MASK)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	has_contact = not hit.is_empty()
	var contact: Vector2 = hit.position if has_contact else limit
	var blocked_before_muzzle := (contact - muzzle).dot(direction) < 0.0
	global_position = contact if blocked_before_muzzle else muzzle
	endpoint = (contact - global_position).round()
	muzzle_spark.visible = not blocked_before_muzzle
	muzzle_spark.rotation = direction.angle()
	contact_spark.position = endpoint
	contact_spark.rotation = direction.angle()
	contact_spark.visible = has_contact
	queue_redraw()

	if not damage_tick or not has_contact:
		return
	var target := hit.collider as Node
	if target is Area2D:
		target = target.get_parent()
	if target == null:
		return
	if target.is_in_group("crate"):
		target.break_from_impact()
	elif target.is_in_group("enemy"):
		target.take_damage(weapon.damage)

func _draw() -> void:
	if endpoint != Vector2.ZERO:
		var strip_size := Vector2(endpoint.length(), ENERGY_STRIP.get_height())
		draw_set_transform(Vector2.ZERO, endpoint.angle())
		draw_texture_rect_region(
			ENERGY_STRIP,
			Rect2(Vector2(0.0, -strip_size.y * 0.5), strip_size),
			Rect2(Vector2(-floorf(energy_scroll), 0.0), strip_size),
			Color.WHITE,
			false,
			false
		)
