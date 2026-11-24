extends Control

const CARD := preload("res://scenes/buff_choice_card.tscn")

# The room-clear flow supplies its roll. Starting selections roll on entry.
var clear_options: Array[BuffData] = []
var choices: Array[BuffData] = []
var selection_made := false

@onready var cards: HBoxContainer = %Cards
@onready var manager: BuffManager = GlobalData.player.buff_manager
@onready var click_sfx: AudioStreamPlayer = $Click

func _ready() -> void:
	if clear_options.is_empty():
		if GlobalData.starting_buff_chosen:
			hide()
			queue_free()
			return
		add_to_group(&"starting_buff_picker")
		choices = manager.clear_choices()
	else:
		%Title.text = "Choose a room-clear buff"
		choices = clear_options

	if choices.is_empty():
		# A returning player can already have every normal buff at its cap.
		_record_choice()
		queue_free()
		return

	for buff in choices:
		var card := CARD.instantiate() as Button
		cards.add_child(card)
		var level := manager.get_buff_level(buff.buff_id)
		card.get_node("Content/Icon").texture = buff.buff_icon
		card.get_node("Content/Name").text = buff.buff_name
		card.get_node("Content/Level").text = "New" if level == 0 else "Lv. %d → Lv. %d" % [level, level + 1]
		card.get_node("Content/Effect").text = buff.description
		card.accessibility_name = buff.buff_name
		card.accessibility_description = "%s. %s" % [card.get_node("Content/Level").text, buff.description]
		card.mouse_entered.connect($Hover.play.bind(0.0))
		card.pressed.connect(select_buff.bind(buff))

	for i in choices.size():
		var card := cards.get_child(i) as Button
		card.focus_neighbor_left = card.get_path_to(cards.get_child(posmod(i - 1, choices.size())))
		card.focus_neighbor_right = card.get_path_to(cards.get_child((i + 1) % choices.size()))
	get_tree().paused = true
	cards.get_child(0).grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and get_tree().paused and event.is_action_pressed(&"escape"):
		get_viewport().set_input_as_handled()


func select_buff(buff: BuffData) -> void:
	if selection_made or not choices.has(buff):
		return
	var level := manager.get_buff_level(buff.buff_id)
	var applied := manager.add_buff(buff) if level == 0 else manager.upgrade_buff(buff.buff_id)
	if not applied:
		return
	selection_made = true
	_record_choice()
	click_sfx.play()
	await click_sfx.finished
	get_tree().paused = false
	queue_free()

func _record_choice() -> void:
	if clear_options.is_empty():
		GlobalData.starting_buff_chosen = true
	else:
		GlobalData.clear_rewards[get_tree().current_scene.scene_file_path] = "claimed"
	GlobalData.request_save()
