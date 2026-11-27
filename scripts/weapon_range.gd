extends Node2D

const PICKUP := preload("res://scenes/pickup.tscn")
const LOOT := preload("res://scripts/weapons/weapon_loot.gd")

func _ready() -> void:
	for tier in range(LOOT.POOLS.size()):
		var weapons: Array = LOOT.POOLS[tier]
		for column in range(weapons.size()):
			var pickup := PICKUP.instantiate()
			pickup.data = ItemData.from_weapon(weapons[column])
			pickup.position = Vector2(112 + column * 56, 49 + tier * 34)
			add_child(pickup)
