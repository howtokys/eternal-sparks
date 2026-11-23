extends Node

const FIRST_ROOM = "res://scenes/First_Room.tscn"
const SHOP_ROOM = "res://scenes/shop_room.tscn"
const WORLD = "res://scenes/World.tscn"
const MAIN_MENU = "res://scenes/Main-Menu.tscn"
const TEST_SAVE_PATH = "user://shop_regression_save.json"
var failures := 0
var balance_events: Array[int] = []

func _ready() -> void:
	call_deferred("_run")

func check(passed: bool, label: String) -> void:
	print("%s %s" % ["PASS" if passed else "FAIL", label])
	if not passed:
		failures += 1

func settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		get_tree().root.push_input(event, true)

func click(button: Button) -> void:
	var viewport := get_tree().root
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		viewport.push_input(event, true)

func load_room(path: String) -> void:
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		check(false, "scene loads: %s" % path)
		get_tree().quit(1)
		return
	await get_tree().scene_changed
	await settle()

func choose_starter() -> StringName:
	var picker := get_tree().current_scene.get_node("PauseLayer/BuffSelection")
	# These shop fixtures measure baseline HP/shield and their pact modifiers.
	var index := 0
	while picker.choices[index].buff_id in [&"life", &"protection"]:
		index += 1
	var selected: StringName = picker.choices[index].buff_id
	click(picker.cards.get_child(index))
	await picker.tree_exited
	await settle()
	return selected

func _shows_weapon_art(icon: TextureRect, weapon: WeaponData) -> bool:
	var image := weapon.texture.get_image()
	var bounds := image.get_used_rect()
	if bounds.size == image.get_size():
		return icon.texture == weapon.texture
	var cropped := icon.texture as AtlasTexture
	return cropped != null and cropped.atlas == weapon.texture and cropped.region == Rect2(bounds)

func offer(list: VBoxContainer, slot: int) -> Button:
	return list.get_child(slot).get_node("Row/Action") as Button


