class_name StatusEffect
extends Resource

@export var id: StringName = &"poison"
@export var max_level: int = 3
@export var duration_per_level: float = 3.0
@export var damage_per_level: Array[int] = [0, 3, 4, 5]
@export var tick_rate: float = 1.0
@export var indicator_scene: PackedScene
@export var level_icons: Array[Texture2D] = []
@export var instant_stack: bool = false  #true for fire, false for poison
@export var ticks_per_level: int = 2     #1 for fire, 2 for poison
