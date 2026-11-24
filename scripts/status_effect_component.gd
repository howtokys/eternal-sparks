class_name StatusEffectComponent
extends Node

const ICE_CRYSTAL = preload("uid://dxeuoxy0h60iu")

signal effect_started(effect_id: StringName, level: int)
signal effect_ended(effect_id: StringName)

var active_effects: Dictionary = {}  # id -> {resource, level, time_left, tick_timer, sources}
var indicators: Dictionary = {}      # effect_id -> Node

func _ready() -> void:
	effect_started.connect(_on_effect_started)

func apply_effect(effect: StatusEffect, source: Node = null) -> void:
	if effect == null:
		return
	
	var id = effect.id
	
	if not active_effects.has(id):
		active_effects[id] = {
			"resource": effect,
			"level": 1,
			"time_left": effect.duration_per_level,
			"tick_timer": 0.0,
			"ticks_done": 0,
			"sources": []
		}
		if source:
			active_effects[id].sources.append(source)
		
		_spawn_indicator(effect)
		effect_started.emit(id, 1)
	else:
		var data = active_effects[id]
		if source and not data.sources.has(source):
			data.sources.append(source)
		
		# Instant stack for fire
		if effect.instant_stack and data.level < effect.max_level:
			data.level += 1
			data.ticks_done = 0
			data.tick_timer = 0.0
			data.time_left = effect.duration_per_level
			effect_started.emit(id, data.level)
			print("[Status] Instant upgrade ", id, " to level ", data.level)

func _spawn_indicator(effect: StatusEffect) -> void:
	if effect.id == &"freeze":
		if indicators.has(effect.id):
			return
		
		var crystal = ICE_CRYSTAL.instantiate()
		crystal.visible = false
		crystal.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		
		get_parent().add_child(crystal)
		crystal.global_position = get_parent().global_position + Vector2(3, -6)
		crystal.reset_physics_interpolation()
		
		crystal.modulate.a = 0.9
		crystal.animation = "freeze"
		crystal.frame = 0
		crystal.pause()
		crystal.visible = true
		
		indicators[effect.id] = crystal
		return
	
	# (poison, fire)
	if not effect.indicator_scene or indicators.has(effect.id):
		return
	
	var indicator = effect.indicator_scene.instantiate()
	get_parent().add_child.call_deferred(indicator)
	indicators[effect.id] = indicator
	
	await get_tree().process_frame
	if is_instance_valid(indicator):
		indicator.position = Vector2(5, -24)
		indicator.visible = true
		_update_indicator_icon(effect.id, 1)

func _on_effect_started(effect_id: StringName, level: int) -> void:
	_update_indicator_icon(effect_id, level)

func _update_indicator_icon(effect_id: StringName, level: int) -> void:
	if not indicators.has(effect_id) or not active_effects.has(effect_id):
		return
	
	var indicator = indicators[effect_id]
	var effect: StatusEffect = active_effects[effect_id].resource
	
	if effect.level_icons.size() > level and effect.level_icons[level]:
		indicator.texture = effect.level_icons[level]

func remove_source(effect_id: StringName, source: Node) -> void:
	if not active_effects.has(effect_id):
		return
	active_effects[effect_id].sources.erase(source)

func _process(delta: float) -> void:
	var to_remove: Array[StringName] = []
	
	for id in active_effects:
		var data = active_effects[id]
		var effect: StatusEffect = data.resource
		
		var source_count = max(data.sources.size(), 1)
		var speed_multiplier = 1.0
		
		if effect.id != &"freeze":
			speed_multiplier = source_count

		data.tick_timer += delta * speed_multiplier

		#damage tick
		if data.tick_timer >= effect.tick_rate:
			data.tick_timer = 0.0
			data.ticks_done += 1
			
			var damage := 0
			if data.level < effect.damage_per_level.size():
				damage = effect.damage_per_level[data.level]
			
			var target = get_parent()
			if damage > 0 and target.has_method("take_damage"):
				target.take_damage(damage)

		#end level after the set number of ticks
		if data.ticks_done >= effect.ticks_per_level:
			if not effect.instant_stack and data.sources.size() > 0 and data.level < effect.max_level:
				#normal stacking (poison)
				data.level += 1
				data.ticks_done = 0
				data.tick_timer = 0.0
				data.time_left = effect.duration_per_level
				effect_started.emit(id, data.level)
			else:
				to_remove.append(id)

		# Then reduce time
		data.time_left -= delta * speed_multiplier

		# Level finished
		if data.time_left <= 0:
			if data.sources.size() > 0 and data.level < effect.max_level:
				data.level += 1
				data.time_left = effect.duration_per_level
				data.tick_timer = 0.0
				effect_started.emit(id, data.level)
			else:
				to_remove.append(id)
	
	for id in to_remove:
		active_effects.erase(id)
		effect_ended.emit(id)
		_remove_indicator(id)

func _remove_indicator(effect_id: StringName) -> void:
	if not indicators.has(effect_id):
		return
	
	var indicator = indicators[effect_id]
	indicators.erase(effect_id)
	
	if effect_id == &"freeze" and is_instance_valid(indicator):
		# Keep world position, unparent from player
		var world_pos = indicator.global_position
		indicator.get_parent().remove_child(indicator)
		get_tree().current_scene.add_child(indicator)
		indicator.global_position = world_pos
		
		indicator.frame = 1
		indicator.z_index = 0
		indicator.position += Vector2(0, 13)  # optional offset from where they stood
		
		await get_tree().create_timer(3.0).timeout
		
		if not is_instance_valid(indicator):
			return
		
		var tween = indicator.create_tween()
		tween.tween_property(indicator, "modulate:a", 0.0, 2.0)
		await tween.finished
		
		if is_instance_valid(indicator):
			indicator.queue_free()
	elif is_instance_valid(indicator):
		indicator.queue_free()

func has_effect(effect_id: StringName) -> bool:
	return active_effects.has(effect_id)

func get_level(effect_id: StringName) -> int:
	if active_effects.has(effect_id):
		return active_effects[effect_id].level
	return 0
