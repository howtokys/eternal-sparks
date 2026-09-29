extends Control


const BGM = preload("res://vsauce.mp3")


@onready var start_button = $Start
@onready var continue_button = $Continue
@onready var settings_button = $Settings
@onready var exit_button = $Exit

# Prevents multiple presses while changing scenes
var is_processing_input: bool = false

func _ready() -> void:
	
	#start continous background music through autoload
	Audio.play_music(BGM)
	# Keep the root MainMenu visible, but ensure settings starts hidden
	visible = true
	$SettingsMenu.visible = false
	$VBoxContainer.visible = true
	
	# Gives the first button focus
	$VBoxContainer/Button.grab_focus()

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
	# DO NOT set visible = false here! That hides the entire screen.
	$VBoxContainer.visible = false
	$SettingsMenu.visible = true
	
	# Focus the back button inside settings for keyboard/controller support
	$SettingsMenu/VBoxContainer/Button.grab_focus()

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


func _on_back_pressed() -> void:
	print("Back pressed")
	# Hide settings and bring back the main menu buttons
	$SettingsMenu.visible = false
	$VBoxContainer.visible = true
	
	# Return focus to the Settings button
	$VBoxContainer/Button3.grab_focus()
	


func _on_option_button_item_selected(index: int) -> void:
	var win = get_window()
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# 2. Explicitly apply your target window dimensions
			var target_size = Vector2i(800, 450)
			win.size = target_size
			
			# 3. Center the window on the display
			win.move_to_center()


func _on_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0,toggled_on)
	


func _on_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(value))
	
