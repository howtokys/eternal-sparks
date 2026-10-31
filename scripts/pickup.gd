extends Area2D

var _data: ItemData
@export var data: ItemData:
	get:
		return _data
	set(value):
		_data = value
		_update_visual()

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var player_in_range: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if label:
		label.hide()
	
	_update_visual()

func _update_visual() -> void:
	if data and is_instance_valid(sprite_2d):
		sprite_2d.texture = data.item_texture
		sprite_2d.centered = true 
	if data and is_instance_valid(label):
		label.text = data.item_name

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		if label:
			label.show()
			
func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		if label:
			label.hide()
			
func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		use_item(player_in_range)

func use_item(body: Node2D) -> void:
	if data:
		if data.item_type == ItemData.Type.HEALTH_POTION:
			print("Used health potion: ", data.item_name)
			body.health_component.heal(data.restore_amount)

		elif data.item_type == ItemData.Type.MANA_POTION:
			print("Used mana potion: ", data.item_name)
			body.restore_mana(data.restore_amount)
			
		elif data.item_type == ItemData.Type.GUN:
			var weapon := body.get_node_or_null("Gun") as Weapon
			if weapon == null or data.weapon_data == null:
				push_error("Weapon pickup is missing a player Weapon or WeaponData.")
				return
			weapon.set_weapon_data(data.weapon_data)
			print("Equipped weapon: ", data.item_name)
			
	queue_free()
