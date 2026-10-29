
extends Node

const TEST_BUFF = preload("res://scripts/Buffs/test_buff.tres")

@onready var buff_manager: BuffManager = $"../BuffManager"


func _ready() -> void:
	print("=== BUFF SYSTEM TEST ===")

	print("Buff Added: ", buff_manager.add_buff(TEST_BUFF))

	print("Starting Level: ",
		buff_manager.get_buff_level(TEST_BUFF.buff_id))

	print("Upgrade 1: ",
		buff_manager.upgrade_buff(TEST_BUFF.buff_id))

	print("Upgrade 2: ",
		buff_manager.upgrade_buff(TEST_BUFF.buff_id))

	print("Upgrade Beyond Max: ",
		buff_manager.upgrade_buff(TEST_BUFF.buff_id))

	print("Final Level: ",
		buff_manager.get_buff_level(TEST_BUFF.buff_id))

	print("Active Buffs: ",
		buff_manager.get_active_buffs().size())

	buff_manager.clear_buffs()

	print("Level After Reset: ",
		buff_manager.get_buff_level(TEST_BUFF.buff_id))
