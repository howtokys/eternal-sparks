extends Control


const BGM = preload("res://dungeon_menu_loop.wav")
const START_ROOM := "res://scenes/First_Room.tscn"
const LEGACY_SAVE_ROOM := "res://scenes/World.tscn"


@onready var start_button = $VBoxContainer/Button
@onready var settings_button = $VBoxContainer/Button2
@onready var continue_button = $VBoxContainer/Button3
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
	
	for button: Button in [start_button, continue_button, settings_button, exit_button]:
		button.focus_mode = Control.FOCUS_ALL
	start_button.grab_focus.call_deferred()

func _on_start_pressed() -> void:
	if is_processing_input: return
	is_processing_input = true
	
	play_click_sound()
	await ClickSound.finished  #audio for when clicked
	
	GlobalData.start_new_run()
	_enter_room(START_ROOM)

func _on_continue_pressed() -> void:
	if is_processing_input: return
	
	play_click_sound()
	
	if not FileAccess.file_exists(GlobalData.save_path):
		show_feedback_dialog("No save file found.")
		return
	if not GlobalData.load_save_data():
		show_feedback_dialog("Save file is corrupted.")
		return

	is_processing_input = true
	GlobalData.is_loading_save = true
	var room_path: String = GlobalData.saved_scene_path
	if room_path.is_empty():
		room_path = LEGACY_SAVE_ROOM
	elif not ResourceLoader.exists(room_path, "PackedScene"):
		# A renamed or removed room cannot reuse the old room's coordinates.
		GlobalData.is_loading_save = false
		room_path = LEGACY_SAVE_ROOM
	await ClickSound.finished
	_enter_room(room_path)


func _enter_room(room_path: String) -> void:
	var result := get_tree().change_scene_to_file(room_path)
	if result != OK:
		is_processing_input = false
		GlobalData.is_loading_save = false
		show_feedback_dialog("Could not open the saved dungeon room.")

func _on_settings_pressed() -> void:
	if is_processing_input:
		return
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
	dialog.visibility_changed.connect(func():
		if dialog.visible:
			return
		if continue_button:
			continue_button.grab_focus.call_deferred()
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
	settings_button.grab_focus()
	


#func _on_mute_toggled(toggled_on: bool) -> void:
	#AudioServer.set_bus_mute(0,toggled_on)
	#
func play_hover_sound () -> void:
	HoverSound.play()
	
func play_click_sound () -> void:
	ClickSound.play()	
	
func _on_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(value))
	
