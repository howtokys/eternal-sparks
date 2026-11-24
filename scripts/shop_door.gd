extends Area2D

@export_file("*.tscn") var destination: String
@export var arrival_marker: NodePath
@export var return_spawn: NodePath
@export var use_return_route := false
@export var prompt_text := "E: Leave shop"

@onready var prompt: Label = $Prompt

func _ready() -> void:
	prompt.text = prompt_text
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is DungeonPlayer:
		prompt.show()

func _on_body_exited(body: Node2D) -> void:
	if body is DungeonPlayer:
		prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	var room: Node
	if use_return_route and GlobalData.return_room_path.begins_with("res://") and not GlobalData.return_spawn_id.is_empty():
		room = _prepare_room(GlobalData.return_room_path, NodePath(GlobalData.return_spawn_id))
	if room == null:
		room = _prepare_room(destination, arrival_marker)
	if room == null:
		push_error("Could not open doorway destination: %s" % destination)
		return
	var origin := get_tree().current_scene.scene_file_path
	var result := get_tree().change_scene_to_node(room)
	if result != OK:
		room.free()
		push_error("Could not change rooms: %s" % error_string(result))
	elif not return_spawn.is_empty():
		GlobalData.return_room_path = origin
		GlobalData.return_spawn_id = String(return_spawn)


func _prepare_room(path: String, spawn: NodePath) -> Node:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var room := packed.instantiate()
	if not spawn.is_empty():
		var marker := room.get_node_or_null(spawn) as Marker2D
		var player := room.find_child("Player") as DungeonPlayer
		if marker == null or player == null:
			room.free()
			return null
		# The first checkpoint must already contain the doorway arrival position.
		player.global_position = marker.global_position
	return room
