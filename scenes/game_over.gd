extends Control

const START_ROOM := "res://scenes/First_Room.tscn"
const MAIN_MENU := "res://scenes/Main-Menu.tscn"


func _ready() -> void:
	%Restart.grab_focus()
	%Restart.pressed.connect(_leave.bind(true))
	%MainMenu.pressed.connect(_leave.bind(false))


func _leave(restart: bool) -> void:
	var tree := get_tree()
	var result := tree.change_scene_to_file(START_ROOM if restart else MAIN_MENU)
	if result != OK:
		push_error("Could not leave game over: %s" % error_string(result))
		return
	# The new room enters the tree at the end of the frame, after this reset.
	if restart:
		GlobalData.start_new_run()
	tree.paused = false
