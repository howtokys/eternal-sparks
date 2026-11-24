extends StaticBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var glow: Sprite2D = $Glow
@onready var prompt: Control = $Prompt
@onready var lid: Sprite2D = $Lid
@onready var interior: Polygon2D = $Interior
@onready var interact_zone: Area2D = $InteractZone

const PICKUP = preload("uid://ddfou1e6ljx0n")
const CHEST_SPRITE_SIZE := Vector2(48, 48)
const LID_ROWS := 26.0

@export var closed_texture: Texture2D
@export var drop: ItemData
@export var open_sound: AudioStream

var player_in_range: Node2D = null
var is_open: bool = false
var base_glow_scale: Vector2
var glow_time: float = 0.0

func _ready() -> void:
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)

	if closed_texture:
		sprite_2d.texture = closed_texture

	base_glow_scale = glow.scale

func _process(delta: float) -> void:
	if is_open:
		return

	glow_time += delta
	var pulse := sin(glow_time * 1.9)
	glow.scale = base_glow_scale * (1.0 + pulse * 0.03)
	glow.modulate.a = 0.82 + pulse * 0.09

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		if not is_open:
			prompt.show()

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		_open()

func _open() -> void:
	if is_open:
		return
	if drop == null:
		push_error("Chest is missing a drop resource.")
		return

	is_open = true
	Audio.play_sfx(open_sound)
	prompt.hide()
	_animate_opening()

	glow.modulate.a = 1.0
	var glow_tween := create_tween()
	glow_tween.tween_property(glow, "modulate:a", 0.0, 0.36)
	glow_tween.finished.connect(glow.hide)

	var pickup = PICKUP.instantiate()
	pickup.visible = false
	get_tree().current_scene.add_child(pickup)

	pickup.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pickup.global_position = global_position + Vector2(0, 18)
	pickup.data = drop
	pickup.reset_physics_interpolation()

	await get_tree().process_frame
	pickup.visible = true

func _animate_opening() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if sprite_2d.texture.get_size() != CHEST_SPRITE_SIZE:
		var rest_scale := sprite_2d.scale
		tween.tween_property(sprite_2d, "scale", rest_scale * 1.06, 0.08)
		tween.tween_property(sprite_2d, "scale", rest_scale, 0.12)
		return

	# Split the original sprite at the lid seam, keeping the base in place.
	var center := sprite_2d.position
	sprite_2d.region_enabled = true
	sprite_2d.region_filter_clip_enabled = true
	sprite_2d.region_rect = Rect2(0, LID_ROWS, CHEST_SPRITE_SIZE.x, CHEST_SPRITE_SIZE.y - LID_ROWS)
	sprite_2d.position.y += LID_ROWS * 0.5
	lid.texture = sprite_2d.texture
	lid.region_filter_clip_enabled = true
	lid.region_rect = Rect2(0, 0, CHEST_SPRITE_SIZE.x, LID_ROWS)
	lid.position = center - Vector2(0, (CHEST_SPRITE_SIZE.y - LID_ROWS) * 0.5)
	interior.show()
	lid.show()
	tween.tween_property(lid, "position:y", lid.position.y - 6.0, 0.18)
	tween.parallel().tween_property(lid, "scale:y", 0.82, 0.18)
