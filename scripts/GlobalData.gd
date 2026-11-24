extends Node

signal enemy_defeated
signal money_changed(new_balance: int)

const SAVE_PATH: String = "user://savegame.json"

const COIN = preload("uid://bemyluq07nctq")
const MANA_PARTICLE = preload("uid://ckrk4ayyc15ff")

var world: Node2D = null
var player: CharacterBody2D = null
var is_loading_save: bool = false

# Player data to save/load
var saved_position: Vector2 = Vector2.ZERO
var has_saved_position: bool = false
var return_room_path := ""
var return_spawn_id := ""
var saved_scene_path: String = ""
var starting_buff_chosen: bool = false
var run_player_state: Dictionary = {}
var clear_rewards: Dictionary = {}
var defeated_enemies: Dictionary = {}
var sold_shop_stock: Dictionary = {}
var save_path: String = SAVE_PATH
var run_finished: bool = false
var save_pending: bool = false
var money: int = 0

func finish_run() -> void:
	if run_finished:
		return
	run_finished = true
	is_loading_save = false
	get_tree().paused = true
	if FileAccess.file_exists(save_path):
		var error := DirAccess.remove_absolute(save_path)
		if error != OK:
			# An existing writable checkpoint may still be marked ended if removal fails.
			var file := FileAccess.open(save_path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify({"finished": true}))
				file.close()
			else:
				push_error("Could not retire the finished run checkpoint: %s" % error_string(error))
	get_tree().change_scene_to_file.call_deferred("res://scenes/game_over.tscn")


func start_new_run() -> void:
	run_finished = false
	# The outgoing player must not repopulate the cleared run as it leaves the tree.
	player = null
	is_loading_save = false
	saved_position = Vector2.ZERO
	has_saved_position = false
	saved_scene_path = ""
	return_room_path = ""
	return_spawn_id = ""
	starting_buff_chosen = false
	run_player_state.clear()
	sold_shop_stock.clear()
	clear_rewards.clear()
	defeated_enemies.clear()
	money = 0
	money_changed.emit(money)


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)
	request_save()


func try_spend_money(amount: int) -> bool:
	if amount <= 0 or amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	request_save()
	return true
	
func enemy_was_defeated(room_path: String, spawn_path: String) -> bool:
	# Older checkpoints only recorded the reward after the last enemy died.
	if clear_rewards.get(room_path) in ["pending", "claimed"]:
		return true
	var defeats: Variant = defeated_enemies.get(room_path)
	return defeats is Dictionary and defeats.get(spawn_path) == true


func record_enemy_defeat(room_path: String, spawn_path: String) -> void:
	var defeats: Variant = defeated_enemies.get(room_path)
	if not defeats is Dictionary:
		defeats = {}
		defeated_enemies[room_path] = defeats
	defeats[spawn_path] = true
	request_save()


func is_shop_stock_sold(stock_id: StringName) -> bool:
	return not stock_id.is_empty() and sold_shop_stock.get(String(stock_id), false) == true


func mark_shop_stock_sold(stock_id: StringName) -> void:
	if not stock_id.is_empty():
		sold_shop_stock[String(stock_id)] = true
		request_save()


func drop_money(pos: Vector2, chance: float) -> void:
	if randf() > chance:
		return
		
	var roll = randf()
	var count: int
	if roll < 0.60: # 60%
		count = 1
	elif roll < 0.85: # 25%
		count = 2
	elif roll < 0.95: # 10%
		count = 3
	elif roll < 0.99: # 4%
		count = 4
	else: 
		count = 5 # 1%
		
	for i in count:
		var drop = COIN.instantiate()
		
		var type_roll = randf()
		if type_roll < 0.6:
			drop.coin_type = 0
		elif type_roll < 0.9:
			drop.coin_type = 1
		else:
			drop.coin_type = 2
		
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		drop.global_position = pos + offset
		drop.visible = false
		get_tree().current_scene.add_child.call_deferred(drop)
		drop.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		drop.reset_physics_interpolation()
		drop.visible = true

func drop_mana(pos: Vector2, chance: float) -> void:
	if randf() > chance:
		return

	# Same weighted chances as coins
	var roll = randf()
	var count: int
	if roll < 0.60:
		count = 1
	elif roll < 0.85:
		count = 2
	elif roll < 0.95:
		count = 3
	elif roll < 0.99:
		count = 4
	else:
		count = 5

	for i in count:
		var drop = MANA_PARTICLE.instantiate()
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		drop.global_position = pos + offset
		drop.visible = false
		get_tree().current_scene.add_child.call_deferred(drop)
		drop.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		drop.reset_physics_interpolation()
		drop.visible = true

func request_save() -> void:
	if run_finished or save_pending:
		return
	# Coalesce a coin deduction and its synchronous shop effect into one checkpoint.
	save_pending = true
	save_game.call_deferred()


func save_game() -> void:
	save_pending = false
	if run_finished or not is_instance_valid(player) or player.is_queued_for_deletion():
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty() or scene.is_in_group("practice_room"):
		return

	saved_position = player.global_position
	has_saved_position = true
	saved_scene_path = scene.scene_file_path
	run_player_state = player.capture_run_state()
	var data := run_player_state.duplicate()
	data.merge({
		"pos_x": saved_position.x,
		"pos_y": saved_position.y,
		"scene": saved_scene_path,
		"return_room_path": return_room_path,
		"return_spawn_id": return_spawn_id,
		"money": money,
		"starting_buff_chosen": starting_buff_chosen,
		"sold_shop_stock": sold_shop_stock,
		"clear_rewards": clear_rewards,
		"defeated_enemies": defeated_enemies,
	})

	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open run checkpoint: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_warning("Could not write run checkpoint: %s" % error_string(write_error))
		return
	var rename_error := DirAccess.rename_absolute(temporary_path, save_path)
	if rename_error != OK:
		push_warning("Could not replace run checkpoint: %s" % error_string(rename_error))


func load_save_data() -> bool:
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false

	var data: Dictionary = parsed
	if run_finished or data.get("finished") == true or read_number(data, "health", 1) <= 0:
		return false
	var position := Vector2(read_number(data, "pos_x", NAN), read_number(data, "pos_y", NAN))
	has_saved_position = position.is_finite()
	saved_position = position if has_saved_position else Vector2.ZERO
	var origin: Variant = data.get("return_room_path")
	var spawn: Variant = data.get("return_spawn_id")
	return_room_path = origin if origin is String else ""
	return_spawn_id = spawn if spawn is String else ""
	var scene_path: Variant = data.get("scene")
	saved_scene_path = scene_path if scene_path is String else ""
	starting_buff_chosen = data.get("starting_buff_chosen", false) == true
	run_player_state = data
	var clears: Variant = data.get("clear_rewards")
	clear_rewards = clears if clears is Dictionary else {}
	var defeats: Variant = data.get("defeated_enemies")
	defeated_enemies = defeats if defeats is Dictionary else {}
	var stock: Variant = data.get("sold_shop_stock")
	sold_shop_stock = stock if stock is Dictionary else {}
	money = maxi(0, int(read_number(data, "money", 0)))
	money_changed.emit(money)
	return true


func read_number(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key)
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback
