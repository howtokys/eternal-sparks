extends Node2D

# Rooms 2 and 3 advance the starting buff; subsequent rooms preserve its level.
@export var buff_level_increase: int = 1
@export_file("*.tscn") var next_room_path: String = "res://scenes/Third_Room.tscn"

var enemies_remaining: int = 0
var transitioning := false
var defeated_enemies: Dictionary = {}

@onready var portal: AnimatedSprite2D = $Portal
@onready var level_exit: Area2D = $LevelExit

func _ready() -> void:
	portal.hide()
	portal.stop()
	level_exit.set_deferred("monitoring", false)
	for enemy in $Floor.get_children():
		if enemy is CharacterBody2D and enemy.has_node("HealthComponent"):
			enemies_remaining += 1
			enemy.get_node("HealthComponent").died.connect(_on_enemy_defeated.bind(enemy.get_instance_id()))
	call_deferred("restore_and_upgrade_buffs")
	if enemies_remaining == 0:
		unlock_portal()

func restore_and_upgrade_buffs() -> void:
	var manager: BuffManager = $Player/BuffManager
	for saved in GlobalData.room_buff_snapshot:
		var buff: BuffData = saved["resource"]
		if buff == null:
			continue
		if manager.get_buff_level(buff.buff_id) == 0 and not manager.add_buff(buff):
			continue
		var target_level := mini(int(saved["level"]) + buff_level_increase, maxi(1, buff.max_level))
		while manager.get_buff_level(buff.buff_id) < target_level:
			if not manager.upgrade_buff(buff.buff_id):
				break
	GlobalData.room_buff_snapshot.clear()

func _on_enemy_defeated(enemy_id: int) -> void:
	if defeated_enemies.has(enemy_id):
		return
	defeated_enemies[enemy_id] = true
	enemies_remaining -= 1
	if enemies_remaining == 0:
		unlock_portal()

func unlock_portal() -> void:
	portal.show()
	portal.play("idle")
	level_exit.set_deferred("monitoring", true)

func _on_level_exit_body_entered(body: Node2D) -> void:
	if transitioning or enemies_remaining > 0 or not body.is_in_group("player"):
		return
	# Keep this stage playable while the next room is still being authored.
	if next_room_path.is_empty() or not ResourceLoader.exists(next_room_path):
		push_warning("Next dungeon room is not available yet: " + next_room_path)
		return
	transitioning = true
	var manager: BuffManager = body.get_node("BuffManager")
	GlobalData.room_buff_snapshot.clear()
	for buff in manager.get_active_buffs():
		GlobalData.room_buff_snapshot.append({"resource": buff, "level": manager.get_buff_level(buff.buff_id)})
	call_deferred("_change_room")

func _change_room() -> void:
	var error := get_tree().change_scene_to_file(next_room_path)
	if error != OK:
		transitioning = false
		push_error("Dungeon transition failed: " + error_string(error))
