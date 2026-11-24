extends Node2D
## Each impact owns its pulses, so simultaneous spike guards stack independently.
enum Shape { WAVE, SPIKES, METEOR }
var shape: Shape
var damage: int
var age := 0.0
var pulses := 0
var tracked_boss: Node2D

func _ready() -> void:
	z_index = 5
	if shape == Shape.WAVE or shape == Shape.SPIKES:
		var sound := AudioStreamPlayer2D.new()
		sound.stream = preload("res://scripts/Buffs/shockwave_pulse.tres")
		sound.volume_db = -7
		add_child(sound)
		sound.play()

func _physics_process(delta: float) -> void:
	age += delta
	if pulses == 0 and is_instance_valid(tracked_boss) and not tracked_boss.is_queued_for_deletion():
		global_position = tracked_boss.global_position
	var start := 0.4 if shape == Shape.METEOR else 0.0
	var total := 3 if shape == Shape.SPIKES else 1
	if pulses < total and age >= start + pulses * 0.15:
		pulses += 1
		var targets := get_tree().get_nodes_in_group("enemy")
		for boss in get_tree().get_nodes_in_group("boss"):
			if not targets.has(boss):
				targets.append(boss)
		for target in targets:
			if target is Node2D and not target.is_queued_for_deletion() and target.has_method("take_damage"):
				var offset: Vector2 = (target.global_position - global_position).abs()
				var hit := offset.length() <= 46.0
				if shape == Shape.SPIKES:
					hit = minf(offset.x, offset.y) <= 10 and maxf(offset.x, offset.y) <= 54
				if hit:
					target.take_damage(damage)
	queue_redraw()
	var end_time := 0.22 if shape == Shape.WAVE else start + total * 0.15
	if pulses == total and age >= end_time:
		queue_free()

func _draw() -> void:
	match shape:
		Shape.WAVE:
			var radius := clampf(age * 320.0, 1.0, 46.0)
			var opacity := clampf((0.22 - age) / 0.07, 0.0, 1.0)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(0.18, 0.72, 1.0, opacity), 3)
			draw_arc(Vector2.ZERO, maxf(1.0, radius - 2), 0, TAU, 40, Color(0.85, 0.97, 1.0, opacity), 1)
		Shape.SPIKES:
			for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				for step in range(1, 5):
					var tip := axis * step * 13
					var base := tip - axis * 12
					var edge := axis.orthogonal() * 5
					draw_colored_polygon(PackedVector2Array([base + edge, tip, base - edge]), Color.HOT_PINK)
		Shape.METEOR:
			draw_arc(Vector2.ZERO, 46, 0, TAU, 32, Color.CORAL, 2)
			var height := maxf(0, 0.4 - age) * 190
			draw_circle(Vector2(height, -height), 8 if height > 0 else 22, Color.ORANGE_RED)
