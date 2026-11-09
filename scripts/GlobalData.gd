extends Node

const SAVE_PATH: String = "user://savegame.json"

const COIN = preload("uid://bemyluq07nctq")

var world: Node2D = null
var player: CharacterBody2D = null
var is_loading_save: bool = false

# Player data to save/load
var saved_position: Vector2 = Vector2.ZERO
var saved_health: int = 100
var money: int = 0

func add_money(amount: int) -> void:
	money = money + amount
	print("Money:", money)
	
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


func save_game() -> void:
	if player:
		saved_position = player.global_position
		

	var save_dict: Dictionary = {
		"pos_x": saved_position.x,
		"pos_y": saved_position.y,
		"health": saved_health
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()
		print("Game saved successfully.")


func load_save_data() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return false

	var data: Dictionary = json.get_data()
	saved_position = Vector2(data.get("pos_x", 0), data.get("pos_y", 0))
	saved_health = data.get("health", 100)
	return true
