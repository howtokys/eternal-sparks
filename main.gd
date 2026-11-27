extends Node2D

@export var start_room: PackedScene
@export var room_scenes: Array[PackedScene]
@export var corridor_right: PackedScene
@export var corridor_left: PackedScene
@export var corridor_up: PackedScene
@export var corridor_down: PackedScene
@export var gate_horizontal: PackedScene
@export var gate_vertical: PackedScene
@export var wall_horizontal: PackedScene
@export var wall_vertical: PackedScene
@export var enemy_scene: PackedScene
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
	
	spawn_from_room(start, true)
	for room in rooms:
		fill_unused_exits(room)
	setup_room_gates()
	
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
		corridor.z_index = parent_room.z_index - 1
	
	var c_start = corridor.get_node_or_null("Start")
	var c_end = corridor.get_node_or_null("End")
	if c_start == null or c_end == null:
		push_error("Corridor missing Start or End")
		corridor.queue_free()
		return null
	
	# 2. Align corridor Start marker to the exit
	corridor.global_position += exit.global_position - c_start.global_position
	
	# 3. Try a few unused room scenes for this exit
	var available_scenes: Array[PackedScene] = []
	for scene in room_scenes:
		if not used_room_scenes.has(scene):
			available_scenes.append(scene)
	
	if available_scenes.is_empty():
		print("ERROR: No unused room scenes left")
		corridor.queue_free()
		return null
	
	available_scenes.shuffle()
	var max_attempts = mini(3, available_scenes.size())
	var new_room: Node2D = null
	var room_exit: Node2D = null
	
	for attempt in max_attempts:
		var scene = available_scenes[attempt]
		var candidate = scene.instantiate()
		add_child(candidate)
		
		var opposite_name = get_opposite_exit_name(exit.name)
		var candidate_exit = candidate.get_node_or_null(opposite_name)
		
		if candidate_exit == null:
			candidate.queue_free()
			continue
		
		# Align candidate to corridor end
		candidate.global_position += c_end.global_position - candidate_exit.global_position
		
		var room_rect = get_bounds_rect(candidate)
		print(candidate.name, " bounds: ", get_bounds_rect(candidate))
		
		if overlaps_existing(room_rect):
			print("Attempt ", attempt + 1, " overlapped, trying next room")
			candidate.queue_free()
			continue
		
		# Success
		new_room = candidate
		room_exit = candidate_exit
		used_room_scenes.append(scene)
		break
	
	if new_room == null:
		print("All attempts failed for ", exit.name)
		corridor.queue_free()
		return null
	
	# Mark exits as used only on success
	used_exits[exit] = true
	used_exits[room_exit] = true
	rooms.append(new_room)
	rooms_left -= 1
	
	if exit.name == "ExitNorth":
		var base_z = parent_room.z_index - 1
		corridor.z_index = base_z
		var wall = corridor.get_node("Floor/Wall")
		wall.z_index = base_z
		var first = corridor.get_node("Floor/Wall/FinalWallFirstHalf")
		first.z_index = new_room.z_index + 1
		var second = corridor.get_node("Floor/Wall/FinalWallFirstHalf/FinalWallSecondHalf")
		second.z_index = new_room.z_index + 1
	
	# Spawn gates
	spawn_gate_on_exit(parent_room, exit)
	spawn_gate_on_exit(new_room, room_exit)
	spawn_enemies_in_room(new_room)
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
	
	var bottom_half = gate.get_node_or_null("BottomHalf")
	if bottom_half:
		bottom_half.z_index = room.z_index - 1

	if is_vertical:
		gate.z_index = room.z_index
	
	print("Gate placed on ", exit.name)

func fill_unused_exits(room: Node2D) -> void:
	for exit in get_free_exits(room):
		var wall_scene: PackedScene
		var marker_name: String
		
		match exit.name:
			"ExitNorth":
				wall_scene = wall_horizontal
				marker_name = "Top"   
			"ExitSouth":
				wall_scene = wall_horizontal
				marker_name = "Bottom"      # Top of wall aligns to ExitSouth
			"ExitWest":
				wall_scene = wall_vertical
				marker_name = "Left"     # Left of wall aligns to ExitWest
			"ExitEast":
				wall_scene = wall_vertical
				marker_name = "Right"    # Right of wall aligns to ExitEast
			_:
				continue
		
		if wall_scene == null:
			continue
		
		var wall = wall_scene.instantiate()
		room.add_child(wall)
		
		var marker = wall.get_node_or_null(marker_name)
		if marker == null:
			wall.queue_free()
			continue
		
		wall.global_position += exit.global_position - marker.global_position
		# Vertical wall z-index
		if exit.name == "ExitWest" or exit.name == "ExitEast":
			wall.z_as_relative = false
			wall.z_index = room.z_index + 1
			
			var bottom_half = wall.get_node_or_null("Wall/TopHalf/BottomHalf")
			if bottom_half:
				bottom_half.z_as_relative = false
				bottom_half.z_index = room.z_index
		print("Wall placed on ", room.name, " / ", exit.name)
	

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

func setup_room_gates() -> void:
	print("=== SETUP ROOM GATES ===")
	for room in rooms:
		print("Checking room: ", room.name)
		var area = room.get_node_or_null("Area2D")
		if area == null:
			print("  No Area2D")
			continue
		
		var gates: Array = []
		var enemies: Array = []
		for child in room.get_children():
			if child.is_in_group("gate"):
				gates.append(child)
				print("  Found gate: ", child.name)
			elif child.is_in_group("enemy"):
				enemies.append(child)
				print("  Found enemy: ", child.name)
		
		print("  Gates: ", gates.size(), " | Enemies: ", enemies.size())
		
		# Start every gate open
		for gate in gates:
			if gate.has_method("set_closed"):
				gate.set_closed(false)
		
		if enemies.is_empty():
			print("  Skipping (no enemies)")
			continue
		
		var state = {
			"player_inside": false,
			"enemies": enemies,
			"gates": gates
		}
		
		area.body_entered.connect(func(body):
			print("Body entered: ", body.name, " groups: ", body.get_groups())
			if body.is_in_group("player"):
				print("  -> Player entered room")
				state.player_inside = true
				_update_room_gates(state)
		)
		area.body_exited.connect(func(body):
			if body.is_in_group("player"):
				print("  -> Player left room")
				state.player_inside = false
				_update_room_gates(state)
		)
		
		for enemy in enemies:
			var hc = enemy.get_node_or_null("HealthComponent")
			if hc and hc.has_signal("died"):
				hc.died.connect(func():
					state.enemies.erase(enemy)
					print("Enemy died. Remaining: ", state.enemies.size())
					_update_room_gates(state)
				)

func _update_room_gates(state: Dictionary) -> void:
	var should_close = state.player_inside and state.enemies.size() > 0
	print("Updating gates. player_inside=", state.player_inside, " enemies=", state.enemies.size(), " -> close=", should_close)
	for gate in state.gates:
		if is_instance_valid(gate) and gate.has_method("set_closed"):
			gate.set_closed(should_close)
		else:
			print("  Gate invalid or missing set_closed: ", gate)


func spawn_enemies_in_room(room: Node2D) -> void:
	var spawn_spot = room.get_node_or_null("SpawnSpot")
	if spawn_spot == null:
		return
	
	var markers = spawn_spot.get_children()
	if markers.is_empty():
		return
	
	markers.shuffle()
	var count = randi_range(2, mini(8, markers.size()))
	
	for i in count:
		var enemy = enemy_scene.instantiate()
		room.add_child(enemy)
		enemy.global_position = markers[i].global_position
