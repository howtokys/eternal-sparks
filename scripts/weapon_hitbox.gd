class_name WeaponHitbox
extends Area2D

var damage: int = 0
var element: String = ""
var knockback: float = 0.0
var _targets_hit: Dictionary[int, bool] = {}

func begin_swing() -> void:
	_targets_hit.clear()

func claim_target_hit(target: Node2D) -> bool:
	var target_id := target.get_instance_id()
	if collision_layer == 0 or _targets_hit.has(target_id):
		return false
	_targets_hit[target_id] = true
	return true
