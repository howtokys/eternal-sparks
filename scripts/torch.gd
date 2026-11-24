extends Node2D

@export var light_color := Color(1.0, 0.61, 0.30)
@export_range(0.0, 2.0) var light_energy := 0.64

@onready var flame: AnimatedSprite2D = $Flame
@onready var glow: PointLight2D = $Glow

var flicker_time := 0.0
var flicker_rate := 1.0


func _ready() -> void:
	glow.color = light_color
	glow.energy = light_energy
	flicker_time = randf_range(0.0, TAU)
	flicker_rate = randf_range(0.89, 1.11)
	var frame_count := flame.sprite_frames.get_frame_count(flame.animation)
	flame.set_frame_and_progress(randi_range(0, frame_count - 1), randf())


func _process(delta: float) -> void:
	flicker_time += delta * flicker_rate
	var flicker := 1.0 + 0.10 * sin(flicker_time * 5.0) + 0.04 * sin(flicker_time * 13.0)
	glow.energy = light_energy * flicker
