class_name ItemData
extends Resource

# Move enum to the very top so Godot sees it first
enum Type { HEALTH_POTION, MANA_POTION, GUN }

@export var item_name: String
@export var item_texture: Texture2D
@export var drop_chance_weight: int = 10

@export var item_type: Type
@export var restore_amount: int = 25
@export var gun_scene: PackedScene
