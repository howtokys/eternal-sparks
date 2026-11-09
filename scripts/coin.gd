extends Area2D

enum CoinType { BRONZE, SILVER, GOLD }

@export var coin_type: CoinType = CoinType.BRONZE
@export var bronze_frames: SpriteFrames
@export var silver_frames: SpriteFrames
@export var gold_frames: SpriteFrames
@export var attract_radius: float = 40.0
@export var attract_speed: float = 120.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var amount: int = 1
var player: Node2D = null
var is_attracted: bool = false

func _ready() -> void:
	match coin_type:
		CoinType.BRONZE:
			amount = 1
			if bronze_frames:
				animated_sprite_2d.sprite_frames = bronze_frames
		
		CoinType.SILVER:
			amount = 3
			if silver_frames:
				animated_sprite_2d.sprite_frames = silver_frames
		
		CoinType.GOLD:
			amount = 5
			if silver_frames:
				animated_sprite_2d.sprite_frames = gold_frames
	animated_sprite_2d.play("spin")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
		
	var dist = global_position.distance_to(player.global_position)
	
	if dist <= attract_radius:
		is_attracted = true
		
	if is_attracted:
		var dir = global_position.direction_to(player.global_position)
		global_position += dir * attract_speed * delta
		
		if dist < 8.0:
			GlobalData.add_money(amount)
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GlobalData.add_money(amount)
		queue_free()
