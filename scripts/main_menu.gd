extends Control


const BGM = preload("res://dungeon_menu_loop.wav")


@onready var start_button = $VBoxContainer/Button
@onready var continue_button = $VBoxContainer/Button2
@onready var settings_button = $VBoxContainer/Button3
@onready var exit_button = $VBoxContainer/Button4
@onready var HoverSound : AudioStreamPlayer = $HoeverSound
@onready var ClickSound : AudioStreamPlayer = $ClickSound

# Prevents multiple presses while changing scenes
var is_processing_input: bool = false

func _ready() -> void:
	
	#start continous background music through autoload
	Audio.play_music(BGM)
	# Keep the root MainMenu visible, but ensure settings starts hidden
	visible = true
	$SettingsMenu.visible = false
	$VBoxContainer.visible = true
	$TitleFrame.visible = true  #show title on main menu 
	
	# Gives the first button focus
	$VBoxContainer/Button.call_deferred("grab_focus")
	
#for the debugging of keyboard navigation 
	get_tree().process_frame.connect(func():
		print("Focused node: ", get_viewport().gui_get_focus_owner())
	, CONNECT_ONE_SHOT)

#for debugging the keyboard navigation 
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		print("Key pressed: ", OS.get_keycode_string(event.keycode))
		print("Is ui_down action? ", event.is_action("ui_down"))
		print("Current focus owner: ", get_viewport().gui_get_focus_owner())

func _on_start_pressed() -> void:
	if is_processing_input: return
	is_processing_input = true
	
	play_click_sound()
	await ClickSound.finished  #audio for when clicked
	
	GlobalData.is_loading_save = false # Fresh start
	print("Start pressed")
	get_tree().change_scene_to_file("res://scenes/First_Room.tscn")

func _on_continue_pressed() -> void:
	if is_processing_input: return
	
	play_click_sound()
	
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
	play_click_sound()
	# DO NOT set visible = false here! That hides the entire screen.
	$VBoxContainer.visible = false
	$TitleFrame.visible = false #hide ternal sparks title
	$SettingsMenu.visible = true
	
	# Focus the back button inside settings for keyboard/controller support
	$SettingsMenu/VBoxContainer/Button.grab_focus()

func _on_exit_pressed() -> void:
	
	play_click_sound()
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
	play_click_sound()
	# Hide settings and bring back the main menu buttons
	$SettingsMenu.visible = false
	$VBoxContainer.visible = true
	$TitleFrame.visible = true #restore eternal sparks title 
	
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


#func _on_mute_toggled(toggled_on: bool) -> void:
	#AudioServer.set_bus_mute(0,toggled_on)
	#
func play_hover_sound () -> void:
	HoverSound.play()
	
func play_click_sound () -> void:
	ClickSound.play()	
	
func _on_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(value))
	
