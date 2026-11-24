
extends Control

@onready var master_slider: HSlider = $VBoxContainer/HBoxContainer3/Volume
@onready var music_slider: HSlider = $VBoxContainer/HBoxContainer4/Volume

@onready var screen_mode: OptionButton = $VBoxContainer/HBoxContainer/OptionButton

# Some window managers deliver resize and focus events before the mode change is acknowledged.
const MODE_ACK_TIMEOUT_MS := 1000
var requested_mode := -1
var mode_deadline_ms := 0

func _ready() -> void:
	screen_mode.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	screen_mode.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	screen_mode.item_selected.connect(_apply_screen_mode)
	visibility_changed.connect(_on_settings_visibility_changed)
	_on_settings_visibility_changed()
	# Load the current Master volume into the slider
	master_slider.set_value_no_signal(
		db_to_linear(AudioServer.get_bus_volume_db(0))
	)

	# Load the current Music volume
	var music_bus := AudioServer.get_bus_index("Music")

	if music_bus != -1:
		music_slider.set_value_no_signal(
			db_to_linear(AudioServer.get_bus_volume_db(music_bus))
		)

	# Connect each slider to its own function
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)


func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		0,
		linear_to_db(value)
	)
	print("Master Volume: ", value)


func _on_music_volume_changed(value: float) -> void:
	
	print ("Music slider moved:", value)
	var music_bus := AudioServer.get_bus_index("Music")
	print("Music bus index: ", music_bus)

	if music_bus == -1:
		push_warning("Music audio bus does not exist.")
		return

	AudioServer.set_bus_volume_db(
		music_bus,
		linear_to_db(value)
	)
	print("Music Volume: ", value)
	print("Music us actual db: ", AudioServer.get_bus_volume_db(music_bus))


func _apply_screen_mode(index: int) -> void:
	requested_mode = screen_mode.get_item_id(index)
	mode_deadline_ms = Time.get_ticks_msec() + MODE_ACK_TIMEOUT_MS
	# Let the dropdown finish dismissing before resizing its owner window.
	get_window().set_mode.call_deferred(requested_mode)
	set_process(true)


func _on_settings_visibility_changed() -> void:
	set_process(is_visible_in_tree())
	_sync_screen_mode()


func _process(_delta: float) -> void:
	_sync_screen_mode()


func _sync_screen_mode() -> void:
	if not is_visible_in_tree():
		return
	var mode := DisplayServer.window_get_mode(get_window().get_window_id())
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	var actual := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	# Keep the selected caption until the OS acknowledges the request. If the OS
	# refuses it, restore the actual mode instead of leaving a false caption.
	if requested_mode != -1 and requested_mode != actual and Time.get_ticks_msec() < mode_deadline_ms:
		return
	requested_mode = -1
	if screen_mode.get_selected_id() != actual:
		screen_mode.select(screen_mode.get_item_index(actual))
