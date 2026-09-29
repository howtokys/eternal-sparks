extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if get_tree().paused:
			resume()
		else:
			pause()


func resume() -> void:
	get_tree().paused = false
	$AnimationPlayer.play_backwards("pause_blur")
	hide()


func pause() -> void:
	show()
	get_tree().paused = true
	$AnimationPlayer.play("pause_blur")


func _resume_pressed() -> void:
	resume()


func _restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_pressed() -> void:
	get_tree().quit()
