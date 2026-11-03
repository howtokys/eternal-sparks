extends StaticBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var glow: Sprite2D = $Glow
@onready var label: Label = $Label
@onready var interact_zone: Area2D = $InteractZone

const PICKUP = preload("uid://ddfou1e6ljx0n")

@export var closed_texture: Texture2D
@export var drop: ItemData

var player_in_range: Node2D = null
var is_open: bool = false
var base_glow_scale: Vector2
var glow_time: float = 0.0

func _ready() -> void:
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)

	if label:
		label.text = "Press E"
		label.hide()

	if closed_texture:
		sprite_2d.texture = closed_texture

	_setup_glow()
	base_glow_scale = glow.scale
	glow.show()

func _process(delta: float) -> void:
	if is_open:
		return

	glow_time += delta
	glow.scale = base_glow_scale * (1.0 + sin(glow_time * 2.5) * 0.06)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		if not is_open:
			label.show()

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		label.hide()

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
	label.hide()
	var glow_tween := create_tween()
	glow_tween.tween_property(glow, "modulate:a", 0.0, 0.5)
	glow_tween.finished.connect(glow.hide)
	sprite_2d.modulate = Color(1.15, 1.1, 0.9)

	var pickup = PICKUP.instantiate()
	pickup.visible = false
	get_tree().current_scene.add_child(pickup)

	pickup.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pickup.global_position = global_position + Vector2(0, 18)
	pickup.data = drop
	pickup.reset_physics_interpolation()

	await get_tree().process_frame
	pickup.visible = true

func _setup_glow() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.9),
		Color(1.0, 1.0, 1.0, 0.0),
	])

	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 64
	gradient_texture.height = 64
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.texture = gradient_texture
	glow.material = material
	glow.modulate = Color(1.0, 0.8, 0.35)
