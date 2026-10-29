
extends Control

#sounds
const SPEED_SOUND = preload("res://speed_boost.wav")
const SHIELD_SOUND = preload("res://shield_boost.wav")
const MANA_SOUND = preload("res://mana_regen.wav")
const CLICK_SOUND = preload("res://buff_select_click.wav")

# Assign the three existing buff resources in the Inspector
@export var speed_buff: BuffData
@export var shield_buff: BuffData
@export var mana_buff: BuffData

# References to the selection buttons
@onready var speed_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SpeedButton
@onready var shield_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ShieldButton
@onready var mana_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ManaButton

#for audio 
@onready var speed_sfx: AudioStreamPlayer = $Speed
@onready var shield_sfx: AudioStreamPlayer = $Shield
@onready var mana_sfx: AudioStreamPlayer = $Mana
@onready var click_sfx: AudioStreamPlayer = $Click

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
	
	speed_button.mouse_entered.connect(play_speed_hover)
	shield_button.mouse_entered.connect(play_shield_hover)
	mana_button.mouse_entered.connect(play_mana_hover)
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
	
	play_buff_click()
	
	#await till sound is played
	await click_sfx.finished

	# Resume gameplay
	get_tree().paused = false

	# Close selection menu
	queue_free()
# Sound when hovering over Speed Boost
func play_speed_hover() -> void:
	speed_sfx.play()

# Sound when hovering over Shield Boost
func play_shield_hover() -> void:
	shield_sfx.play()

# Sound when hovering over Mana Regen
func play_mana_hover() -> void:
	mana_sfx.play()

# Sound when selecting a buff
func play_buff_click() -> void:
	click_sfx.play()
