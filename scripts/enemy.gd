extends CharacterBody2D

@export var health = 10
@onready var area_2d = $Area2D
@onready var reset_timer = $CountTimer
const DAMAGE_NUMBER = preload("uid://bscrltn1af1bx")

var hit_count = 0
var active_label = null

func _ready():
	area_2d.connect("body_entered", decrease_life_points)
	reset_timer.timeout.connect(reset_hit_counter)

func decrease_life_points(body):
	if body is Bullet:
		health -= 1
		body.queue_free()
		
		hit_count += 1
		update_hit_display()
		
		reset_timer.start()
		
		if health <= 0:
			queue_free()

func update_hit_display():
	if not is_instance_valid(active_label):
		active_label = DAMAGE_NUMBER.instantiate()
		get_tree().current_scene.add_child(active_label)
	
	var spawn_pos = global_position + Vector2(randf_range(-6, 6), -15)
	active_label.display(hit_count, spawn_pos)

func reset_hit_counter():
	hit_count = 0
	active_label = null
