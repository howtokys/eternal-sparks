extends Node2D

@export var start_room: PackedScene
@export var room_scenes: Array[PackedScene]
@export var corridor_scene: PackedScene
@export var room_count: int = 5

var rooms: Array[Node2D] = []
var used_exits: Dictionary = {}
var rooms_left: int
var used_room_scenes: Array[PackedScene] = []

func _ready() -> void:
	generate()

func generate() -> void:
	rooms_left = room_count
	
	var start = start_room.instantiate()
	add_child(start)
	start.global_position = Vector2.ZERO
	rooms.append(start)
	print("=== START ROOM SPAWNED ===")
	
	spawn_from_room(start, true)
	
func spawn_from_room(room: Node2D, is_start: bool = false) -> void:
	if rooms_left <= 0:
		return
	
	var free_exits = get_free_exits(room)
	print("Room ", room.name, " has ", free_exits.size(), " free exits")
	if free_exits.is_empty():
		return
	
	var max_to_use = 1 if is_start else mini(mini(3, free_exits.size()), rooms_left)
	var to_use = randi_range(1, max_to_use)
	free_exits.shuffle()
	
	var new_rooms: Array[Node2D] = []
	
	for i in to_use:
		if rooms_left <= 0:
			break
		var new_room = spawn_corridor_and_room(room, free_exits[i])
		if new_room:
			new_rooms.append(new_room)
	
	for new_room in new_rooms:
		spawn_from_room(new_room, false)

func spawn_corridor_and_room(parent_room: Node2D, exit: Node2D) -> Node2D:
	if rooms_left <= 0:
		return null
	
	print("\n--- Connecting from ", parent_room.name, " exit: ", exit.name, " ---")
	
	# 1. Spawn corridor
	var corridor = corridor_scene.instantiate()
	add_child(corridor)
	
	var c_start = corridor.get_node_or_null("Start")
	var c_end = corridor.get_node_or_null("End")
	if c_start == null or c_end == null:
		push_error("Corridor missing Start or End")
		corridor.queue_free()
		return null
	
	# 2. Rotate corridor based on which exit we're connecting from
	match exit.name:
		"ExitEast":
			corridor.rotation = 0
		"ExitWest":
			corridor.rotation = PI
		"ExitSouth":
			corridor.rotation = PI / 2
		"ExitNorth":
			corridor.rotation = -PI / 2
		_:
			print("Unknown exit name: ", exit.name)
			corridor.queue_free()
			return null
	
	print("Corridor rotated for ", exit.name)
	
	# 3. Align corridor Start marker to the exit
	corridor.global_position += exit.global_position - c_start.global_position
	print("Corridor Start aligned to ", exit.name)
	
	used_exits[exit] = true
	
	# 4. Pick an unused room scene
	var available_scenes: Array[PackedScene] = []
	for scene in room_scenes:
		if not used_room_scenes.has(scene):
			available_scenes.append(scene)
	
	if available_scenes.is_empty():
		print("ERROR: No unused room scenes left")
		corridor.queue_free()
		return null
	
	var scene = available_scenes[randi() % available_scenes.size()]
	used_room_scenes.append(scene)
	
	var new_room = scene.instantiate()
	add_child(new_room)
	
	# 5. Find the opposite exit on the new room
	var opposite_name = get_opposite_exit_name(exit.name)
	var room_exit = new_room.get_node_or_null(opposite_name)
	
	if room_exit == null or used_exits.has(room_exit):
		print("ERROR: New room missing free ", opposite_name)
		new_room.queue_free()
		return null
	
	print("Aligning to ", opposite_name, " on new room")
	
	# 6. Align the opposite exit to the corridor's End marker
	new_room.global_position += c_end.global_position - room_exit.global_position
	print("Room ", opposite_name, " aligned to corridor End")
	
	used_exits[room_exit] = true
	rooms.append(new_room)
	rooms_left -= 1
	
	print("=== ROOM PLACED ===")
	
	return new_room

func get_opposite_exit_name(exit_name: String) -> String:
	match exit_name:
		"ExitNorth": return "ExitSouth"
		"ExitSouth": return "ExitNorth"
		"ExitEast": return "ExitWest"
		"ExitWest": return "ExitEast"
		_: return ""

func get_free_exits(room: Node2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in room.get_children():
		if child.name.begins_with("Exit") and not used_exits.has(child):
			result.append(child)
	return result
