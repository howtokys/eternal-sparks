extends Area2D

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	# Expects attack hitboxes to define a 'damage' variable
	if area.is_in_group("enemy_attack") and "damage" in area:
		take_damage(area.damage)

func take_damage(amount: int) -> void:
	# Player owns shield absorption, health overflow, and the recharge delay.
	get_parent().call("take_damage", amount)
