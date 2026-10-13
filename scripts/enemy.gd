extends CharacterBody2D

# Notifies other systems when the enemy is ready to perform a melee attack.
signal attack_requested(target: Node2D)

# Values that can be tuned per enemy instance in the Inspector.
@export var move_speed: float = 45.0
@export var attack_cooldown: float = 0.8
@export var contact_damage: int = 1 

# Frequently accessed child nodes.
@onready var hurt_box: Area2D = $HurtBox
@onready var detection_radius: Area2D = $DetectionRadius
@onready var attack_range: Area2D = $AttackRange
@onready var reset_timer: Timer = $HitCountResetTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

const DAMAGE_NUMBER = preload("uid://bscrltn1af1bx")

# Runtime state used to control movement and combat.
var player: Node2D
var player_in_detection_range := false
#var player_in_attack_range := false
var hit_count = 0
var active_label = null

# Detection areas update these flags as the player enters or leaves each range.
# *** #
func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_detection_range = true
		print("Enemy detected player")

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_detection_range = false
		print("Player left detection range")

func _on_hurt_box_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage(contact_damage)
	elif body is Bullet:
		health_component.take_damage(1)
		body.queue_free()

		hit_count += 1
		update_hit_display()
		reset_timer.start()
#func _on_attack_body_entered(body: Node2D) -> void:
	#if body.is_in_group("player"):
		#player_in_attack_range = true
		#print("Player entered attack range")

#func _on_attack_body_exited(body: Node2D) -> void:
	#if body.is_in_group("player"):
		#player_in_attack_range = false
		#print("Player left attack range")

# Move toward the player only after detection and stop at attack range.
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if is_instance_valid(player) and player_in_detection_range:
		if player_in_attack_range:
			velocity = Vector2.ZERO
			if attack_timer.is_stopped():
				attack_player()
		else:
			var direction := global_position.direction_to(player.global_position)
			if direction.x != 0:
				sprite.flip_h = direction.x < 0
			velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func attack_player() -> void:
	var player_hurt_box := player.get_node_or_null("HurtBox") as Hurtbox

	if player_hurt_box == null:
		print("Enemy attack failed: Player HurtBox not found")
		return

	print("Enemy attacking player")
	player_hurt_box.take_damage(1)
	attack_timer.start()

# Cache node references and connect gameplay signals once the enemy enters the scene.
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	hurt_box.body_entered.connect(_on_hurt_box_body_entered)
	
	reset_timer.timeout.connect(reset_hit_counter)
	health_component.died.connect(_on_enemy_died)

	detection_radius.body_entered.connect(_on_detection_body_entered)
	detection_radius.body_exited.connect(_on_detection_body_exited)

	#attack_range.body_entered.connect(_on_attack_body_entered)
	#attack_range.body_exited.connect(_on_attack_body_exited)

	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true

func _on_enemy_died() -> void:
	queue_free()

# Display the accumulated damage count above the enemy.
func update_hit_display() -> void:
	if not is_instance_valid(active_label):
		active_label = DAMAGE_NUMBER.instantiate()
		get_tree().current_scene.add_child(active_label)

	var spawn_pos := global_position + Vector2(randf_range(-6, 6), -15)
	active_label.display(hit_count, spawn_pos)

# Clear the damage counter after the reset timer expires.
func reset_hit_counter() -> void:
	hit_count = 0
	active_label = null
