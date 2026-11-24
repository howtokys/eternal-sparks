extends Control

@onready var hover_sfx: AudioStreamPlayer = $Hover
@onready var click_sfx: AudioStreamPlayer = $Click
@onready var resume_button: Button = %Resume
@onready var restart_button: Button = %Restart
@onready var quit_button: Button = %Quit

var owns_pause: bool = false
var leaving_scene: bool = false


func _ready() -> void:
	for button: Button in [resume_button, restart_button, quit_button]:
		button.mouse_entered.connect(play_hover_sfx)
	hide()


func _input(event: InputEvent) -> void:
	if GlobalData.run_finished or not event.is_action_pressed("escape") or event.is_echo():
		return
	if get_tree().paused and not owns_pause:
		return

	get_viewport().set_input_as_handled()
	if leaving_scene:
		return
	if owns_pause:
		resume()
	else:
		pause()


func resume() -> void:
	if not owns_pause:
		return
	owns_pause = false
	get_tree().paused = false
	hide()


func pause() -> void:
	if get_tree().paused:
		return
	owns_pause = true
	show()
	get_tree().paused = true
	resume_button.call_deferred("grab_focus")
	GlobalData.request_save()


func play_hover_sfx() -> void:
	hover_sfx.play()


func play_click_sfx() -> void:
	click_sfx.play()


func _resume_pressed() -> void:
	if leaving_scene:
		return
	play_click_sfx()
	resume()


func _restart_pressed() -> void:
	if leaving_scene:
		return
	leaving_scene = true
	play_click_sfx()
	await click_sfx.finished

	GlobalData.start_new_run()
	resume()
	var result := get_tree().change_scene_to_file("res://scenes/First_Room.tscn")
	if result != OK:
		leaving_scene = false
		push_error("Could not restart the run: %s" % error_string(result))


func _quit_pressed() -> void:
	if leaving_scene:
		return
	leaving_scene = true
	play_click_sfx()
	await click_sfx.finished
	GlobalData.save_game()
	resume()
	get_tree().quit()
