extends Node2D

@export var start_room: PackedScene
@export var room_scenes: Array[PackedScene]
@export var corridor_right: PackedScene
@export var corridor_left: PackedScene
@export var corridor_up: PackedScene
@export var corridor_down: PackedScene
@export var gate_horizontal: PackedScene
@export var gate_vertical: PackedScene
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
	var corridor_scene: PackedScene
	match exit.name:
		"ExitEast":
			corridor_scene = corridor_right
		"ExitWest":
			corridor_scene = corridor_left
		"ExitSouth":
			corridor_scene = corridor_down
		"ExitNorth":
			corridor_scene = corridor_up
		_:
			print("Unknown exit name: ", exit.name)
			return null

	if corridor_scene == null:
		push_error("Missing corridor scene for ", exit.name)
		return null

	var corridor = corridor_scene.instantiate()
	add_child(corridor)
	
	if exit.name == "ExitNorth":
		print("=== Corridor tree ===")
		corridor.print_tree_pretty()
		corridor.z_index = parent_room.z_index - 1
			
	var c_start = corridor.get_node_or_null("Start")
	var c_end = corridor.get_node_or_null("End")
	if c_start == null or c_end == null:
		push_error("Corridor missing Start or End")
		corridor.queue_free()
		return null

	print("Using corridor for ", exit.name)

	# 2. Align corridor Start marker to the exit (no rotation needed)
	corridor.global_position += exit.global_position - c_start.global_position
	print("Corridor Start aligned to ", exit.name)

	used_exits[exit] = true
	
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
	
	if exit.name == "ExitNorth":
		var base_z = parent_room.z_index - 1
		corridor.z_index = base_z		
		var wall = corridor.get_node("Floor/Wall")
		wall.z_index = base_z
		
		var first = corridor.get_node("Floor/Wall/FinalWallFirstHalf")
		first.z_index = new_room.z_index + 1
		var second = corridor.get_node("Floor/Wall/FinalWallFirstHalf/FinalWallSecondHalf")
		second.z_index = new_room.z_index + 1
		print("FinalWallSecondHalf z: ", second.z_index, " | New room z: ", new_room.z_index)
			
	# Check overlap with existing rooms
	print("New room rect: ", get_room_rect(new_room))
	print("Start room rect: ", get_room_rect(rooms[0]))
	
	var room_rect = get_bounds_rect(new_room)
	var corridor_rect = get_bounds_rect(corridor)

	if overlaps_existing(room_rect) or overlaps_existing(corridor_rect):
		print("Overlap detected, rejecting")
		new_room.queue_free()
		corridor.queue_free()
		return null
	

	used_exits[room_exit] = true
	rooms.append(new_room)
	rooms_left -= 1
	
	# Spawn gates on both exits that now have a corridor
	spawn_gate_on_exit(parent_room, exit)
	spawn_gate_on_exit(new_room, room_exit)
	
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
	

func get_room_rect(room: Node2D) -> Rect2:
	var shape = room.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D:
		var size = (shape.shape as RectangleShape2D).size
		var pos = room.global_position + shape.position - size / 2
		return Rect2(pos, size)
	# Fallback if no collision shape
	return Rect2(room.global_position - Vector2(64, 64), Vector2(128, 128))

func spawn_gate_on_exit(room: Node2D, exit: Node2D) -> void:
	print("Trying gate on ", room.name, " / ", exit.name)
	
	var gate_scene_to_use: PackedScene
	var marker_name: String
	var is_vertical := false
	
	match exit.name:
		"ExitNorth":
			gate_scene_to_use = gate_horizontal
			marker_name = "Top"
		"ExitSouth":
			gate_scene_to_use = gate_horizontal
			marker_name = "Bottom"
		"ExitWest":
			gate_scene_to_use = gate_vertical
			marker_name = "Left"
			is_vertical = true
		"ExitEast":
			gate_scene_to_use = gate_vertical
			marker_name = "Right"
			is_vertical = true
		_:
			return
	
	if gate_scene_to_use == null:
		print("Missing gate scene for ", exit.name)
		return
	
	var gate = gate_scene_to_use.instantiate()
	room.add_child(gate)
	
	var marker = gate.get_node_or_null(marker_name)
	if marker == null:
		print("Missing marker: ", marker_name)
		gate.queue_free()
		return
	
	gate.global_position += exit.global_position - marker.global_position
	
	# Play close animation
	var anim = gate.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim and anim.sprite_frames.has_animation("close"):
		anim.play("close")
	
	# Vertical gate sits one below the previous room
	if is_vertical:
		gate.z_index = room.z_index + 1
	
	print("Gate placed on ", exit.name)

func get_bounds_rect(node: Node2D) -> Rect2:
	var shape_node = node.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var size = (shape_node.shape as RectangleShape2D).size
		var pos = node.global_position + shape_node.global_position - node.global_position - size / 2
		# More reliable: use the shape's global transform
		var global_pos = shape_node.global_position - size / 2
		return Rect2(global_pos, size)
	# Fallback
	return Rect2(node.global_position - Vector2(64, 64), Vector2(128, 128))

func overlaps_existing(rect: Rect2) -> bool:
	rect = rect.grow(-4)
	for existing in rooms:
		var existing_rect = get_bounds_rect(existing).grow(-4)
		if rect.intersects(existing_rect):
			return true
	# Also check previously placed corridors if you store them
	return false
