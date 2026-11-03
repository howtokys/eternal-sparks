# Run: GODOT_MCP_RUNTIME=off XDG_DATA_HOME=/tmp/eternal-sparks-tests godot --headless --path . --script res://tests/dungeon_progression.gd -- Third
# Use -- chain after all rooms exist to exercise real portal transitions.
extends SceneTree

const ROOM_NAMES := ["Second", "Third", "Fourth", "Fifth"]
const ENEMY_COUNTS := [3, 4, 5, 6]
const BUFF_PATHS := ["res://scripts/Buffs/speed_buff.tres", "res://scripts/Buffs/shield.tres", "res://scripts/Buffs/mana_regen_buff.tres"]
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func enemies_in(room: Node) -> Array[Node]:
	var enemies: Array[Node] = []
	for child in room.get_node("Floor").get_children():
		if child is CharacterBody2D and child.has_node("HealthComponent"):
			enemies.append(child)
	return enemies

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func run_tests() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("chain"):
		await test_chain()
	else:
		var name: String = args[0] if not args.is_empty() else "Third"
		await test_room(name)
	# Release menu music before shutting down the headless audio server.
	var audio := root.get_node("Audio")
	audio.stop()
	audio.stream = null
	await process_frame
	print("Dungeon tests finished; failures=", failures)
	quit(1 if failures else 0)

func test_room(name: String) -> void:
	var index := ROOM_NAMES.find(name)
	check(index >= 0, "Known room")
	if index < 0:
		return
	var global := root.get_node("GlobalData")
	for path in BUFF_PATHS:
		var buff: BuffData = load(path)
		for previous_level in [2, 3]:
			global.room_buff_snapshot.assign([{"resource": buff, "level": previous_level}])
			var room: Node2D = load("res://scenes/" + name + "_Room.tscn").instantiate()
			root.add_child(room)
			current_scene = room
			var enemies := enemies_in(room)
			for enemy in enemies:
				enemy.set_physics_process(false)
			await settle()
			var manager: BuffManager = room.get_node("Player/BuffManager")
			var expected_level := mini(previous_level + (1 if index <= 1 else 0), buff.max_level)
			check(manager.get_buff_level(buff.buff_id) == expected_level, name + " restores/upgrades buff " + str(buff.buff_id))
			check(global.room_buff_snapshot.is_empty(), "Snapshot consumed")
			check(enemies.size() == ENEMY_COUNTS[index], name + " enemy count")
			check(room.has_node("CanvasLayer/PauseScene"), "Pause menu preserved")
			check(room.has_node("CanvasLayer/StatBars"), "HUD preserved")
			check(room.has_node("Player/Gun"), "Weapon preserved")
			check(not room.has_node("CanvasLayer/BuffSelection"), "No repeated buff selection")
			check(not paused, "Gameplay is unpaused")
			check(not room.get_node("Portal").visible and not room.get_node("LevelExit").monitoring, "Portal locked")
			# Entry callback must reject the player before clearing.
			room._on_level_exit_body_entered(room.get_node("Player"))
			check(not room.transitioning, "Cannot skip encounter")
			if path == BUFF_PATHS[0] and previous_level == 2:
				await test_paths(room, enemies)
				var pause_menu := room.get_node("CanvasLayer/PauseScene")
				pause_menu.pause()
				check(paused and pause_menu.visible, "Pause works")
				pause_menu.resume()
				check(not paused and not pause_menu.visible, "Resume works")
			for i in enemies.size():
				enemies[i].get_node("HealthComponent").take_damage(100)
				if i < enemies.size() - 1:
					check(not room.get_node("Portal").visible, "Portal remains locked before final death")
			await settle()
			check(room.enemies_remaining == 0, "All enemies defeated")
			check(room.get_node("Portal").visible and room.get_node("Portal").is_playing(), "Unlocked portal animates")
			check(room.get_node("LevelExit").monitoring, "Exit activates")
			print("PASS ", name, " ", buff.buff_id, " ", previous_level, " -> ", manager.get_buff_level(buff.buff_id))
			room.queue_free()
			await process_frame

func test_paths(room: Node2D, enemies: Array[Node]) -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = room.get_node("Player/CollisionShape2D").shape
	query.collision_mask = 2
	var excluded: Array[RID] = []
	for enemy in enemies:
		excluded.append(enemy.get_rid())
	query.exclude = excluded
	var space := room.get_world_2d().direct_space_state
	var reachable := {}
	var spawn: Vector2 = room.get_node("Player").position
	var pending: Array[Vector2i] = [Vector2i(spawn / 4)]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if reachable.has(cell) or cell.x < 5 or cell.x > 96 or cell.y < 6 or cell.y > 55:
			continue
		query.transform = Transform2D(0, Vector2(cell * 4) + Vector2(5.0625, 9.5))
		if not space.intersect_shape(query, 1).is_empty():
			continue
		reachable[cell] = true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(cell + direction)
	for enemy in enemies:
		check(reachable.has(Vector2i(enemy.position / 4)), "Player can reach " + str(enemy.name))
		query.shape = enemy.get_node("BodyCollisionShape").shape
		query.transform = Transform2D(0, enemy.position + enemy.get_node("BodyCollisionShape").position)
		check(space.intersect_shape(query, 1).is_empty(), "Enemy spawns clear of static collisions")
	check(reachable.has(Vector2i(room.get_node("LevelExit").position / 4)), "Exit reachable with obstacles intact")
	print("PASS ", room.name, " physics reachability; cells=", reachable.size())

func test_chain() -> void:
	var global := root.get_node("GlobalData")
	for path in BUFF_PATHS:
		var buff: BuffData = load(path)
		global.room_buff_snapshot.clear()
		change_scene_to_file("res://scenes/First_Room.tscn")
		await scene_changed
		await settle()
		check(paused, "First Room pauses for starting selection")
		await current_scene.get_node("CanvasLayer/BuffSelection").select_buff(buff)
		await settle()
		var chain_names := ["First"] + ROOM_NAMES
		for index in chain_names.size():
			var room := current_scene
			check(room.scene_file_path == "res://scenes/" + chain_names[index] + "_Room.tscn", "Correct room in chain")
			var manager: BuffManager = room.get_node("Player/BuffManager")
			check(manager.get_buff_level(buff.buff_id) == mini(index + 1, 3), "Buff retained across actual scene change")
			for enemy in enemies_in(room):
				enemy.get_node("HealthComponent").take_damage(100)
			await settle()
			# Enter the Area2D physically, exercising its saved signal connection.
			room.get_node("Player").global_position = room.get_node("LevelExit").get_child(0).global_position - Vector2(5, 9)
			await scene_changed
			await settle()
			print("PASS portal transition from ", chain_names[index])
		check(current_scene.scene_file_path == "res://scenes/DungeonComplete.tscn", "Final portal opens completion screen")
		check(current_scene.get_node("Center/Panel/Margin/Content/BuffSummary").text.contains(buff.buff_name), "Completion shows carried buff")
		current_scene.get_node("Center/Panel/Margin/Content/Menu").pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path == "res://scenes/Main-Menu.tscn", "Completion returns to menu")
		check(global.room_buff_snapshot.is_empty(), "Completed run snapshot cleared")
		current_scene.queue_free()
		await process_frame
