extends Area2D

@export var mana_amount: float = 5.0
@export var attract_radius: float = 40.0
@export var attract_speed: float = 140.0

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var trail: CPUParticles2D = $Trail

var player: Node2D = null
var is_attracted: bool = false

func _ready() -> void:
	z_index = 51
	body_entered.connect(_on_body_entered)
	trail.direction = Vector2(0, -1)
	trail.gravity = Vector2.ZERO
	
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	if dist <= attract_radius:
		is_attracted = true
		trail.emitting = true
	
	if is_attracted:
		var dir = global_position.direction_to(player.global_position)
		global_position += dir * attract_speed * delta
		
		if dist < 8.0:
			player.restore_mana(mana_amount)
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_attracted = true
