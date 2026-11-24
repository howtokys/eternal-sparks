extends Control

signal back_requested

const REPEAT_PURCHASE_DELAY_MS := 350
const SUCCESS_COLOR := Color("#d4edb0")
const ERROR_COLOR := Color("#ffc49d")
const COIN_COLOR := Color("#ffd47a")
const PACT_COLOR := Color("#ff9eb9")

@export var regular_items: Array[ShopItemData]
@export var pacts: Array[ShopItemData]

@onready var regular_tab: Button = %RegularTab
@onready var mysterious_tab: Button = %MysteriousTab
@onready var regular_contents: VBoxContainer = %RegularContents
@onready var mysterious_contents: VBoxContainer = %MysteriousContents
@onready var coin_balance: Label = %CoinBalance
@onready var back_button: Button = %Back
@onready var hover_sfx: AudioStreamPlayer = $Hover
@onready var click_sfx: AudioStreamPlayer = $Click
@onready var purchase_sfx: AudioStreamPlayer = $Purchase
@onready var error_sfx: AudioStreamPlayer = $Error
@onready var browsing: VBoxContainer = %Browsing
@onready var inventory: ScrollContainer = %Inventory
@onready var feedback: Label = %Feedback
@onready var confirmation: VBoxContainer = %Confirmation
@onready var confirmation_text: RichTextLabel = %ConfirmationText
@onready var feedback_panel: PanelContainer = feedback.get_parent()
@onready var cancel_button: Button = %Cancel
@onready var confirm_button: Button = %Confirm

var offers: Dictionary[Button, ShopItemData] = {}
var last_purchase_at: Dictionary[ShopItemData, int] = {}
var pending_pact: ShopItemData
var pending_button: Button
var purchasing: bool = false
var feedback_tween: Tween


func _ready() -> void:
	GlobalData.money_changed.connect(_update_balance)
	_update_balance(GlobalData.money)
	for button: Button in [regular_tab, mysterious_tab, back_button, cancel_button, confirm_button]:
		button.mouse_entered.connect(hover_sfx.play.bind(0.0))
	regular_tab.pressed.connect(_tab_pressed.bind(false))
	mysterious_tab.pressed.connect(_tab_pressed.bind(true))
	back_button.pressed.connect(request_back)
	cancel_button.pressed.connect(request_back)
	confirm_button.pressed.connect(_confirm_pact)

	for item in regular_items:
		_add_card(regular_contents, item)
	for item in pacts:
		_add_card(mysterious_contents, item)


func open() -> void:
	pending_pact = null
	pending_button = null
	confirmation.hide()
	browsing.show()
	_show_category(false)
	show()
	regular_tab.call_deferred("grab_focus")


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("escape") and not event.is_echo():
		get_viewport().set_input_as_handled()
		request_back()


func request_back() -> void:
	click_sfx.play()
	if confirmation.visible:
		_cancel_confirmation()
	else:
		back_requested.emit()


func _tab_pressed(mysterious: bool) -> void:
	click_sfx.play()
	_show_category(mysterious)


func _show_category(mysterious: bool) -> void:
	regular_tab.set_pressed_no_signal(not mysterious)
	mysterious_tab.set_pressed_no_signal(mysterious)
	regular_contents.visible = not mysterious
	mysterious_contents.visible = mysterious
	feedback.text = ""
	if feedback_tween != null:
		feedback_tween.kill()
	feedback_panel.self_modulate.a = 0.0
	inventory.scroll_vertical = 0
	_refresh_offers()


func _add_card(list: VBoxContainer, item: ShopItemData) -> void:
	if item == null:
		return
	var is_pact := item.kind == ShopItemData.Kind.PACT
	var card := PanelContainer.new()
	card.theme_type_variation = &"PactCard" if is_pact else &"RegularCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(card)

	var row := HBoxContainer.new()
	row.name = &"Row"
	row.custom_minimum_size.y = 49
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = item.display_icon()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.name = &"Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)

	var item_title := Label.new()
	item_title.text = item.display_name()
	item_title.add_theme_font_size_override("font_size", 12)
	item_title.add_theme_color_override("font_color", Color("#f8e9e7"))
	info.add_child(item_title)

	var details := Label.new()
	details.text = item.description()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 10)
	info.add_child(details)

	var cost := Label.new()
	cost.text = item.cost_text()
	cost.add_theme_color_override("font_color", PACT_COLOR if is_pact else COIN_COLOR)
	cost.add_theme_font_size_override("font_size", 10)
	info.add_child(cost)

	var restriction := Label.new()
	restriction.name = &"Restriction"
	restriction.modulate = ERROR_COLOR
	restriction.add_theme_font_size_override("font_size", 10)
	restriction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restriction.hide()
	info.add_child(restriction)

	var button := Button.new()
	button.name = &"Action"
	if is_pact:
		button.theme_type_variation = &"PactButton"
	button.custom_minimum_size = Vector2(94, 28)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 13)
	button.mouse_entered.connect(hover_sfx.play.bind(0.0))
	button.pressed.connect(_select_offer.bind(item, button))
	row.add_child(button)
	offers[button] = item


