extends Resource
class_name BuffData

@export var buff_id: StringName = &""
@export var buff_name: String = ""
@export_multiline var description: String = ""
@export_range(1,100.,1) var max_level: int = 1


#movement speed increase according to buff level 
@export var speed_bonus_per_level: float = 0.0

#maximum shield per buff level . 
@export var shield_bonus_per_level: int = 0

#mana regneration per second, per buff level 
@export var mana_regen_bonus_per_level: float = 0.0
