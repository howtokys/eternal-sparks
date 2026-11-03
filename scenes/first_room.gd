
extends Node2D

@onready var portal: AnimatedSprite2D = $Portal
@onready var level_exit: Area2D = $LevelExit

var enemies_remaining: int = 0

func _ready() -> void:
	print("First Room loaded successfully!")
	
	portal.hide()
	portal.stop()
	
	level_exit.set_deferred("monitoring", false)
	
	var enemies: Array[Node] = [
		$Floor/Enemy,
		$Floor/Enemy2
	]	
	
	enemies_remaining = enemies.size()
	
	for enemy in enemies:
		enemy.tree_exited.connect(_on_enemy_removed)
	
	print("Enemies Remaining:", enemies_remaining)
	
	if enemies_remaining == 0:
		unlock_portal()



func _on_level_exit_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var manager: BuffManager = body.get_node_or_null(
		"BuffManager"
	) as BuffManager

	if manager == null:
		push_error("BuffManager not found!")
		return

	# Remember current buffs before changing rooms
	GlobalData.room_buff_snapshot.clear()

	for buff in manager.get_active_buffs():
		GlobalData.room_buff_snapshot.append({
			"resource": buff,
			"level": manager.get_buff_level(buff.buff_id)
		})

	print("Entering Second Room!")

	# Change to the next dungeon room
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/Second_Room.tscn"
	)
	
func _on_enemy_removed()-> void:
	enemies_remaining -=1
	
	print("Enemeies remiaing: ", enemies_remaining)
	
	if enemies_remaining <=0:
		unlock_portal()
		
		
func unlock_portal()->void: 
	print("Room cleared portal unlocked")
	
	portal.show()
	portal.play("idle")
	
	level_exit.set_deferred("monitoring", true)
