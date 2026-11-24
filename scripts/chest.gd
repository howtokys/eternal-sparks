extends StaticBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var glow: Sprite2D = $Glow
@onready var opening_sparks: Sprite2D = $OpeningSparks
@onready var prompt: Control = $Prompt
@onready var lid: Sprite2D = $Lid
@onready var interior: Polygon2D = $Interior
@onready var interact_zone: Area2D = $InteractZone

const PICKUP = preload("uid://ddfou1e6ljx0n")
const WEAPON_LOOT := preload("res://scripts/weapons/weapon_loot.gd")
const CHEST_SPRITE_SIZE := Vector2(48, 48)
const LID_ROWS := 26.0
const OPENING_COLORS := [Color("#ffcb91"), Color("#aff3ff"), Color("#ffe389")]

@export var closed_texture: Texture2D
@export var loot_tier: WEAPON_LOOT.Tier = WEAPON_LOOT.Tier.BROWN
## Optional fixed reward for a scripted chest.
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
	is_open = true
	var reward := drop if drop != null else WEAPON_LOOT.roll(loot_tier)
	Audio.play_sfx(open_sound)
	prompt.hide()
	_animate_opening()
	_play_opening_effect()

	var pickup = PICKUP.instantiate()
	pickup.visible = false
	get_tree().current_scene.add_child(pickup)

	pickup.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pickup.global_position = global_position + Vector2(0, 18)
	pickup.data = reward
	pickup.reset_physics_interpolation()

	await get_tree().process_frame
	if is_instance_valid(pickup):
		pickup.show()

func _play_opening_effect() -> void:
	var tint: Color = OPENING_COLORS[loot_tier]
	opening_sparks.modulate = tint
	glow.modulate = tint
	var effect := create_tween()
	effect.tween_interval(0.04)
	effect.tween_callback(opening_sparks.show)
	for frame in range(opening_sparks.hframes):
		effect.tween_callback(opening_sparks.set_frame.bind(frame))
		effect.tween_interval(0.045)
	effect.tween_callback(opening_sparks.hide)

	var halo := create_tween()
	halo.tween_property(glow, "scale", base_glow_scale * 1.12, 0.08).set_trans(Tween.TRANS_CUBIC)
	halo.tween_property(glow, "modulate:a", 0.0, 0.28)
	halo.tween_callback(glow.hide)

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
