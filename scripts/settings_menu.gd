
extends Control

@onready var master_slider: HSlider = $VBoxContainer/HBoxContainer3/Volume
@onready var music_slider: HSlider = $VBoxContainer/HBoxContainer4/Volume

func _ready() -> void:
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
