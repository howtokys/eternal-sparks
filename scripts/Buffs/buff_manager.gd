extends Node
class_name BuffManager

signal buff_added (buff : BuffData)
signal buff_upgraded(buff: BuffData, level: int)
signal buffs_cleared

var active_buffs: Dictionary = {}

#give players new buff
func add_buff(buff: BuffData) -> bool:
	if buff == null or buff.buff_id ==&"":
		push_warning("Cannot add an invalid buff . ")
		return false
		
	if active_buffs.has(buff.buff_id):
		return false 
	active_buffs[buff.buff_id]={
		"data": buff,
		"level": 1
	}
	buff_added.emit(buff)
	return true
	
	
# to upgrade existing buff
func upgrade_buff(buff_id: StringName) -> bool:
	if not active_buffs.has(buff_id):
		return false

	var entry: Dictionary = active_buffs[buff_id]
	var buff: BuffData = entry["data"]
	var current_level: int = entry["level"]

	if current_level >= maxi(1, buff.max_level):
		return false

	entry["level"] = current_level + 1
	active_buffs[buff_id] = entry

	buff_upgraded.emit(buff, entry["level"])
	return true


# Check the level of a buff
func get_buff_level(buff_id: StringName) -> int:
	if active_buffs.has(buff_id):
		return active_buffs[buff_id]["level"]

	return 0


# Get all active buffs
func get_active_buffs() -> Array[BuffData]:
	var buffs: Array[BuffData] = []

	for entry in active_buffs.values():
		buffs.append(entry["data"])

	return buffs


# Remove all buffs
func clear_buffs() -> void:
	active_buffs.clear()
	buffs_cleared.emit()
