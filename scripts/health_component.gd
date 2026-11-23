class_name HealthComponent
extends Node2D

signal health_changed(current_health: int)
signal health_stats_changed(current: int, maximum: int)
signal died

@export var max_health: int = 10

var current_health: int


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	current_health = maxi(current_health - amount, 0)
	_emit_health_changed()
	if current_health == 0:
		died.emit()


func heal(amount: int) -> bool:
	if amount <= 0 or current_health <= 0 or current_health >= max_health:
		return false

	current_health = mini(current_health + amount, max_health)
	_emit_health_changed()
	return true


func set_maximum_health(maximum: int) -> void:
	maximum = maxi(1, maximum)
	if maximum == max_health:
		return
	max_health = maximum
	current_health = mini(current_health, max_health)
	_emit_health_changed()


func _emit_health_changed() -> void:
	health_changed.emit(current_health)
	health_stats_changed.emit(current_health, max_health)
