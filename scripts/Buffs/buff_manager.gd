extends Node
class_name BuffManager

signal buff_added (buff : BuffData)
signal buff_upgraded(buff: BuffData, level: int)
signal buffs_cleared

const KNOWN_BUFFS: Array[BuffData] = [
	preload("res://scripts/Buffs/speed_buff.tres"),
	preload("res://scripts/Buffs/shield.tres"),
	preload("res://scripts/Buffs/mana_regen_buff.tres"),
	preload("res://scripts/Buffs/movement_surge.tres"),
	preload("res://scripts/Buffs/arcane_pact.tres"),
	preload("res://scripts/Buffs/iron_bargain.tres"),
	preload("res://scripts/Buffs/spike_guard.tres"),
	preload("res://scripts/Buffs/meteor.tres"),
]

const CLEAR_POOL: Array[BuffData] = [
	preload("res://scripts/Buffs/ricochet.tres"),
	preload("res://scripts/Buffs/reflect.tres"),
	preload("res://scripts/Buffs/deadly_strike.tres"),
	preload("res://scripts/Buffs/shockwave.tres"),
	preload("res://scripts/Buffs/life.tres"),
	preload("res://scripts/Buffs/protection.tres"),
	preload("res://scripts/Buffs/looting.tres"),
]

func clear_choices() -> Array[BuffData]:
	var choices: Array[BuffData] = []
	for buff in CLEAR_POOL:
		if get_buff_level(buff.buff_id) < buff.max_level:
			choices.append(buff)
	choices.shuffle()
	return choices.slice(0, 3)

func exchange_buff(payment: StringName, reward: BuffData) -> bool:
	if not active_buffs.has(payment) or not can_add_buff(reward):
		return false
	active_buffs.erase(payment)
	return add_buff(reward) # Observers see both changes in the same notification.

var active_buffs: Dictionary = {}

func can_add_buff(buff: BuffData) -> bool:
	return buff != null and buff.buff_id != &"" and not active_buffs.has(buff.buff_id)


#give players new buff
func add_buff(buff: BuffData) -> bool:
	if buff == null or buff.buff_id ==&"":
		push_warning("Cannot add an invalid buff . ")
		return false
		
	if not can_add_buff(buff):
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


func capture_run_buffs() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for buff: BuffData in get_active_buffs():
		records.append({
			"id": String(buff.buff_id),
			"level": get_buff_level(buff.buff_id),
			"path": buff.resource_path,
		})
	return records


func restore_run_buffs(records: Variant) -> void:
	# Restore during player initialization, before gameplay or the HUD observes the buffs.
	if not records is Array:
		return
	for record in records:
		if not record is Dictionary or not record.get("id") is String:
			continue
		var id := StringName(record["id"])
		var buff := _resolve_saved_buff(id, record.get("path"))
		if can_add_buff(buff):
			var level := clampi(int(GlobalData.read_number(record, "level", 1)), 1, maxi(1, buff.max_level))
			active_buffs[id] = {"data": buff, "level": level}


func _resolve_saved_buff(id: StringName, path: Variant) -> BuffData:
	for buff: BuffData in KNOWN_BUFFS + CLEAR_POOL:
		if buff.buff_id == id:
			return buff
	if path is String and path.begins_with("res://") and ResourceLoader.exists(path, "Resource"):
		var resource := load(path) as BuffData
		if resource != null and resource.buff_id == id:
			return resource
	return null


# Remove all buffs
func clear_buffs() -> void:
	active_buffs.clear()
	buffs_cleared.emit()


# Calculate the movement speed multiplier
# from the currently active buff.
func get_speed_multiplier() -> float:
	var total_bonus: float = 0.0

	for entry in active_buffs.values():
		var buff: BuffData = entry["data"]
		var level: int = entry["level"]

		total_bonus += buff.speed_bonus_per_level * level

	return maxf(0.0, 1.0 + total_bonus)


# Calculate additional shield capacity from active buffs.
func get_shield_bonus() -> int:
	var total_bonus: int = 0

	for entry in active_buffs.values():
		var buff: BuffData = entry["data"]
		var level: int = entry["level"]

		total_bonus += buff.shield_bonus_per_level * level

	return total_bonus

# Calculate additional mana regeneration from active buffs
func get_mana_regen_bonus() -> float:
	var total_bonus: float = 0.0

	for entry in active_buffs.values():
		var buff: BuffData = entry["data"]
		var level: int = entry["level"]

		total_bonus += buff.mana_regen_bonus_per_level * level

	return total_bonus
