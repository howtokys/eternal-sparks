extends Area2D

const COIN_COLOR := Color("#ffd47a")
const PACT_COLOR := Color("#ff9eb9")

@export var offer: ShopItemData
## Use a unique ID for this position in the dungeon to retain the sale across room loads.
@export var stock_id: StringName
@export var prompt_offset := Vector2(0, -33)

@onready var item_icon: TextureRect = $ItemIcon
@onready var price: Label = $Price
@onready var prompt: Label = $PromptAnchor/Prompt
@onready var wooden_stand: Sprite2D = $WoodenStand
@onready var pact_altar: Sprite2D = $PactAltar
@onready var interact_sfx: AudioStreamPlayer2D = $Interact
@onready var purchase_sfx: AudioStreamPlayer2D = $Purchase
@onready var error_sfx: AudioStreamPlayer2D = $Error

var nearby_player: DungeonPlayer
var armed := false
var sold := false
var purchasing := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if offer == null:
		return

	$PromptAnchor.position = prompt_offset
	item_icon.texture = offer.display_icon()
	if offer.kind == ShopItemData.Kind.WEAPON and item_icon.texture:
		var art := AtlasTexture.new()
		art.atlas = item_icon.texture
		art.region = Rect2(art.atlas.get_image().get_used_rect())
		item_icon.texture = art
		item_icon.offset_left = -13
		item_icon.offset_right = 13
		item_icon.position.y += 5
	price.text = offer.cost_text().trim_prefix("Permanent cost: ")
	if offer.kind == ShopItemData.Kind.PACT:
		price.modulate = PACT_COLOR
		wooden_stand.hide()
		pact_altar.show()
	if GlobalData.is_shop_stock_sold(stock_id):
		_show_sold()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and armed:
		armed = false
		_show_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or sold or purchasing or offer == null:
		return
	if not is_instance_valid(nearby_player) or nearby_player.is_queued_for_deletion():
		return
	if GlobalData.is_shop_stock_sold(stock_id):
		_show_sold()
		return
	get_viewport().set_input_as_handled()

	if offer.kind == ShopItemData.Kind.PACT and not armed:
		var failure := offer.purchase_error(nearby_player)
		if not failure.is_empty():
			_show_error(failure)
			return
		armed = true
		_show_prompt()
		interact_sfx.play()
		return

	purchasing = true
	armed = false
	var failure := offer.purchase(nearby_player, global_position + Vector2.DOWN * 12)
	if failure.is_empty():
		_show_sold()
		GlobalData.mark_shop_stock_sold(stock_id)
		purchase_sfx.play()
	else:
		_show_error(failure)
	purchasing = false


func _on_body_entered(body: Node2D) -> void:
	if body is DungeonPlayer:
		nearby_player = body
		_show_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body == nearby_player:
		nearby_player = null
		armed = false
		_show_prompt()


func _show_prompt() -> void:
	price.visible = not armed
	prompt.visible = offer != null and not sold and is_instance_valid(nearby_player)
	if not prompt.visible:
		return
	prompt.add_theme_color_override("font_color", PACT_COLOR if armed else Color.WHITE)
	if armed:
		var cost := "Trade Reflect" if not offer.trade_buff.is_empty() else "-%d Max %s" % [
			offer.sacrifice_amount, ShopItemData.STAT_NAMES[offer.stat].capitalize()]
		prompt.text = "%s\n[E] Confirm" % cost
	else:
		prompt.text = "[E] %s" % offer.display_name()
		if offer.kind == ShopItemData.Kind.WEAPON:
			prompt.text += "\n%s | %s" % [offer.description(), "Equip" if nearby_player.weapon_slots.has(null) else "Swap"]


func _show_sold() -> void:
	sold = true
	armed = false
	item_icon.hide()
	prompt.hide()
	wooden_stand.self_modulate = Color.DIM_GRAY
	pact_altar.self_modulate = Color.DIM_GRAY
	price.show()
	price.text = "Sold"
	price.modulate = Color("#b6acb9")


func _show_error(message: String) -> void:
	price.show()
	prompt.text = message
	prompt.add_theme_color_override("font_color", Color("#ffc49d"))
	error_sfx.play()
