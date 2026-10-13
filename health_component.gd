class_name HealthComponent
extends Node2D

signal health_changed(current_health: int)
signal died

@export var max_health: int = 10

var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health)

	if current_health == 0:
		died.emit()
