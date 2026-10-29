
extends Control

@onready var hover_sfx: AudioStreamPlayer = $Hover
@onready var click_sfx: AudioStreamPlayer = $Click

@onready var resume_button: Button = $PanelContainer/VBoxContainer/Button
@onready var restart_button: Button = $PanelContainer/VBoxContainer/Button2
@onready var quit_button: Button = $PanelContainer/VBoxContainer/Button3


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	hover_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	click_sfx.process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.mouse_entered.connect(play_hover_sfx)
	restart_button.mouse_entered.connect(play_hover_sfx)
	quit_button.mouse_entered.connect(play_hover_sfx)

	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape") and not event.is_echo():
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
	resume_button.call_deferred("grab_focus")


func play_hover_sfx() -> void:
	hover_sfx.play()


func play_click_sfx() -> void:
	click_sfx.play()


func _resume_pressed() -> void:
	play_click_sfx()
	resume()


func _restart_pressed() -> void:
	play_click_sfx()

	# Let the click finish before replacing the World scene
	await click_sfx.finished

	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_pressed() -> void:
	play_click_sfx()

	# Let the click finish before closing the game
	await click_sfx.finished

	get_tree().quit()
