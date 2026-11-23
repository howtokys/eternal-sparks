extends Area2D

@export_file("*.tscn") var destination: String
@export var arrival_marker: NodePath
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
	var packed := load(destination) as PackedScene
	if packed == null:
		push_error("Could not load doorway destination: %s" % destination)
		return
	var room := packed.instantiate()
	if not arrival_marker.is_empty():
		var marker := room.get_node_or_null(arrival_marker) as Marker2D
		var player := room.find_child("Player") as DungeonPlayer
		if marker == null or player == null:
			push_error("Missing doorway arrival marker or player in %s" % destination)
			room.free()
			return
		# Place before _ready so the first checkpoint uses the doorway spawn.
		player.global_position = marker.global_position
	var result := get_tree().change_scene_to_node(room)
	if result != OK:
		room.free()
		push_error("Could not open %s: %s" % [destination, error_string(result)])
