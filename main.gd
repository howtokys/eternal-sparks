extends Node2D

@export var start_room: PackedScene
@export var room_scenes: Array[PackedScene]
@export var corridor_scene: PackedScene
@export var room_count: int = 5
@export var room_spacing: float = 1000.0

var rooms: Array[Node2D] = []
var used_exits: Dictionary = {}

const DIRECTIONS = [
	Vector2.RIGHT,
	Vector2.LEFT,
	Vector2.UP,
	Vector2.DOWN
]

func _ready() -> void:
	generate()

func generate() -> void:
	var start = start_room.instantiate()
	add_child(start)
	start.global_position = Vector2.ZERO
	rooms.append(start)
	print("Start room placed")
	
	for i in room_count:
		var scene = room_scenes[randi() % room_scenes.size()]
		var room = scene.instantiate()
		add_child(room)
		
		var placed = false
		for attempt in 40:
			var parent = rooms[randi() % rooms.size()]
			var dir = DIRECTIONS[randi() % DIRECTIONS.size()]
			
			var exit_a = get_any_free_exit(parent)
			if exit_a == null:
				continue
			
			room.global_position = parent.global_position + dir * room_spacing
			rooms.append(room)
			
			if connect_rooms(parent, room, exit_a, dir):
				placed = true
				break
		
		if not placed:
			print("Could not place room ", i)
			room.queue_free()

func connect_rooms(a: Node2D, b: Node2D, exit_a: Node2D, dir: Vector2) -> bool:
	var exit_b = get_any_free_exit(b)
	if exit_b == null:
		print("No free exit on ", b.name)
		return false
	
	used_exits[exit_a] = true
	used_exits[exit_b] = true
	
	if corridor_scene == null:
		print("ERROR: corridor_scene is not assigned")
		return false
	
	var corridor = corridor_scene.instantiate()
	add_child(corridor)
	
	var mid = (exit_a.global_position + exit_b.global_position) / 2.0
	corridor.global_position = mid
	
	# Cardinal rotation only
	if abs(dir.x) > abs(dir.y):
		corridor.rotation = 0 if dir.x > 0 else PI
	else:
		corridor.rotation = PI / 2 if dir.y > 0 else -PI / 2
	
	print("Connected ", a.name, " → ", b.name, " | corridor at ", mid)
	return true

func get_any_free_exit(room: Node2D) -> Node2D:
	for child in room.get_children():
		if child.name.begins_with("Exit") and not used_exits.has(child):
			return child
	return null