func _run() -> void:
	var tree := get_tree()
	var root := tree.root
	reparent(root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	GlobalData.save_path = TEST_SAVE_PATH
	GlobalData.start_new_run()
	# Use a test-specific save even when launched with F6 in the editor.
	tree.create_timer(20.0).timeout.connect(func():
		push_error("Shop regression timed out.")
		tree.quit(1))
	print("Shop regression window: ", root.size)
	check(ProjectSettings.get_setting("application/run/main_scene") == MAIN_MENU,
		"launching the project targets the Main Menu")
	GlobalData.money_changed.connect(func(balance: int): balance_events.append(balance))
	await _test_screen_mode()
	await _test_continue_without_save()
	await load_room(FIRST_ROOM)
	var starting_id := await choose_starter()

	var room := tree.current_scene
	var hud := room.get_node("CanvasLayer")
	var player := GlobalData.player as DungeonPlayer
	var health := player.health_component
	var manager := player.buff_manager
	var pause := room.get_node("PauseLayer/PauseScene")
	var shop := pause.shop_menu as Control
	key(KEY_ESCAPE)
	await settle()
	click(pause.shop_button)
	await settle()
	check(shop.visible and tree.paused and shop.regular_tab.has_focus(), "Phase 1 pause and shop focus are preserved")
	check(shop.get_viewport_rect().encloses(shop.get_node("Panel").get_global_rect()), "shop panel fits the viewport")
	check(shop.regular_contents.get_child_count() == shop.regular_items.size() and shop.mysterious_contents.get_child_count() == shop.pacts.size(), "both categories build a card for every resource-backed offer")
	var first_icon := hud.weapon_slot_1.get_node("Icon") as TextureRect
	var second_icon := hud.weapon_slot_2.get_node("Icon") as TextureRect
	check(_shows_weapon_art(first_icon, player.weapon_slots[0]) and hud.weapon_slot_2.get_node("EmptyMark").visible,
		"HUD shows the starting weapon icon and an empty second slot")
	var alternate := preload("res://scripts/weapons/data/shotgun.tres")
	if alternate.id == player.weapon_slots[0].id:
		alternate = preload("res://scripts/weapons/data/pistol.tres")
	player.equip_weapon(alternate)
	check(_shows_weapon_art(second_icon, alternate) and not hud.weapon_slot_2.get_node("EmptyMark").visible
			and hud.weapon_slot_2.self_modulate == Color.WHITE and hud.weapon_slot_1.self_modulate != Color.WHITE,
		"equipping a second weapon updates its icon and active frame immediately while paused")
	player.switch_weapon(0)
	check(hud.weapon_slot_1.self_modulate == Color.WHITE and hud.weapon_slot_2.self_modulate != Color.WHITE
			and _shows_weapon_art(second_icon, alternate), "switching back retains both icons and moves the highlight")
	var health_buy := offer(shop.regular_contents, 0)
	var shield_buy := offer(shop.regular_contents, 1)
	var mana_buy := offer(shop.regular_contents, 2)
	check(hud.health_value.text == "6/6" and hud.shield_value.text == "5/5" and hud.mana_value.text == "200/200",
		"HUD starts with exact current and maximum values")
	var centered := true
	for label: Label in [hud.health_value, hud.shield_value, hud.mana_value]:
		var bar := label.get_parent() as ProgressBar
		centered = centered and bar != null and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER and label.get_global_rect().get_center().is_equal_approx(bar.get_global_rect().get_center())
	check(centered and not hud.health_warning.visible and not hud.shield_warning.visible,
		"healthy HUD centers each value over its bar and hides both warnings")
	var passive := true
	for control: Control in hud.find_children("*", "Control", true, false):
		passive = passive and control.mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(passive and hud.coin_count.get_global_rect().end.x >= shop.get_viewport_rect().size.x - 9,
		"HUD controls pass mouse input and the coin count is anchored at the right edge")
	check(health_buy.disabled and shield_buy.disabled and mana_buy.disabled, "all full resources are disabled")
	check(not health.heal(1) and not player.restore_shield(1) and not player.restore_mana(1) and not player.restore_stat(DungeonPlayer.Stat.MANA, 0), "restoration helpers report no change at full or invalid amounts")

	health.take_damage(4)
	player.take_damage(4)
	check(hud.health_warning.visible and hud.shield_warning.visible, "HP at the quarter-cap threshold and one shield show both warnings while paused")
	player.use_mana(100)
	GlobalData.add_money(1)
	check(health_buy.disabled and health_buy.tooltip_text.contains("19 more"), "unaffordable item is disabled with missing balance")
	click(health_buy)
	check(health.current_health == 2 and GlobalData.money == 1, "disabled click spends and restores nothing")
	GlobalData.add_money(99)
	await settle()
	check(hud.coin_count.text == "100" and shop.coin_balance.text == "100 coins", "balance updates immediately while paused")

	health_buy.grab_focus()
	key(KEY_ENTER)
	check(GlobalData.money == 80 and health.current_health == 5 and hud.health_bar.value == 5 and shop.purchase_sfx.playing, "keyboard purchase restores 3 HP for 20 coins with HUD and audio feedback")
	key(KEY_ENTER)
	check(GlobalData.money == 80 and health.current_health == 5 and shop.error_sfx.playing and balance_events == [1, 100, 80], "rapid duplicate is rejected with error feedback and no extra charge")
	await settle()
	var purchase_checkpoint := _read_checkpoint()
	check(purchase_checkpoint.get("money") == 80 and purchase_checkpoint.get("health") == 5,
		"Regular purchase checkpoints the balance and healed HP together")
	click(shield_buy)
	check(GlobalData.money == 65 and player.current_shield == 4 and hud.shield_bar.value == 4, "Shield Recharge restores 3 shield for 15 coins")
	check(not hud.health_warning.visible and not hud.shield_warning.visible, "healing and recharging hide each warning while paused")
	click(mana_buy)
	check(GlobalData.money == 50 and player.current_mana == 120 and hud.mana_bar.value == 120 and hud.mana_value.text == "120/200" and hud.shield_value.text == "4/5" and hud.health_value.text == "5/6", "Mana Potion restores 20 mana for 15 coins")
	await tree.create_timer(0.37).timeout
	check(player.restore_mana(71.0), "mana restored on request below cap")
	click(health_buy)
	click(shield_buy)
	click(mana_buy)
	check(GlobalData.money == 0 and health.current_health == 6 and player.current_shield == 5 and player.current_mana == 200, "all three restorations clamp to their effective maximums")
	check(health_buy.disabled and shield_buy.disabled and mana_buy.disabled and tree.paused, "full-item purchases disable immediately while paused")
	await settle()

	click(shop.mysterious_tab)
	await settle()
	var movement := offer(shop.mysterious_contents, 0)
	var arcane := offer(shop.mysterious_contents, 1)
	var iron := offer(shop.mysterious_contents, 2)
	click(movement)
	await settle()
	check(shop.confirmation.visible and not shop.browsing.visible and shop.cancel_button.has_focus() and shop.confirmation_text.text.contains("30%") and shop.confirmation_text.text.contains("-1 max shield"), "confirmation presents benefit and sacrifice and defaults to Cancel")
	check(player.shield_sacrifice == 0 and manager.get_buff_level(&"movement_surge") == 0, "opening confirmation makes no changes")
	click(shop.cancel_button)
	await settle()
	check(not shop.confirmation.visible and shop.visible and movement.has_focus() and player.shield_sacrifice == 0, "Cancel restores the pact button focus and changes nothing")
	click(movement)
	await settle()
	key(KEY_ESCAPE)
	check(not shop.confirmation.visible and shop.visible and movement.has_focus() and player.shield_sacrifice == 0 and tree.paused, "Escape only cancels confirmation and returns focus")

	click(movement)
	await settle()
	player.base_max_shield = 1
	click(shop.confirm_button)
	check(player.shield_sacrifice == 0 and manager.get_buff_level(&"movement_surge") == 0 and movement.disabled and shop.feedback.text.contains("1 base shield"), "Confirm revalidates an unsafe sacrifice and applies nothing")
	player.base_max_shield = 5
	click(shop.regular_tab)
	click(shop.mysterious_tab)
	await settle()
	click(movement)
	await settle()
	click(shop.confirm_button)
	check(player.max_shield == 4 and player.current_shield == 4 and hud.shield_bar.value == 4 and hud.shield_bar.max_value == 4 and is_equal_approx(manager.get_speed_multiplier(), 1.3), "Movement Surge applies the speed buff and clamps shield value and cap")
	check(movement.disabled and movement.text == "Owned" and not manager.upgrade_buff(&"movement_surge") and hud.buff_list.get_child_count() == 2, "pact becomes owned, is single-level, and appears in BuffList")
	click(movement)
	check(player.shield_sacrifice == 1 and not shop.confirmation.visible, "owned pact cannot be repurchased")

	click(arcane)
	await settle()
	click(shop.confirm_button)
	check(health.max_health == 5 and health.current_health == 5 and hud.health_bar.max_value == 5 and hud.health_bar.value == 5 and manager.get_mana_regen_bonus() == 5.0, "Arcane Pact improves mana regen and immediately clamps HP and HUD")
	click(iron)
	await settle()
	click(shop.confirm_button)
	check(player.max_mana == 160 and player.current_mana == 160 and hud.mana_bar.max_value == 160 and hud.mana_bar.value == 160, "Iron Bargain immediately clamps mana and HUD")
	check(player.max_shield == 7 and player.current_shield == 7 and hud.shield_bar.max_value == 7 and GlobalData.money == 0 and hud.buff_list.get_child_count() == 4, "Iron Bargain adds 3 shield without spending coins and all 3 pacts appear in HUD")
	await settle()
	var frame := hud.get_node("StatusRow/StatFrame") as PanelContainer
	var grid := hud.buff_list as GridContainer
	var first := grid.get_child(0) as Control
	var fourth := grid.get_child(3) as Control
	var icon := first.get_child(0) as TextureRect
	check(grid.global_position.x >= frame.get_global_rect().end.x and grid.global_position.y == frame.global_position.y
			and fourth.global_position.x == first.global_position.x and fourth.global_position.y >= first.get_global_rect().end.y
			and grid.get_global_rect().end.x < hud.weapon_slot_1.global_position.x and frame.size.y < grid.size.y
			and icon.size.y == 23 and first.get_child(1).get_theme_font_size("font_size") == 10 and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"paused buff HUD wraps beside the stat frame with compact pixel icons and clears the weapon slots")
	var pact_checkpoint := _read_checkpoint()
	check(pact_checkpoint.get("mana_sacrifice") == 40 and pact_checkpoint.get("mana") == 160
			and pact_checkpoint.get("buffs", []).size() == 4,
		"pact checkpoints its sacrifice, affected current stat, and buff")

	var normal_shield := preload("res://scripts/Buffs/shield.tres")
	check(manager.add_buff(normal_shield) and player.max_shield == 9 and manager.upgrade_buff(normal_shield.buff_id) and player.max_shield == 11, "normal buff upgrades preserve the separate shield sacrifice")
	check(not player.can_sacrifice_stat(DungeonPlayer.Stat.SHIELD, 4) and player.can_sacrifice_stat(DungeonPlayer.Stat.SHIELD, 3), "shield floor ignores bonus capacity and permits the exact floor")
	check(not player.can_sacrifice_stat(DungeonPlayer.Stat.HEALTH, 4) and player.can_sacrifice_stat(DungeonPlayer.Stat.HEALTH, 3), "health floor is 2")
	check(not player.can_sacrifice_stat(DungeonPlayer.Stat.MANA, 111) and player.can_sacrifice_stat(DungeonPlayer.Stat.MANA, 110), "mana floor is 50")
	key(KEY_ESCAPE)
	await settle()
	check(tree.paused and pause.shop_button.has_focus() and not shop.visible, "Back after purchases still restores pause focus")
	key(KEY_ESCAPE)
	check(not tree.paused, "Resume still works")
	await _test_checkpoint(room, player, starting_id)
	await _test_legacy_saves()
	await _test_coins_and_combat()
	await _test_pedestals()
	await _test_new_game_and_restart()
	await _test_combat_buffs()
	await _test_projectile_buffs()
	await _test_boar_contact()
	await _test_game_over()
	await _test_picker_caps()
	if failures == 0:
		# Exercise the real Quit button after the completed checks.
		var quit_menu := tree.current_scene.get_node("PauseLayer/PauseScene")
		key(KEY_ESCAPE)
		await settle()
		click(quit_menu.quit_button)
		check(quit_menu.leaving_scene and quit_menu.click_sfx.playing, "Quit runs the existing click-and-exit flow")
	print("SHOP REGRESSION FINISHED. Failures: ", failures)
	if failures != 0:
		tree.quit(1)

func _read_checkpoint() -> Dictionary:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_checkpoint(data: Dictionary) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func _continue_from_menu() -> void:
	await load_room(MAIN_MENU)
	var menu := get_tree().current_scene
	click(menu.continue_button)
	await get_tree().scene_changed
	await settle()


func _test_checkpoint(room: Node, player: DungeonPlayer, starting_id: StringName) -> void:
	var tree := get_tree()
	var pause := room.get_node("PauseLayer/PauseScene")
	key(KEY_ESCAPE)
	await settle()
	player.health_component.take_damage(2)
	player.take_damage(player.current_shield - 2)
	player.use_mana(80)
	var saved_position := player.global_position
	GlobalData.add_money(21)
	await settle()
	var checkpoint := _read_checkpoint()
	check(checkpoint.get("money") == 21 and checkpoint.get("health") == 3
			and checkpoint.get("shield") == 2 and checkpoint.get("mana") == 80,
		"pickup checkpoint stores balance and live HP, shield, and mana")
	check(checkpoint.get("scene") == FIRST_ROOM and checkpoint.get("buffs", []).size() == 5
			and checkpoint.get("health_sacrifice") == 1 and checkpoint.get("shield_sacrifice") == 1
			and checkpoint.get("mana_sacrifice") == 40,
		"checkpoint stores the scene, buff IDs and levels, and all sacrifices")
	check(float(checkpoint.get("shield_recharge_remaining", 0)) > 0
			and is_equal_approx(float(checkpoint.get("mana_regen_delay", 0)), 0.75),
		"checkpoint stores recovery delays")
	click(pause.resume_button)
	await _continue_from_menu()
	player = GlobalData.player as DungeonPlayer
	check(tree.current_scene.scene_file_path == FIRST_ROOM and player.global_position.is_equal_approx(saved_position),
		"Continue opens the saved room and position")
	check(player.health_component.current_health == 3 and player.current_shield == 2 and player.current_mana == 80
			and player.health_component.max_health == 5 and player.max_shield == 11 and player.max_mana == 160,
		"Continue derives effective caps before restoring current values without a shield refill")
	check(GlobalData.money == 21 and player.shield_timer.time_left > 0
			and player.buff_manager.get_buff_level(&"shield_boost") == 2,
		"Continue restores coins, active shield recovery, and a normal buff's level")

	player.health_component.take_damage(1)
	await load_room(WORLD)
	player = GlobalData.player as DungeonPlayer
	check(player.health_component.current_health == 2 and player.max_shield == 11 and player.current_shield == 2
			and player.mana_sacrifice == 40 and GlobalData.money == 21 and player.shield_timer.time_left > 0
			and player.buff_manager.get_buff_level(&"movement_surge") == 1,
		"scene replacement carries live state newer than the last checkpoint")
	check(not player.global_position.is_equal_approx(saved_position) and not tree.paused
			and not tree.current_scene.has_node("UI/BuffSelection"),
		"World uses its authored spawn and keeps the completed First Room choice")
	check(_read_checkpoint().get("starting_buff_chosen") == true, "the starting choice persists in the room checkpoint")
	await _continue_from_menu()
	player = GlobalData.player as DungeonPlayer
	check(tree.current_scene.scene_file_path == WORLD and not tree.paused
			and not tree.current_scene.has_node("UI/BuffSelection")
			and player.buff_manager.get_buff_level(starting_id) == 1,
		"Continue preserves the starting buff and skips the completed picker")


func _test_legacy_saves() -> void:
	var tree := get_tree()
	var old_position := Vector2(322, 179)
	_write_checkpoint({"pos_x": old_position.x, "pos_y": old_position.y, "health": 100})
	await _continue_from_menu()
	var player := GlobalData.player as DungeonPlayer
	check(tree.current_scene.scene_file_path == WORLD and player.global_position.is_equal_approx(old_position)
			and player.health_component.current_health == 6 and player.current_shield == 5
			and player.current_mana == 200 and GlobalData.money == 0 and player.buff_manager.get_active_buffs().is_empty(),
		"legacy save restores coordinates and defaults absent shop fields")
	var picker := tree.current_scene.get_node("UI/BuffSelection")
	picker.select_buff(picker.choices[0])
	await picker.tree_exited
	_write_checkpoint({})
	await _continue_from_menu()
	player = GlobalData.player as DungeonPlayer
	var authored_room := preload(WORLD).instantiate()
	var authored_spawn: Vector2 = authored_room.get_node("Player").position
	authored_room.free()
	check(player.global_position.is_equal_approx(authored_spawn) and tree.paused,
		"minimal save without coordinates uses the existing room spawn")
	picker = tree.current_scene.get_node("UI/BuffSelection")
	picker.select_buff(picker.choices[0])
	await picker.tree_exited
	await settle()
	_write_checkpoint({
		"scene": FIRST_ROOM, "health": 99, "shield": 99, "mana": 999,
		"clear_rewards": {FIRST_ROOM: "pending"},
		"health_sacrifice": 1, "shield_sacrifice": 1, "mana_sacrifice": 40,
		"buffs": [
			{"id": "iron_bargain", "level": 9},
			{"id": "iron_bargain", "level": 1},
			{"id": "unknown_pact", "level": 1},
		],
	})
	await _continue_from_menu()
	player = GlobalData.player as DungeonPlayer
	check(player.health_component.current_health == 5 and player.current_shield == 7
			and player.current_mana == 160 and player.buff_manager.get_active_buffs().size() == 1
			and player.buff_manager.get_buff_level(&"iron_bargain") == 1,
		"load clamps stats and levels, and ignores duplicate or unknown buff IDs")
	check(tree.paused and tree.current_scene.has_node("PauseLayer/BuffSelection"), "Continue prompts for an outstanding First Room starting choice")
	var legacy_choice := await choose_starter()
	var reward := tree.current_scene.find_child("BuffSelection", true, false)
	check(tree.paused and is_instance_valid(reward) and player.buff_manager.get_buff_level(legacy_choice) == 1,
		"an outstanding room-clear reward waits for the starter before taking pause ownership")
	if is_instance_valid(reward):
		click(reward.cards.get_child(0))
		await reward.tree_exited
		await settle()
	check(not tree.paused, "gameplay resumes after both outstanding choices")


func _test_continue_without_save() -> void:
	await load_room(MAIN_MENU)
	var menu := get_tree().current_scene
	GlobalData.save_path = "%s.missing-%d" % [TEST_SAVE_PATH, OS.get_process_id()]
	click(menu.continue_button)
	await settle()
	GlobalData.save_path = TEST_SAVE_PATH
	var dialogs := menu.get_children().filter(func(child): return child is AcceptDialog)
	check(get_tree().current_scene == menu and dialogs.size() == 1
			and dialogs[0].visible and dialogs[0].dialog_text == "No save file found.",
		"Continue with no save stays on the menu and explains why")


func _test_coins_and_combat() -> void:
	var tree := get_tree()
	var room := tree.current_scene
	var player := GlobalData.player as DungeonPlayer
	var hud := room.get_node("CanvasLayer")
	var coin = preload("res://coin.tscn").instantiate()
	coin.coin_type = 2
	coin.position = player.position
	room.add_child(coin)
	coin.player = player
	coin._physics_process(0.0)
	coin.body_entered.emit(player)
	check(GlobalData.money == 5 and hud.coin_count.text == "5" and coin.collected,
		"magnet and body overlap credit one gold pickup")
	await settle()
	check(not is_instance_valid(coin) and _read_checkpoint().get("money") == 5,
		"coin is freed and its value is checkpointed")
	check(tree.get_nodes_in_group("enemy").is_empty(), "legacy cleared-room checkpoint restores an empty room")
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	enemy.position = Vector2(250, 210)
	room.add_child(enemy)
	seed(42)
	randf()
	var roll := randf()
	var expected := 1
	if roll >= 0.99:
		expected = 5
	elif roll >= 0.95:
		expected = 4
	elif roll >= 0.85:
		expected = 3
	elif roll >= 0.60:
		expected = 2
	seed(42)
	enemy.health_component.died.emit()
	enemy.health_component.died.emit()
	await settle()
	var drops := room.get_children().filter(func(node): return node.scene_file_path == "res://coin.tscn")
	check(not is_instance_valid(enemy) and drops.size() == expected, "repeated enemy death spawns only one drop burst")

	var shots: Array[Node] = []
	var track_shot := func(node: Node):
		if node is Bullet:
			shots.append(node)
	tree.node_added.connect(track_shot)
	var shot := InputEventMouseButton.new()
	shot.button_index = MOUSE_BUTTON_LEFT
	shot.position = Vector2(450, 180)
	shot.pressed = true
	tree.root.push_input(shot, true)
	await settle()
	check(not shots.is_empty(), "weapon still fires after loading the run")
	tree.node_added.disconnect(track_shot)


func _approach_pedestal(pedestal: Area2D) -> void:
	var player := GlobalData.player as DungeonPlayer
	player.global_position = pedestal.global_position + Vector2(0, 8)
	player.reset_physics_interpolation()
	await _wait_for_physics()


func _wait_for_physics() -> void:
	for i in range(4):
		await get_tree().physics_frame
	await settle()


func _test_pedestals() -> void:
	var tree := get_tree()
	GlobalData.start_new_run()
	await load_room(FIRST_ROOM)
	await choose_starter()
	var room := tree.current_scene
	room.get_node("Floor/Enemy3/HealthComponent").take_damage(100)
	var door := room.get_node("ShopEntrance")
	key(KEY_E)
	check(not room.has_node("DungeonTrader") and not door.prompt.visible and tree.current_scene == room,
		"First Room spawn is in the combat room, outside the corridor interaction")
	Input.action_press("move_up")
	for frame in range(70):
		await tree.physics_frame
		if door.prompt.visible:
			break
	Input.action_release("move_up")
	check(door.prompt.visible, "walking north from spawn crosses the tiled wall opening to the shop")
	if not door.prompt.visible:
		return
	key(KEY_E)
	await tree.scene_changed
	await settle()
	room = tree.current_scene
	var player := GlobalData.player as DungeonPlayer
	check(room.scene_file_path == SHOP_ROOM and player.global_position == room.get_node("PlayerSpawn").global_position,
		"the corridor enters the shop at its south spawn")
	var regular := room.get_node("DungeonTrader/HealthPedestal")
	var shield := room.get_node("DungeonTrader/ShieldPedestal")
	var pact := room.get_node("DungeonTrader/PactPedestal")
	var hud := room.get_node("CanvasLayer")
	await _approach_pedestal(shield)
	var hit := KinematicCollision2D.new()
	check(player.test_move(player.global_transform, Vector2.UP * 60, hit)
			and hit.get_collider() == room.get_node("DungeonTrader/Counter"), "the wooden counter blocks the player")
	await _approach_pedestal(regular)
	check(regular.prompt.visible and regular.price.text == "20 coins" and pact.price.text == "-1 max shield",
		"proximity shows the offer prompt alongside the coin and sacrifice labels")
	key(KEY_E)
	check(not regular.sold and regular.error_sfx.playing and regular.prompt.text.contains("full"),
		"a full-health pedestal attempt is rejected with feedback")
	player.health_component.take_damage(4)
	key(KEY_E)
	check(not regular.sold and regular.prompt.text.contains("20 more coins") and player.health_component.current_health == 2,
		"insufficient funds leave the offer and HP untouched")
	GlobalData.add_money(50)
	key(KEY_E)
	key(KEY_E)
	check(regular.sold and not regular.item_icon.visible and regular.price.text == "Sold"
			and GlobalData.money == 30 and player.health_component.current_health == 5
			and hud.coin_count.text == "30" and hud.health_bar.value == 5 and regular.purchase_sfx.playing,
		"the in-world potion restores HP, updates the HUD and sells exactly once")

	await _approach_pedestal(shield)
	player.take_damage(4)
	key(KEY_E)
	check(shield.sold and GlobalData.money == 15 and player.current_shield == 4
			and hud.shield_bar.value == 4, "the shield pedestal uses the shared shop purchase and HUD updates")

	await _approach_pedestal(pact)
	player.buff_manager.add_buff(pact.offer.buff)
	key(KEY_E)
	check(not pact.armed and not pact.sold and pact.prompt.text == "Already owned."
			and player.shield_sacrifice == 0, "a pact acquired elsewhere cannot be purchased at the pedestal")
	player.buff_manager.clear_buffs()
	key(KEY_E)
	check(pact.armed and not pact.sold and pact.prompt.text == "-1 Max Shield\n[E] Confirm"
			and player.shield_sacrifice == 0 and not tree.paused,
		"the first pact interaction warns of the permanent cost while gameplay continues")
	await settle()
	var prompt_rect: Rect2 = pact.prompt.get_global_rect()
	var clear_of_props := true
	for crate: Sprite2D in [room.get_node("Decor/WestCrate"), room.get_node("Decor/EastCrate")]:
		clear_of_props = clear_of_props and not prompt_rect.intersects(crate.global_transform * crate.get_rect())
	check(clear_of_props and prompt_rect.end.y < pact.global_position.y
			and not prompt_rect.has_point(room.get_node("Doorway").global_position)
			and pact.prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"armed prompt fits above the pedestal clear of both crates and the south doorway")
	var held_key := InputEventKey.new()
	held_key.physical_keycode = KEY_E
	held_key.keycode = KEY_E
	held_key.pressed = true
	held_key.echo = true
	tree.root.push_input(held_key, true)
	check(pact.armed and not pact.sold, "holding Interact cannot confirm a pact")
	player.global_position = Vector2(142, 49)
	for i in range(4):
		await tree.physics_frame
	await settle()
	check(not pact.armed and not pact.prompt.visible and player.shield_sacrifice == 0,
		"moving out of range cancels an armed pact")
	await _approach_pedestal(pact)
	key(KEY_E)
	key(KEY_ESCAPE)
	await settle()
	key(KEY_E)
	check(tree.paused and not pact.armed and not pact.sold,
		"the pause menu cancels arming and blocks pedestal interaction")
	key(KEY_ESCAPE)
	key(KEY_E)
	player.base_max_shield = 1
	key(KEY_E)
	check(not pact.sold and not pact.armed and player.shield_sacrifice == 0
			and pact.prompt.text.contains("1 base shield"), "the second press revalidates the safe floor")
	player.base_max_shield = 5
	key(KEY_E)
	key(KEY_E)
	check(pact.sold and not pact.item_icon.visible and player.shield_sacrifice == 1 and player.max_shield == 4
			and player.buff_manager.get_buff_level(&"movement_surge") == 1
			and hud.buff_list.get_child_count() == 1 and GlobalData.money == 15,
		"the confirmed pact applies its buff and shield sacrifice without spending coins")
	await settle()
	var stock: Dictionary = _read_checkpoint().get("sold_shop_stock", {})
	check(stock.size() == 3 and stock.get("first_room.movement_surge") == true,
		"all three sales are recorded in the run checkpoint")
	var shotgun_stand := room.get_node("ShotgunPedestal")
	var katana_stand := room.get_node("KatanaPedestal")
	await _approach_pedestal(shotgun_stand)
	key(KEY_E)
	check(not shotgun_stand.sold and GlobalData.money == 15 and player.weapon_slots[1] == null,
		"unaffordable weapon stays on its pedestal")
	GlobalData.add_money(75)
	key(KEY_E)
	key(KEY_E)
	check(shotgun_stand.sold and GlobalData.money == 50 and player.active_weapon_slot == 1
			and player.weapon_slots[1] == shotgun_stand.offer.weapon and player.gun.data == shotgun_stand.offer.weapon
			and _shows_weapon_art(hud.weapon_slot_2.get_node("Icon"), shotgun_stand.offer.weapon),
		"weapon purchase fills the empty slot, selects its HUD icon and charges only once")
	player.switch_weapon(0)
	var replaced := player.gun.data
	await _approach_pedestal(katana_stand)
	key(KEY_E)
	var pickups := room.get_children().filter(func(node): return node.scene_file_path == "res://scenes/pickup.tscn")
	check(katana_stand.sold and GlobalData.money == 15 and player.gun.data == katana_stand.offer.weapon
			and player.weapon_slots[1] == shotgun_stand.offer.weapon and pickups.size() == 1
			and pickups[0].data.weapon_data == replaced and pickups[0].global_position == katana_stand.global_position + Vector2.DOWN * 12
			and _shows_weapon_art(hud.weapon_slot_1.get_node("Icon"), katana_stand.offer.weapon),
		"full loadout swaps only the held weapon and drops a recoverable starter rifle in front")
	if pickups.size() == 1:
		player.global_position = pickups[0].global_position - player.get_node("CollisionShape2D").position
		await _wait_for_physics()
		key(KEY_E)
		await _wait_for_physics()
		check(player.gun.data == replaced and GlobalData.money == 15,
			"interacting with the dropped starter swaps it back for free")
		key(KEY_E)
		await _wait_for_physics()
		check(player.gun.data == katana_stand.offer.weapon and GlobalData.money == 15,
			"the displaced katana remains reachable at the same pickup position")
	await settle()
	await _continue_from_menu()
	room = tree.current_scene
	check(room.get_node("DungeonTrader/HealthPedestal").sold and room.get_node("DungeonTrader/ShieldPedestal").sold
			and room.get_node("DungeonTrader/PactPedestal").sold and GlobalData.money == 15,
		"Continue restores sold stock and the remaining balance")
	check(room.get_node("ShotgunPedestal").sold and room.get_node("KatanaPedestal").sold
			and GlobalData.player.gun.data.id == "long_katana" and GlobalData.player.weapon_slots[1].id == "shotgun",
		"Continue restores both purchased weapons, the equipped slot and sold pedestals")
	var exit_door := room.get_node("Doorway")
	player = GlobalData.player as DungeonPlayer
	player.global_position = exit_door.global_position - player.get_node("CollisionShape2D").position
	await _wait_for_physics()
	key(KEY_E)
	await tree.scene_changed
	await settle()
	room = tree.current_scene
	player = GlobalData.player as DungeonPlayer
	check(room.scene_file_path == FIRST_ROOM and player.global_position == room.get_node("ShopReturnSpawn").position
			and not room.get_node("ShopEntrance").prompt.visible, "south exit returns outside the combat-room corridor")
	check(not room.has_node("Floor/Enemy3") and tree.get_nodes_in_group("enemy").size() == 4,
		"shop visit and Continue preserve the defeated boar and the four surviving boars")
	check(GlobalData.money == 15 and player.shield_sacrifice == 1
			and player.buff_manager.get_buff_level(&"movement_surge") == 1
			and GlobalData.sold_shop_stock.size() == 5 and player.gun.data.id == "long_katana" and player.weapon_slots[1].id == "shotgun", "the doorway retains coins, pact, sacrifice and sold stock")
	await _continue_from_menu()
	check(tree.current_scene.scene_file_path == FIRST_ROOM
			and GlobalData.player.global_position == tree.current_scene.get_node("ShopReturnSpawn").position,
		"Continue uses the combat-room doorway checkpoint")


func _test_new_game_and_restart() -> void:
	var tree := get_tree()
	var player := GlobalData.player as DungeonPlayer
	var pause := tree.current_scene.get_node("PauseLayer/PauseScene")
	key(KEY_ESCAPE)
	await settle()
	click(pause.restart_button)
	await tree.scene_changed
	await settle()
	player = GlobalData.player as DungeonPlayer
	check(tree.current_scene.scene_file_path == FIRST_ROOM and tree.paused and tree.current_scene.has_node("PauseLayer/BuffSelection") and _run_is_fresh(player),
		"Restart reloads the room and clears coins, buffs, sacrifices, and current damage")
	check(not GlobalData.is_shop_stock_sold(&"first_room.health_potion")
			and not GlobalData.is_shop_stock_sold(&"first_room.movement_surge")
			and _read_checkpoint().get("sold_shop_stock", {}).is_empty(), "Restart replenishes the trader's stock")
	check(_read_checkpoint().get("money") == 0 and _read_checkpoint().get("buffs", []).is_empty(),
		"Restart replaces the disk checkpoint with a fresh run")
	check(tree.get_nodes_in_group("enemy").size() == 5 and GlobalData.defeated_enemies.is_empty(), "Restart restores all five boar spawns")
	check(player.weapon_slots[1] == null and player.gun.data.id == "auto_rifle" and player.active_weapon_slot == 0
			and not GlobalData.is_shop_stock_sold(&"shop_room.shotgun"), "Restart resets loadout and weapon stock")
	var restart_choice := await choose_starter()
	player.equip_weapon(preload("res://scripts/weapons/data/shotgun.tres"))
	GlobalData.mark_shop_stock_sold(&"shop_room.shotgun")
	check(not tree.paused and player.buff_manager.get_buff_level(restart_choice) == 1, "Restart grants a fresh normal buff selection")

	player.apply_shop_pact(preload("res://scripts/Buffs/movement_surge.tres"), DungeonPlayer.Stat.SHIELD, 1)
	player.apply_shop_pact(preload("res://scripts/Buffs/arcane_pact.tres"), DungeonPlayer.Stat.HEALTH, 1)
	player.apply_shop_pact(preload("res://scripts/Buffs/iron_bargain.tres"), DungeonPlayer.Stat.MANA, 40)
	GlobalData.add_money(17)
	GlobalData.mark_shop_stock_sold(&"first_room.health_potion")
	GlobalData.starting_buff_chosen = true
	tree.current_scene.get_node("Floor/Enemy3/HealthComponent").take_damage(100)
	AudioServer.set_bus_volume_db(0, -4.0)
	await settle()
	await load_room(MAIN_MENU)
	GlobalData.is_loading_save = true
	GlobalData.has_saved_position = true
	GlobalData.saved_position = Vector2(299, 177)
	check(tree.current_scene.scene_file_path == MAIN_MENU and tree.current_scene.start_button.has_focus(),
		"New Game receives keyboard focus on Main Menu entry")
	key(KEY_ENTER)
	await tree.scene_changed
	await settle()
	player = GlobalData.player as DungeonPlayer
	check(tree.current_scene.scene_file_path == FIRST_ROOM and tree.paused
			and _run_is_fresh(player) and AudioServer.get_bus_volume_db(0) == -4.0,
		"New Game opens First Room, clears the previous run and keeps volume")
	check(not GlobalData.is_shop_stock_sold(&"first_room.health_potion")
			and _read_checkpoint().get("sold_shop_stock", {}).is_empty(), "New Game replenishes the trader stock")
	check(tree.get_nodes_in_group("enemy").size() == 5 and GlobalData.defeated_enemies.is_empty(), "New Game restores all five boar spawns")
	check(player.weapon_slots[1] == null and player.gun.data.id == "auto_rifle" and player.active_weapon_slot == 0
			and not GlobalData.is_shop_stock_sold(&"shop_room.shotgun"), "New Game resets loadout and weapon stock")
	var authored_room := preload(FIRST_ROOM).instantiate()
	var authored_spawn: Vector2 = authored_room.get_node("Player").position
	authored_room.free()
	var checkpoint := _read_checkpoint()
	check(player.global_position.is_equal_approx(authored_spawn) and checkpoint.get("scene") == FIRST_ROOM
			and checkpoint.get("money") == 0 and checkpoint.get("buffs", []).is_empty()
			and checkpoint.get("health_sacrifice") == 0 and checkpoint.get("shield_sacrifice") == 0
			and checkpoint.get("mana_sacrifice") == 0,
		"New Game uses the authored spawn and replaces the old checkpoint with First Room")
	var picker := tree.current_scene.get_node("PauseLayer/BuffSelection")
	key(KEY_ESCAPE)
	check(tree.paused and picker.visible and picker.cards.get_child(0).has_focus()
			and not tree.current_scene.get_node("PauseLayer/PauseScene").visible,
		"New Game opens the starting picker with keyboard focus and Escape keeps gameplay paused")
	var starting_id: StringName = picker.choices[1].buff_id
	var seen := {}
	var fits: bool = picker.get_viewport_rect().encloses(picker.get_node("Center/Panel").get_global_rect())
	for i in picker.choices.size():
		var buff: BuffData = picker.choices[i]
		var card := picker.cards.get_child(i) as Button
		seen[buff.buff_id] = true
		fits = fits and BuffManager.CLEAR_POOL.has(buff) and card.focus_mode == Control.FOCUS_ALL
		fits = fits and card.get_node("Content/Icon").texture == buff.buff_icon
		fits = fits and card.get_node("Content/Icon").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		fits = fits and card.get_node("Content/Name").text == buff.buff_name
		fits = fits and card.get_node("Content/Level").text == "New"
		var effect := card.get_node("Content/Effect") as Label
		fits = fits and effect.text == buff.description and card.get_global_rect().encloses(effect.get_global_rect())
	check(seen.size() == 3 and fits, "three distinct normal buff cards show their icon, name, status and effect inside the viewport")
	key(KEY_RIGHT)
	check(picker.cards.get_child(1).has_focus(), "keyboard navigation moves to the second buff card")
	key(KEY_ENTER)
	picker.cards.get_child(0).pressed.emit()
	await picker.tree_exited
	await settle()
	check(not tree.paused and GlobalData.starting_buff_chosen and player.buff_manager.get_buff_level(starting_id) == 1
			and player.buff_manager.get_active_buffs().size() == 1 and tree.current_scene.get_node("CanvasLayer").buff_list.get_child_count() == 1,
		"choosing one starting buff updates the HUD, guards a second press and resumes First Room")
	await _continue_from_menu()
	player = GlobalData.player as DungeonPlayer
	check(tree.current_scene.scene_file_path == FIRST_ROOM and player.global_position.is_equal_approx(authored_spawn)
			and GlobalData.starting_buff_chosen and player.buff_manager.get_buff_level(starting_id) == 1
			and not tree.current_scene.has_node("PauseLayer/BuffSelection") and not tree.paused,
		"Continue restores the chosen starting buff in First Room without prompting again")


func _test_combat_buffs() -> void:
	var tree := get_tree()
	var player := GlobalData.player as DungeonPlayer
	var manager := player.buff_manager
	var room := tree.current_scene
	var shop := room.get_node("PauseLayer/PauseScene").shop_menu as Control
	manager.clear_buffs() # Test pact prerequisites independently of the random starter.
	var spike := preload("res://scripts/Shop/spike_guard.tres")
	var meteor := preload("res://scripts/Shop/meteor.tres")
	var reflect := preload("res://scripts/Shop/reflect.tres")
	var trade := preload("res://scripts/Shop/reflect_exchange.tres")
	var pause_ui := room.get_node("PauseLayer/PauseScene")
	pause_ui.pause()
	pause_ui.shop_button.pressed.emit()
	shop.mysterious_tab.pressed.emit()
	check(not shop.mysterious_contents.get_child(3).visible and not spike.purchase(player).is_empty(),
		"Spike Guard is hidden and rejected without Shockwave")
	manager.add_buff(preload("res://scripts/Buffs/shockwave.tres"))
	shop.regular_tab.pressed.emit()
	shop.mysterious_tab.pressed.emit()
	check(shop.mysterious_contents.get_child(3).visible and spike.purchase(player).is_empty()
			and player.health_sacrifice == 1, "Shockwave unlocks Spike Guard for one maximum HP")
	shop.request_back()
	pause_ui.resume()
	var enemy := room.get_node("Floor/Enemy") as CharacterBody2D
	enemy.global_position = player.global_position + Vector2(32, 0)
	enemy.set_physics_process(false)
	enemy.health_component.set_maximum_health(100)
	enemy.health_component.heal(100)
	player.take_damage(1)
	player.take_damage(1)
	await tree.create_timer(0.5).timeout
	check(enemy.health_component.current_health == 82, "two on-hit crosses stack three boosted pulses each")
	GlobalData.add_money(20)
	check(reflect.purchase(player).is_empty() and GlobalData.money == 0 and reflect.price() * 2 == reflect.coin_cost,
		"Reflect costs half its base price")
	var shot := preload("res://scenes/bullet.tscn").instantiate() as Bullet
	shot.hostile = true
	shot.target_position = Vector2.RIGHT
	player.gun.attack_phase = Weapon.AttackPhase.STRIKE
	player.gun._on_strike_overlap(shot)
	check(not shot.hostile and shot.target_position == Vector2.LEFT, "melee Reflect reverses a hostile bullet")
	shot.hostile = true
	shot.data = preload("res://scripts/weapons/data/laser_gun.tres")
	player.gun._on_strike_overlap(shot)
	check(shot.hostile, "Reflect leaves laser projectiles hostile")
	shot.free()
	player.gun.cancel_attack()
	check(trade.purchase(player).is_empty() and manager.get_buff_level(&"reflect") == 0
			and manager.get_buff_level(&"meteor") == 1 and player.mana_sacrifice == 0
			and player.health_sacrifice == 1 and player.shield_sacrifice == 0, "Reflect exchange grants Meteor without a stat cost")
	check(not meteor.purchase(player).is_empty(), "exchanged Meteor blocks duplicate stat purchases")
	enemy.add_to_group("boss")
	player.tick_run_buffs(29)
	check(is_equal_approx(player.meteor_remaining, 1.0), "Meteor waits for the full 30-second cycle")
	player.tick_run_buffs(1)
	var impact := room.get_child(-1) as Node2D
	check(impact != null and impact.global_position == enemy.global_position and player.meteor_remaining == 30,
		"the expired cycle drops the meteor on the boss and restarts")
	enemy.remove_from_group("boss")
	check(player.get_viewport_rect().has_point(player.get_canvas_transform() * player.meteor_target()),
		"ordinary meteor targets lie inside the current viewport")
	player.tick_run_buffs(11)
	for i in 4:
		GlobalData.enemy_defeated.emit()
	check(player.meteor_remaining == 19 and player.meteor_kills == 4, "four kills retain the meteor countdown")
	GlobalData.enemy_defeated.emit()
	check(player.meteor_remaining == 30 and player.meteor_kills == 0 and room.get_child(-1) == impact,
		"the fifth kill resets the timer without spawning a meteor")
	manager.add_buff(preload("res://scripts/Buffs/life.tres"))
	manager.upgrade_buff(&"life")
	manager.add_buff(preload("res://scripts/Buffs/protection.tres"))
	player.health_component.take_damage(2)
	var hp := player.health_component.current_health
	player.tick_run_buffs(5)
	check(player.health_component.max_health == player.base_max_health + 1
			and player.health_component.current_health == hp + 1 and player.max_shield == 6,
		"Life stacks with sacrifices, heals slowly and Protection raises shield")
	player.take_damage(1)
	check(player.shield_timer.time_left <= player.shield_recharge_delay / 1.5, "Protection accelerates shield recovery")
	GlobalData.enemy_defeated.emit()
	GlobalData.save_game()
	await _continue_from_menu()
	player = GlobalData.player as DungeonPlayer
	manager = player.buff_manager
	check(manager.get_buff_level(&"life") == 2 and manager.get_buff_level(&"spike_guard") == 1
			and manager.get_buff_level(&"meteor") == 1 and manager.get_buff_level(&"reflect") == 0
			and player.meteor_kills == 1 and absf(player.meteor_remaining - 25) < 0.6 and player.health_sacrifice == 1,
		"Continue restores levels, exchanged ownership, sacrifices and meteor progress")
	await load_room(SHOP_ROOM)
	check(GlobalData.player.meteor_kills == 1 and GlobalData.player.buff_manager.get_buff_level(&"meteor") == 1,
		"room handoff carries meteor progress")
	await load_room(FIRST_ROOM)
	for foe in tree.get_nodes_in_group("enemy"):
		foe.health_component.died.emit()
	await settle()
	var picker := tree.current_scene.find_child("BuffSelection", true, false)
	check(is_instance_valid(picker) and tree.paused and picker.clear_options.size() == 3,
		"last enemy death opens eligible normal buff choices")
	if is_instance_valid(picker):
		var choice: BuffData = picker.clear_options[0]
		var old_level: int = GlobalData.player.buff_manager.get_buff_level(choice.buff_id)
		picker.select_buff(choice)
		await picker.tree_exited
		check(GlobalData.player.buff_manager.get_buff_level(choice.buff_id) == old_level + 1
				and GlobalData.clear_rewards[FIRST_ROOM] == "claimed", "level clear grants or upgrades the selected buff once")
	var earned: Array = GlobalData.player.capture_run_state().buffs
	for doorway_name in ["ShopEntrance", "Doorway"]:
		var doorway := tree.current_scene.get_node(NodePath(doorway_name))
		GlobalData.player.global_position = doorway.global_position - GlobalData.player.get_node("CollisionShape2D").position
		await _wait_for_physics()
		key(KEY_E)
		await tree.scene_changed
		await settle()
	check(tree.current_scene.scene_file_path == FIRST_ROOM and tree.get_nodes_in_group("enemy").is_empty()
			and not tree.paused and GlobalData.clear_rewards.get(FIRST_ROOM) == "claimed"
			and GlobalData.player.capture_run_state().buffs == earned,
		"return through the shop doorway preserves the clear and never grants a second reward")
	var pause := tree.current_scene.get_node("PauseLayer/PauseScene")
	key(KEY_ESCAPE)
	await settle()
	click(pause.restart_button)
	await tree.scene_changed
	await settle()
	player = GlobalData.player as DungeonPlayer
	check(_run_is_fresh(player) and player.meteor_remaining == 30 and player.meteor_kills == 0
			and GlobalData.clear_rewards.is_empty(), "Restart clears new buffs, meteor progress and room rewards")
	await choose_starter()
	check(meteor.purchase(player).is_empty() and player.mana_sacrifice == 30, "Meteor accepts its ordinary max mana sacrifice")
	await load_room(MAIN_MENU)
	click(tree.current_scene.start_button)
	await tree.scene_changed
	await settle()
	check(_run_is_fresh(GlobalData.player), "New Game clears the paid Meteor and sacrifice")
	await choose_starter()

func _test_projectile_buffs() -> void:
	var player := GlobalData.player as DungeonPlayer
	var room := get_tree().current_scene
	var manager := player.buff_manager
	var shot := preload("res://scenes/bullet.tscn").instantiate() as Bullet
	shot.global_position = Vector2(45, 65)
	shot.target_position = Vector2.LEFT
	shot.bounces_left = 2
	room.add_child(shot)
	for i in 12:
		await get_tree().physics_frame
		if not is_instance_valid(shot) or shot.target_position.x > 0:
			break
	check(is_instance_valid(shot) and shot.target_position.dot(Vector2.RIGHT) > 0.99 and shot.bounces_left == 1,
		"bullet rebounds from First Room's west wall and consumes exactly one bounce")
	if is_instance_valid(shot):
		var target := room.get_node("Floor/Enemy") as Node2D
		shot.global_position = target.global_position - Vector2(3, 0)
		shot.hit_enemy(target)
		check(shot.target_position.dot(Vector2.LEFT) > 0.99 and shot.bounces_left == 0, "enemy contact consumes the second bounce")
		shot.queue_free()
	manager.add_buff(preload("res://scripts/Buffs/deadly_strike.tres"))
	manager.upgrade_buff(&"deadly_strike")
	manager.add_buff(preload("res://scripts/Buffs/ricochet.tres"))
	var shotgun := preload("res://scripts/weapons/data/shotgun.tres")
	player.gun.set_weapon_data(shotgun)
	var pellets: Array[Bullet] = []
	var record := func(node: Node):
		if node is Bullet:
			pellets.append(node)
	get_tree().node_added.connect(record)
	seed(449)
	for i in 10:
		player.restore_mana(100)
		player.gun._fire_ranged_shot(true)
	get_tree().node_added.disconnect(record)
	var critical := pellets.any(func(b): return b.damage == 2 * shotgun.damage)
	var ordinary := pellets.any(func(b): return b.damage == shotgun.damage)
	check(pellets.size() == 50 and critical and ordinary and pellets[0].bounces_left == 1,
		"shotgun volleys carry Ricochet and roll both critical and ordinary pellet damage")
	check(is_equal_approx(absf(pellets[0].target_position.angle_to(pellets[4].target_position)), deg_to_rad(24)),
		"Deadly Strike level two narrows the shotgun fan from 40 to 24 degrees")
	for pellet in pellets:
		pellet.queue_free()
	var crate := room.get_node("Floor/Crate")
	var baseline := 0
	var boosted := 0
	var weapons := 0
	seed(77)
	for i in 1000:
		if crate.roll_loot(0) != null:
			baseline += 1
	seed(77)
	for i in 1000:
		var item: ItemData = crate.roll_loot(3)
		if item != null:
			boosted += 1
			if item.item_type == ItemData.Type.GUN:
				weapons += 1
	check(boosted - weapons > baseline and weapons > 0, "Looting increases potion drops and adds weapon drops")

func _test_boar_contact() -> void:
	GlobalData.start_new_run()
	await load_room(FIRST_ROOM)
	await choose_starter()
	var tree := get_tree()
	var room := tree.current_scene
	var player := GlobalData.player as DungeonPlayer
	player.buff_manager.clear_buffs()
	player.buff_manager.add_buff(preload("res://scripts/Buffs/shockwave.tres"))
	var attacker := room.get_node("Floor/Enemy")
	var witness := room.get_node("Floor/Enemy2")
	witness.set_physics_process(false)
	witness.global_position = player.global_position - Vector2(36, 0)
	attacker.global_position = player.global_position + Vector2(17, 0)
	var waves: Array[int] = []
	room.child_entered_tree.connect(func(node: Node):
		if node.get_script() == DungeonPlayer.IMPACT and node.shape == DungeonPlayer.IMPACT.Shape.WAVE:
			waves.append(node.get_instance_id()))
	var hp := player.health_component.current_health
	var shield := player.current_shield
	var enemy_hp: int = attacker.health_component.current_health
	var witness_hp: int = witness.health_component.current_health
	for tick in 8:
		await tree.physics_frame
	check(attacker.player_in_attack_range and player.current_shield == shield - 1
			and player.health_component.current_health == hp and waves.size() == 1
			and attacker.health_component.current_health == enemy_hp - 2
			and witness.health_component.current_health == witness_hp - 2,
		"First Room boar contact absorbs one shield and releases one damaging Shockwave")
	player._set_shield(0, player.max_shield)
	for tick in ceili(attacker.attack_cooldown * Engine.physics_ticks_per_second) + 5:
		await tree.physics_frame
	check(player.health_component.current_health == hp - 1 and waves.size() == 2
			and attacker.health_component.current_health == enemy_hp - 4
			and witness.health_component.current_health == witness_hp - 4,
		"boar contact after cooldown costs one HP and releases one more damaging Shockwave")

func _test_picker_caps() -> void:
	var records: Array[Dictionary] = []
	for buff in BuffManager.CLEAR_POOL:
		var level := buff.max_level - 1 if buff.buff_id == &"life" else buff.max_level
		records.append({"id": String(buff.buff_id), "level": level})
	_write_checkpoint({"scene": FIRST_ROOM, "buffs": records, "starting_buff_chosen": false})
	await _continue_from_menu()
	var picker := get_tree().current_scene.get_node("PauseLayer/BuffSelection")
	var button := picker.cards.get_child(0) as Button
	check(picker.choices.size() == 1 and picker.choices[0].buff_id == &"life"
			and button.get_node("Content/Level").text == "Lv. 2 → Lv. 3", "capped buffs are excluded and Life shows its next level")
	click(button)
	await picker.tree_exited
	await settle()
	check(GlobalData.player.buff_manager.get_buff_level(&"life") == 3 and not get_tree().paused
			and GlobalData.starting_buff_chosen, "the starting picker applies an upgrade and releases gameplay")
	await _continue_from_menu()
	check(GlobalData.player.buff_manager.get_buff_level(&"life") == 3 and not get_tree().paused
			and not get_tree().current_scene.has_node("PauseLayer/BuffSelection"), "Continue restores the chosen upgrade without prompting")

func _run_is_fresh(player: DungeonPlayer) -> bool:
	return GlobalData.money == 0 and not GlobalData.starting_buff_chosen and not GlobalData.is_loading_save \
		and player.buff_manager.get_active_buffs().is_empty() \
		and player.health_sacrifice == 0 and player.shield_sacrifice == 0 and player.mana_sacrifice == 0 \
		and player.health_component.current_health == 6 and player.current_shield == 5 and player.current_mana == 200

func _test_game_over() -> void:
	var tree := get_tree()
	for source: String in [FIRST_ROOM, SHOP_ROOM]:
		GlobalData.start_new_run()
		await load_room(source)
		if source == FIRST_ROOM:
			await choose_starter()
		GlobalData.add_money(30)
		GlobalData.save_game()
		var player := GlobalData.player as DungeonPlayer
		GlobalData.request_save()
		player.take_damage(player.current_shield + player.health_component.current_health)
		player.health_component.take_damage(1)
		key(KEY_ESCAPE)
		await tree.scene_changed
		await settle()
		var screen := tree.current_scene
		check(tree.paused and screen.scene_file_path == "res://scenes/game_over.tscn" and screen.get_node("%Restart").has_focus(), "lethal hit opens a focused game-over screen from " + source)
		key(KEY_ESCAPE)
		check(tree.paused and not FileAccess.file_exists(TEST_SAVE_PATH) and not GlobalData.load_save_data(), "Escape and deferred saves cannot revive a dead run")
		if source == FIRST_ROOM:
			click(screen.get_node("%Restart"))
			await tree.scene_changed
			await settle()
			check(tree.current_scene.scene_file_path == FIRST_ROOM and GlobalData.money == 0 and not GlobalData.run_finished and GlobalData.player.health_component.current_health == GlobalData.player.health_component.max_health and tree.paused, "game-over Restart restores full health and opens a fresh starting picker")
			await choose_starter()
		else:
			click(screen.get_node("%MainMenu"))
			await tree.scene_changed
			await settle()
			check(tree.current_scene.scene_file_path == MAIN_MENU and not tree.paused, "game-over Main Menu releases pause")
			click(tree.current_scene.continue_button)
			await settle()
			check(tree.current_scene.scene_file_path == MAIN_MENU and not tree.current_scene.find_children("*", "AcceptDialog", true, false).is_empty(), "Continue after death stays on the menu")
	GlobalData.start_new_run()

func _test_screen_mode() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP native window modes require a windowing display")
		return
	var window := get_window()
	var original_mode := window.mode
	var original_size := window.size
	window.mode = Window.MODE_WINDOWED
	await load_room(MAIN_MENU)
	var menu := get_tree().current_scene
	click(menu.settings_button)
	await settle()
	var settings := menu.get_node("SettingsMenu")
	var selector: OptionButton = settings.screen_mode
	check(selector.get_selected_id() == Window.MODE_WINDOWED, "Settings initially reports the actual windowed mode")
	get_tree().paused = true
	selector.grab_focus()
	key(KEY_ENTER)
	await settle()
	selector.get_popup().set_focused_item(selector.get_item_index(Window.MODE_FULLSCREEN))
	key(KEY_ENTER)
	await settle()
	check(DisplayServer.window_get_mode(window.get_window_id()) == DisplayServer.WINDOW_MODE_FULLSCREEN and selector.get_selected_id() == Window.MODE_FULLSCREEN, "keyboard selection immediately enters native fullscreen while paused")
	var caption_stable := true
	for frame in 12:
		await get_tree().process_frame
		caption_stable = caption_stable and selector.text == "Fullscreen" and selector.selected == selector.get_item_index(Window.MODE_FULLSCREEN)
	check(caption_stable and DisplayServer.window_get_mode(window.get_window_id()) == DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen caption and selection survive native window notifications")
	get_tree().paused = false
	click(menu.get_node("SettingsMenu/VBoxContainer/Button"))
	click(menu.settings_button)
	await settle()
	check(settings.is_visible_in_tree() and selector.text == "Fullscreen", "reopening Settings retains the visible Fullscreen caption")
	await load_room(MAIN_MENU)
	menu = get_tree().current_scene
	click(menu.settings_button)
	await settle()
	settings = menu.get_node("SettingsMenu")
	selector = settings.screen_mode
	check(selector.get_selected_id() == Window.MODE_FULLSCREEN and selector.text == "Fullscreen", "a fresh Settings scene reads fullscreen from the window")
	selector.grab_focus()
	key(KEY_ENTER)
	await settle()
	selector.get_popup().set_focused_item(selector.get_item_index(Window.MODE_WINDOWED))
	key(KEY_ENTER)
	await settle()
	check(DisplayServer.window_get_mode(window.get_window_id()) == DisplayServer.WINDOW_MODE_WINDOWED and selector.get_selected_id() == Window.MODE_WINDOWED and selector.text == "Windowed", "Windowed restores the native window and matching option")
	check(window.size == original_size, "round trip preserves the previous windowed dimensions")
	# Exercise the displayed rows with pointer input independently of their enum IDs.
	for row in selector.item_count:
		click(selector)
		await settle()
		var popup := selector.get_popup()
		await get_tree().create_timer(0.25).timeout
		var bounds := popup.get_visible_rect().size
		var point := Vector2(bounds.x / 2, bounds.y * (row + 0.5) / selector.item_count)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		popup.push_input(motion, true)
		print('TRACE ', row, ' open ',popup.visible, ' bounds ',bounds,' point ',point,' focused ', popup.get_focused_item())
		for down: bool in [true, false]:
			var press := InputEventMouseButton.new()
			press.position = point
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = down
			popup.push_input(press, true)
		await get_tree().create_timer(1.1).timeout
		print('TRACE selected ',selector.selected,' caption ',selector.text,' window ',window.mode,' open ',popup.visible)
		var label := selector.get_item_text(row)
		var expected := DisplayServer.WINDOW_MODE_FULLSCREEN if label == "Fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
		check(not popup.visible and selector.text == label and selector.selected == row and DisplayServer.window_get_mode(window.get_window_id()) == expected, "clicking %s keeps both the visible caption and native mode after the acknowledgement timeout" % label)
	window.mode = original_mode
