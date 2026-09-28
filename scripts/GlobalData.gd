extends Node

const SAVE_PATH: String = "user://savegame.json"

# References assigned dynamically by the scenes themselves
var world: Node2D = null
var player: CharacterBody2D = null

# Flag telling the player script whether to restore data
var is_loading_save: bool = false

# Player data to save/load
var saved_position: Vector2 = Vector2.ZERO
var saved_health: int = 100


func save_game() -> void:
	if player:
		saved_position = player.global_position
		# If your player has a health variable:
		# saved_health = player.health

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
