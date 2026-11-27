extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var shield_bar: ProgressBar = %ShieldBar
@onready var mana_bar: ProgressBar = %ManaBar
@onready var health_warning: Label = %HealthWarning
@onready var shield_warning: Label = %ShieldWarning
@onready var health_value: Label = %HealthValue
@onready var shield_value: Label = %ShieldValue
@onready var mana_value: Label = %ManaValue
@onready var weapon_slot_1: PanelContainer = %WeaponSlot1
@onready var weapon_slot_2: PanelContainer = %WeaponSlot2
@onready var coin_count: Label = %CoinCount
@onready var buff_list: GridContainer = %BuffList

var player: DungeonPlayer
var buff_manager: BuffManager
var hud_icons: Dictionary[Texture2D, Texture2D] = {}

func _ready() -> void:
	for warning: Label in [health_warning, shield_warning]:
		var pulse := warning.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pulse.tween_property(warning, "modulate:a", 0.65, 0.5).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(warning, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	GlobalData.money_changed.connect(_update_coin_count)
	_update_coin_count(GlobalData.money)
	# Find the player in the scene
	player = get_tree().get_first_node_in_group("player") as DungeonPlayer

	if is_instance_valid(player):
		connect_player_signals()

func _update_coin_count(new_balance: int) -> void:
	coin_count.text = str(new_balance)


func _process(_delta: float) -> void:
	# find the players if the display was initialized before the player
	if not is_instance_valid(player):
		var found_player := get_tree().get_first_node_in_group("player") as DungeonPlayer
		if found_player != null:
			player = found_player
			connect_player_signals()
		return

func update_weapon_slots() -> void:
	var panels: Array[PanelContainer] = [weapon_slot_1, weapon_slot_2]
	for index in panels.size():
		var panel := panels[index]
		var weapon := player.weapon_slots[index] if index < player.weapon_slots.size() else null
		var icon := panel.get_node("Icon") as TextureRect
		icon.texture = _hud_icon(weapon.texture) if weapon else null
		panel.get_node("EmptyMark").visible = icon.texture == null
		var selected := index == player.active_weapon_slot and weapon != null
		panel.self_modulate = Color.WHITE if selected else Color(0.48, 0.53, 0.62)
		panel.accessibility_name = "Slot %d, %s" % [index + 1, weapon.display_name if weapon else "empty"]

func _hud_icon(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if hud_icons.has(texture):
		return hud_icons[texture]

	# Trim transparent world-sprite padding when fitting art into compact HUD slots.
	var image := texture.get_image()
	var icon := texture
	if image != null:
		var bounds := image.get_used_rect()
		if bounds.has_area() and bounds.size != image.get_size():
			var cropped := AtlasTexture.new()
			cropped.atlas = texture
			cropped.region = Rect2(bounds)
			icon = cropped
	hud_icons[texture] = icon
	return icon

func connect_player_signals() -> void:
	player.weapon_slots_changed.connect(update_weapon_slots)
	update_weapon_slots()
	var health := player.health_component
	health.health_stats_changed.connect(_on_health_stats_changed)
	player.shield_stats_changed.connect(_on_shield_stats_changed)
	player.mana_stats_changed.connect(_on_mana_stats_changed)
	_on_health_stats_changed(health.current_health, health.max_health)
	_on_shield_stats_changed(player.current_shield, player.max_shield)
	_on_mana_stats_changed(player.current_mana, player.max_mana)

	# Find player's buffmanager
	buff_manager = player.get_node_or_null("BuffManager") as BuffManager

	if buff_manager != null:

		# update hud when a new buff is added
		if not buff_manager.buff_added.is_connected(_on_buff_added):
			buff_manager.buff_added.connect(_on_buff_added)

		#update the hud when a buff is upgraded
		if not buff_manager.buff_upgraded.is_connected(_on_buff_upgraded):
			buff_manager.buff_upgraded.connect(_on_buff_upgraded)

		#update hud when buffs are cleared
		if not buff_manager.buffs_cleared.is_connected(_on_buffs_cleared):
			buff_manager.buffs_cleared.connect(_on_buffs_cleared)

		update_buff_display()


## buff ui

func update_buff_display()->void:
	#remove the old buff labels
	for child in buff_list.get_children():
		buff_list.remove_child(child)
		child.queue_free()

	if not is_instance_valid(buff_manager):
		return

	for buff in buff_manager.get_active_buffs():
		var level: int = buff_manager.get_buff_level(buff.buff_id)

		var buff_row: VBoxContainer = VBoxContainer.new()
		buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buff_row.add_theme_constant_override("separation", 0)

		var buff_icon: TextureRect = TextureRect.new()
		buff_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buff_icon.texture = _hud_icon(buff.buff_icon)
		buff_icon.accessibility_name = "%s · Lv. %d\n%s" % [buff.buff_name, level, buff.description]
		buff_icon.custom_minimum_size = Vector2(23, 23)
		buff_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		buff_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		buff_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		buff_row.add_child(buff_icon)
		buff_row.alignment = BoxContainer.ALIGNMENT_CENTER

		var buff_label: Label = Label.new()
		buff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buff_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		buff_label.add_theme_constant_override("outline_size", 2)
		buff_label.text = "Lv. %d" % level

		buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		buff_label.add_theme_font_size_override("font_size", 10)

		buff_row.add_child(buff_label)

		buff_list.add_child(buff_row)

func _on_buff_added(_buff: BuffData) -> void:
	update_buff_display()

func _on_buff_upgraded(_buff: BuffData, _level: int)->void:
	update_buff_display()

func _on_buffs_cleared()->void:
	update_buff_display()

func _on_health_stats_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%d/%d" % [current, maximum]
	health_warning.visible = maximum > 0 and current <= ceili(maximum * 0.25)


func _on_shield_stats_changed(current: int, maximum: int) -> void:
	shield_bar.max_value = maximum
	shield_bar.value = current
	shield_value.text = "%d/%d" % [current, maximum]
	shield_warning.visible = maximum > 0 and current <= 1


func _on_mana_stats_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_value.text = "%d/%d" % [floori(current), floori(maximum)]
