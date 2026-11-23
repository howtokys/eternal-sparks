extends Node2D

const TARGET_MASK := 2
const BEAM_EDGE := Color("#238aa8")
const BEAM_INNER := Color("#58dbe9")
const BEAM_CORE := Color("#e9ffff")

var endpoint: Vector2
var has_contact: bool = false
var sound: AudioStreamPlayer
var sound_fade: Tween

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
	global_position = contact if (contact - muzzle).dot(direction) < 0.0 else muzzle
	endpoint = (contact - global_position).round()
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
		draw_line(Vector2.ZERO, endpoint, BEAM_EDGE, 5.0)
		draw_line(Vector2.ZERO, endpoint, BEAM_INNER, 3.0)
		draw_line(Vector2.ZERO, endpoint, BEAM_CORE, 1.0)
	draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 4)), BEAM_INNER)
	if has_contact:
		draw_rect(Rect2(endpoint - Vector2(2, 2), Vector2(4, 4)), BEAM_INNER)
		draw_rect(Rect2(endpoint - Vector2.ONE, Vector2(2, 2)), BEAM_CORE)
