extends RefCounted

enum Tier { BROWN, BLUE, GOLD }

const POOLS := [
	[
		preload("res://scripts/weapons/data/pistol.tres"),
		preload("res://scripts/weapons/data/auto_rifle.tres"),
		preload("res://scripts/weapons/data/spear.tres"),
		preload("res://scripts/weapons/data/battle_axe.tres"),
	],
	[
		preload("res://scripts/weapons/data/shotgun.tres"),
		preload("res://scripts/weapons/data/long_katana.tres"),
		preload("res://scripts/weapons/data/ember_staff.tres"),
		preload("res://scripts/weapons/data/frost_staff.tres"),
	],
	[
		preload("res://scripts/weapons/data/war_hammer.tres"),
		preload("res://scripts/weapons/data/storm_staff.tres"),
		preload("res://scripts/weapons/data/laser_gun.tres"),
	],
]

static func roll(tier: Tier) -> ItemData:
	return ItemData.from_weapon(POOLS[tier].pick_random())
