extends Area2D

@onready var health_component: HealthComponent = $"../HealthComponent"

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	# Expects attack hitboxes to define a 'damage' variable
	if area.is_in_group("enemy_attack") and "damage" in area:
		health_component.take_damage(area.damage)