func _refresh_offers() -> void:
	var player := GlobalData.player as DungeonPlayer
	for button in offers:
		var item := offers[button]
		button.get_parent().get_parent().visible = item.available_to(player)
		var reason := item.purchase_error(player)
		var owns_pact := item.is_owned(player)
		var had_focus := button.has_focus()
		button.disabled = not reason.is_empty()
		var action := "Choose" if item.kind == ShopItemData.Kind.PACT else "Buy"
		if button.disabled:
			action = "Owned" if owns_pact else "Unavailable"
		button.text = action
		button.tooltip_text = reason
		var restriction: Label = button.get_node("../Info/Restriction")
		restriction.text = reason
		restriction.visible = button.disabled and not owns_pact
		if button.disabled and had_focus:
			back_button.grab_focus()


func _select_offer(item: ShopItemData, button: Button) -> void:
	if not _can_purchase() or not browsing.visible or not button.is_visible_in_tree():
		return

	var reason := item.purchase_error(GlobalData.player as DungeonPlayer)
	if not reason.is_empty():
		_show_feedback(reason, false)
		_refresh_offers()
		return
	if item.kind != ShopItemData.Kind.PACT:
		_purchase(item)
		return

	click_sfx.play()
	pending_pact = item
	pending_button = button
	confirmation_text.text = (
		"[center][b]Accept %s?[/b]\n\n%s\n[color=#ff9eb9]%s[/color]\n"
		+ "%s[/center]"
	) % [
		item.display_name().replace("[", "[lb]"),
		item.description().replace("[", "[lb]"),
		item.cost_text().replace("[", "[lb]"),
		"Reflect will be consumed." if not item.trade_buff.is_empty() else "This sacrifice lasts for the rest of the run.",
	]
	browsing.hide()
	confirmation.show()
	cancel_button.grab_focus()


func _confirm_pact() -> void:
	if not _can_purchase() or not confirmation.visible or pending_pact == null:
		return
	var item := pending_pact
	_cancel_confirmation()
	_purchase(item)


func _cancel_confirmation() -> void:
	var return_button := pending_button
	pending_pact = null
	pending_button = null
	confirmation.hide()
	browsing.show()
	if is_instance_valid(return_button) and not return_button.disabled:
		return_button.grab_focus()
	else:
		mysterious_tab.grab_focus()


func _can_purchase() -> bool:
	return is_visible_in_tree() and get_tree().paused and not purchasing


func _purchase(item: ShopItemData) -> void:
	var now := Time.get_ticks_msec()
	if now - last_purchase_at.get(item, -REPEAT_PURCHASE_DELAY_MS) < REPEAT_PURCHASE_DELAY_MS:
		_show_feedback("Wait a moment before buying this again.", false)
		return
	purchasing = true
	var failure := item.purchase(GlobalData.player as DungeonPlayer)
	if failure.is_empty():
		last_purchase_at[item] = now
		_show_feedback("%s purchased." % item.display_name(), true)
	else:
		_show_feedback(failure, false)
	purchasing = false
	_refresh_offers()


func _show_feedback(message: String, success: bool) -> void:
	feedback.text = message
	feedback.modulate = SUCCESS_COLOR if success else ERROR_COLOR
	if feedback_tween != null:
		feedback_tween.kill()
	feedback_panel.self_modulate = Color(1.35, 2.0, 1.25) if success else Color(2.0, 1.1, 1.15)
	feedback_tween = create_tween()
	feedback_tween.tween_property(feedback_panel, "self_modulate", Color.WHITE, 0.24).set_ease(Tween.EASE_OUT)
	if success:
		purchase_sfx.play()
	else:
		error_sfx.play()


func _update_balance(new_balance: int) -> void:
	coin_balance.text = "%d coins" % new_balance
	if is_visible_in_tree() and not purchasing:
		_refresh_offers()
