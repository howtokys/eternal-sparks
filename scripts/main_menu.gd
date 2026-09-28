extends Control

# Update paths to match your actual scene tree node names
@onready var start_button = $Start
@onready var continue_button = $Continue
@onready var settings_button = $Settings
@onready var exit_button = $Exit

# Prevents multiple presses while changing scenes
var is_processing_input: bool = false

func _ready() -> void:
	# Gives the first button focus so controller/keyboard navigation works immediately
	if start_button:
		start_button.grab_focus()

func _on_start_pressed() -> void:
	if is_processing_input: return
	is_processing_input = true
	
	GlobalData.is_loading_save = false # Fresh start
	print("Start pressed")
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_continue_pressed() -> void:
	if is_processing_input: return
	
	# Check if the file exists on the disk
	if FileAccess.file_exists(GlobalData.SAVE_PATH):
		var success = GlobalData.load_save_data()
		if success:
			is_processing_input = true
			GlobalData.is_loading_save = true
			print("Loading existing progress...")
			get_tree().change_scene_to_file("res://scenes/World.tscn")
		else:
			show_feedback_dialog("Save file is corrupted.")
	else:
		show_feedback_dialog("No save file found.")

func _on_settings_pressed() -> void:
	print("Settings pressed")

func _on_exit_pressed() -> void:
	if is_processing_input: return
	is_processing_input = true
	get_tree().quit()

# Spawns a small popup dialog if no save file exists without crashing
func show_feedback_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		if continue_button:
			continue_button.grab_focus()
		dialog.queue_free()
)
