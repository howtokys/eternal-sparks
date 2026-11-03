extends Control

var leaving := false

func _ready() -> void:
	get_tree().paused = false
	var summaries: PackedStringArray = []
	for saved in GlobalData.room_buff_snapshot:
		var buff: BuffData = saved["resource"]
		if buff != null:
			summaries.append("%s · Level %d" % [buff.buff_name, int(saved["level"])])
	$Center/Panel/Margin/Content/BuffSummary.text = "\n".join(summaries)
	$Center/Panel/Margin/Content/Menu.pressed.connect(_return_to_menu)
	$Center/Panel/Margin/Content/Quit.pressed.connect(func(): get_tree().quit())
	$Center/Panel/Margin/Content/Menu.grab_focus()

func _return_to_menu() -> void:
	if leaving:
		return
	leaving = true
	call_deferred("_change_to_menu")

func _change_to_menu() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/Main-Menu.tscn")
	if error != OK:
		leaving = false
		push_error("Could not return to menu: " + error_string(error))
	else:
		GlobalData.room_buff_snapshot.clear()
		GlobalData.is_loading_save = false
