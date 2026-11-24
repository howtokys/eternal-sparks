extends Node2D

const DURATION := 0.33
const EXPANSION_TIME := 0.075
const DUST_COUNT := 15
const DUST_COLORS := [Color("#725355"), Color("#a57b62"), Color("#d7ac7e"), Color("#efd1a3")]

var radius: float
var locked_on_impact: bool = false
var elapsed: float = 0.0
var dust_angles := PackedFloat32Array()
var dust_distances := PackedFloat32Array()

func _ready() -> void:
	z_index = 2
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Visual randomness stays separate from gameplay rolls.
	var random := RandomNumberGenerator.new()
	random.randomize()
	for index in range(DUST_COUNT):
		dust_angles.append(TAU * (index + random.randf_range(-0.35, 0.35)) / DUST_COUNT)
		dust_distances.append(random.randf_range(0.45, 0.92))

func finish_miss() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.05)
	fade.tween_callback(queue_free)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var spread := minf(elapsed / EXPANSION_TIME, 1.0)
	var outer_radius := radius * lerpf(0.22, 1.0, 1.0 - pow(1.0 - spread, 2.0))
	var fade := 1.0 - elapsed / DURATION
	var extent := ceili(outer_radius)
	var ring_color := Color(1.0, 0.75, 0.46, fade * 0.9)
	var shade_color := Color(0.64, 0.36, 0.28, fade * 0.62)
	for y in range(-extent, extent):
		for x in range(-extent, extent):
			var pixel := Vector2(x, y)
			var distance := (pixel + Vector2(0.5, 0.5)).length()
			if distance <= outer_radius and distance > outer_radius - 2.0:
				var color := ring_color if distance > outer_radius - 0.9 else shade_color
				draw_rect(Rect2(pixel, Vector2.ONE), color)

	var dust_travel := 1.0 - pow(fade, 2.0)
	for index in range(DUST_COUNT):
		var direction := Vector2.from_angle(dust_angles[index])
		var pixel := (direction * radius * dust_distances[index] * dust_travel).round()
		var size := 2.0 + float(index % 2)
		var color: Color = DUST_COLORS[index % DUST_COLORS.size()]
		color.a = fade * 0.9
		draw_rect(Rect2(pixel - Vector2.ONE, Vector2(size, size)), color)
