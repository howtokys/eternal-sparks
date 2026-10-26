
extends Control

# Assign the three existing buff resources in the Inspector
@export var speed_buff: BuffData
@export var shield_buff: BuffData
@export var mana_buff: BuffData

# References to the selection buttons
@onready var speed_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SpeedButton
@onready var shield_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ShieldButton
@onready var mana_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ManaButton

var selection_made: bool = false


func _ready() -> void:
	# Allow menu buttons to work while gameplay is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect the three buttons
	speed_button.pressed.connect(
		func(): select_buff(speed_buff)
	)

	shield_button.pressed.connect(
		func(): select_buff(shield_buff)
	)

	mana_button.pressed.connect(
		func(): select_buff(mana_buff)
	)

	# Pause the dungeon until a starting buff is chosen
	get_tree().paused = true


func select_buff(selected_buff: BuffData) -> void:
	# Prevent choosing more than one buff
	if selection_made:
		return

	if selected_buff == null:
		push_error("Selected buff resource is missing.")
		return

	# Find the player
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error("Player could not be found.")
		return

	# Find the player's BuffManager
	var manager: BuffManager = player.get_node_or_null(
		"BuffManager"
	) as BuffManager

	if manager == null:
		push_error("Player BuffManager could not be found.")
		return

	# Apply the chosen buff
	var added: bool = manager.add_buff(selected_buff)

	if not added:
		push_error("Could not add selected starting buff.")
		return

	selection_made = true

	print("Starting buff selected: ", selected_buff.buff_name)

	# Resume gameplay
	get_tree().paused = false

	# Close selection menu
	queue_free()
