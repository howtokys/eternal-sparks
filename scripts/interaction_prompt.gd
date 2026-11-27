extends CenterContainer

@onready var key: Label = $Plate/Content/Row/Key
@onready var title: Label = $Plate/Content/Row/Title
@onready var detail: Label = $Plate/Content/Detail

func _ready() -> void:
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode else event.keycode
			key.text = OS.get_keycode_string(code)
			return

func set_content(heading: String, description := "", show_key := true) -> void:
	title.text = heading
	detail.text = description
	detail.visible = not description.is_empty()
	key.visible = show_key
