extends AudioStreamPlayer

func _ready() -> void:
	# Allows music to keep playing even when you pause the game
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = "Music"

func play_music(stream_to_play: AudioStream) -> void:
	# If this song is already playing, do nothing (prevents restart)
	if stream == stream_to_play and playing:
		return
	
	stream = stream_to_play
	play()
