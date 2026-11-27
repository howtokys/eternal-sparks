extends AnimatedSprite2D

# The original body is centered five pixels right of the sprite frame's center.
const MIRRORED_OFFSET_X := 10.0
const HURT_SOUND := preload("res://sounds/player_hurt.wav")

@onready var player := get_parent() as CharacterBody2D
@onready var gun := player.get_node("Gun") as Weapon
@onready var health := player.get_node("HealthComponent") as HealthComponent
var previous_health: int

func _ready() -> void:
	await player.ready
	previous_health = health.current_health
	health.health_changed.connect(_on_health_changed)

func _process(_delta: float) -> void:
	flip_h = gun.global_transform.x.x < 0.0
	position.x = MIRRORED_OFFSET_X if flip_h else 0.0
	if animation == &"hurt" and is_playing():
		return
	play(&"walk" if player.get_real_velocity().length_squared() > 1.0 else &"idle")

func react_to_damage() -> void:
	Audio.play_sfx(HURT_SOUND, 0.0, randf_range(0.96, 1.04))
	play(&"hurt")
	set_frame_and_progress(0, 0.0)

func _on_health_changed(current_health: int) -> void:
	if current_health < previous_health:
		react_to_damage()
	previous_health = current_health
