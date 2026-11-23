extends Control

@onready var hover_sfx: AudioStreamPlayer = $Hover
@onready var click_sfx: AudioStreamPlayer = $Click
@onready var pause_buttons: PanelContainer = $PanelContainer
@onready var resume_button: Button = $PanelContainer/VBoxContainer/Button
@onready var shop_button: Button = $PanelContainer/VBoxContainer/Shop
@onready var restart_button: Button = $PanelContainer/VBoxContainer/Button2
@onready var quit_button: Button = $PanelContainer/VBoxContainer/Button3
@onready var shop_menu = $ShopMenu

var owns_pause: bool = false
var leaving_scene: bool = false


func _ready() -> void:
	for button: Button in [resume_button, shop_button, restart_button, quit_button]:
		button.mouse_entered.connect(play_hover_sfx)
	shop_button.pressed.connect(_shop_pressed)
	shop_menu.back_requested.connect(_return_from_shop)
	hide()


func _input(event: InputEvent) -> void:
	if GlobalData.run_finished or not event.is_action_pressed("escape") or event.is_echo():
		return
	if get_tree().paused and not owns_pause:
		return

	get_viewport().set_input_as_handled()
	if leaving_scene:
		return
	if shop_menu.visible:
		shop_menu.request_back()
	elif owns_pause:
		resume()
	else:
		pause()


func resume() -> void:
	if not owns_pause:
		return
	owns_pause = false
	get_tree().paused = false
	$AnimationPlayer.play_backwards("pause_blur")
	hide()


func pause() -> void:
	if get_tree().paused:
		return
	owns_pause = true
	show()
	get_tree().paused = true
	$AnimationPlayer.play("pause_blur")
	resume_button.call_deferred("grab_focus")
	GlobalData.request_save()


func _shop_pressed() -> void:
	if not owns_pause or leaving_scene:
		return
	play_click_sfx()
	pause_buttons.hide()
	$PauseFrame.hide()
	$Spiderweb.hide()
	shop_menu.open()


func _return_from_shop() -> void:
	shop_menu.hide()
	pause_buttons.show()
	$PauseFrame.show()
	$Spiderweb.show()
	shop_button.call_deferred("grab_focus")


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
	var result := get_tree().reload_current_scene()
	if result != OK:
		leaving_scene = false
		push_error("Could not restart the current scene: %s" % error_string(result))


func _quit_pressed() -> void:
	if leaving_scene:
		return
	leaving_scene = true
	play_click_sfx()
	await click_sfx.finished
	GlobalData.save_game()
	resume()
	get_tree().quit()
