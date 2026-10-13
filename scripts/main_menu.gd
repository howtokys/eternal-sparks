extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")
	print("Start pressed")


func _on_settings_pressed() -> void:
	print("Settings pressed")


func _on_continue_pressed() -> void:
	print("Contineu pressed")


func _on_exit_pressed() -> void:
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
	
