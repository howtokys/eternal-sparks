
extends Node2D


func _ready() -> void:
	call_deferred("restore_and_upgrade_buffs")


func restore_and_upgrade_buffs() -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error("Player not found in Second Room!")
		return

	var manager: BuffManager = player.get_node_or_null(
        "BuffManager"
	) as BuffManager

	if manager == null:
		push_error("BuffManager not found!")
		return

	for saved in GlobalData.room_buff_snapshot:
		var buff: BuffData = saved["resource"]
		var previous_level: int = saved["level"]

		# Restore the buff if the new player doesn't have it
		if manager.get_buff_level(buff.buff_id) == 0:
			if not manager.add_buff(buff):
				push_error("Could not restore buff: " + buff.buff_id)
				continue

		# Advance one level beyond the previous room
		var target_level: int = previous_level + 1

		while manager.get_buff_level(buff.buff_id) < target_level:
			if not manager.upgrade_buff(buff.buff_id):
				break  # Reached maximum level

		print(
			"Buff: ", buff.buff_name,
			" | Level: ", manager.get_buff_level(buff.buff_id)
		)

	GlobalData.room_buff_snapshot.clear()
