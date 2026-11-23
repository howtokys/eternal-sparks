extends AudioStreamPlayer

const SFX_POOL_SIZE := 8
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_bus: StringName = &"Master"

func _ready() -> void:
	# Allows music to keep playing even when you pause the game
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = "Music"

	if AudioServer.get_bus_index(&"SFX") != -1:
		sfx_bus = &"SFX"

	for _index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = sfx_bus
		add_child(player)
		sfx_pool.append(player)

func play_music(stream_to_play: AudioStream) -> void:
	# If this song is already playing, do nothing (prevents restart)
	if stream == stream_to_play and playing:
		return
	
	stream = stream_to_play
	play()

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return

	for player in sfx_pool:
		if player.playing:
			continue
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.play()
		return

func play_world_sfx(stream: AudioStream, world_position: Vector2, pitch_scale: float = 1.0) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = sfx_bus
	player.max_distance = 460.0
	player.panning_strength = 0.65
	player.pitch_scale = pitch_scale
	get_tree().current_scene.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()
