class_name DungeonPlayer
extends CharacterBody2D

signal weapon_slots_changed
signal shield_stats_changed(current: int, maximum: int)
signal mana_stats_changed(current: float, maximum: float)

enum Stat { HEALTH, SHIELD, MANA }

const MINIMUM_HEALTH := 2
const MINIMUM_SHIELD := 1
const MINIMUM_MANA :	= 50

const SPEED = 500.0
const PICKUP = preload("uid://ddfou1e6ljx0n")
const WEAPON_ITEM_DATA := {
	"pistol": preload("res://Chest_loot/weapon_pistol.tres"),
	"long_katana": preload("res://Chest_loot/weapon_long_katana.tres"),
	"ember_staff": preload("res://Chest_loot/weapon_ember_staff.tres"),
	"shotgun": preload("res://Chest_loot/weapon_shotgun.tres"),
}

#for the player buff (speed)
#@export_group("Buffs")
#@export var starting_buff: BuffData

@export_group("Shield")
@export var max_shield: int = 5
@export var shield_recharge_delay: float = 5.0

@export_group("Mana")
@export var max_mana: float = 200.0
@export var mana_regen_rate: float = 5.0

var current_shield: int
var current_mana: float
const IMPACT := preload("res://scripts/Buffs/buff_impact.gd")
const METEOR_PERIOD := 30.0
var meteor_remaining := METEOR_PERIOD
var meteor_kills := 0
var life_progress := 0.0
var mana_regen_delay: float = 0.0
var weapon_slots: Array[WeaponData] = []
var active_weapon_slot: int = 0
var weapon_switch_lockout: float = 0.0

var base_max_health: int
var base_max_shield: int
var base_max_mana: float
var health_sacrifice: int
var shield_sacrifice: int
var mana_sacrifice: int
var applied_shield_bonus: int

var temp_speed_multiplier: float = 1.0
var temp_speed_time_left: float = 0.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var buff_manager: BuffManager = $BuffManager  #for the speed buff
@onready var shield_timer: Timer = $ShieldTimer
@onready var gun: Weapon = $Gun


func _ready() -> void:
	GlobalData.player = self
	GlobalData.enemy_defeated.connect(_on_enemy_defeated)
	_offer_pending_reward.call_deferred()
	base_max_health = health_component.max_health
	base_max_shield = max_shield
	base_max_mana = max_mana
	current_shield = max_shield
	current_mana = max_mana
	weapon_slots.append(gun.data)
	weapon_slots.append(null)

	health_component.died.connect(_on_player_died)
	
	if shield_timer:
		shield_timer.wait_time = shield_recharge_delay
		shield_timer.one_shot = true
		shield_timer.timeout.connect(_on_shield_recharge_timeout)
	#shield buff connection with buff manager
	
	buff_manager.buff_added.connect(_on_buff_added)
	buff_manager.buff_upgraded.connect(_on_buff_upgraded)
	buff_manager.buffs_cleared.connect(_on_buffs_cleared)
	
	# for testing the buffs
	# Assign the starting buff on a new game.
	#if not GlobalData.is_loading_save and starting_buff != null:
		#buff_manager.add_buff(starting_buff)
		#print("Starting buff: ", starting_buff.buff_name)
		#print("Movement speed: ", SPEED * buff_manager.get_speed_multiplier())
		#
	#if not GlobalData.is_loading_save and starting_buff != null:
		#var shield_buff: BuffData = load ("res://scripts/Buffs/shield.tres") as BuffData
		#if shield_buff != null:
			#buff_manager.add_buff(shield_buff)
			#print("Shield Boost level :", buff_manager.get_buff_level((shield_buff.buff_id)))
		#else:
			#push_error("Shield Boost resources couldn't be loaded.")
			#
	#if not GlobalData.is_loading_save and starting_buff !=null:
		#var mana_buff: BuffData = load("res://scripts/Buffs/mana_regen_buff.tres") as BuffData
		#if mana_buff != null:
			#buff_manager.add_buff(mana_buff)
			#print("== Mana regen boost test ==")
			#print("Mana buff level: ", buff_manager.get_buff_level(mana_buff.buff_id)) 
			#print("Mana regeneration rate: ", mana_regen_rate + buff_manager.get_mana_regen_bonus())
			#
			#
		#else:
			#push_error("Mana regenration buff resource could not be loaded")  
		
	if not GlobalData.run_player_state.is_empty():
		_restore_run_state(GlobalData.run_player_state)
	if GlobalData.is_loading_save:
		if GlobalData.has_saved_position:
			global_position = GlobalData.saved_position
			reset_physics_interpolation()
		GlobalData.is_loading_save = false
	GlobalData.request_save()


func _exit_tree() -> void:
	if GlobalData.player == self:
		if health_component.current_health > 0:
			GlobalData.run_player_state = capture_run_state()
		GlobalData.player = null

func apply_temporary_speed(multiplier: float, duration: float) -> void:
	temp_speed_multiplier = multiplier
	temp_speed_time_left = duration

func capture_run_state() -> Dictionary:
	return {
		"weapon_slots": weapon_slots.map(func(w: WeaponData): return w.resource_path if w else ""),
		"active_weapon_slot": active_weapon_slot,
		"health": health_component.current_health,
		"meteor_remaining": meteor_remaining,
		"meteor_kills": meteor_kills,
		"life_progress": life_progress,
		"shield": current_shield,
		"mana": current_mana,
		"health_sacrifice": health_sacrifice,
		"shield_sacrifice": shield_sacrifice,
		"mana_sacrifice": mana_sacrifice,
		"shield_recharge_remaining": shield_timer.time_left,
		"mana_regen_delay": mana_regen_delay,
		"buffs": buff_manager.capture_run_buffs(),
	}


func _restore_weapons(state: Dictionary) -> void:
	var saved: Variant = state.get("weapon_slots")
	if not saved is Array or saved.size() != weapon_slots.size():
		return
	for index in weapon_slots.size():
		var path: Variant = saved[index]
		if path is String and path.get_base_dir() == "res://scripts/weapons/data" and path.get_extension() == "tres" and ResourceLoader.exists(path):
			var weapon := load(path) as WeaponData
			if weapon != null:
				weapon_slots[index] = weapon
	active_weapon_slot = clampi(int(GlobalData.read_number(state, "active_weapon_slot", 0)), 0, weapon_slots.size() - 1)
	if weapon_slots[active_weapon_slot] == null:
		active_weapon_slot = 0
	gun.set_weapon_data(weapon_slots[active_weapon_slot])
	weapon_slots_changed.emit()


func _restore_run_state(state: Dictionary) -> void:
	_restore_weapons(state)
	health_sacrifice = clampi(int(GlobalData.read_number(state, "health_sacrifice", 0)), 0, maxi(0, base_max_health - MINIMUM_HEALTH))
	shield_sacrifice = clampi(int(GlobalData.read_number(state, "shield_sacrifice", 0)), 0, maxi(0, base_max_shield - MINIMUM_SHIELD))
	mana_sacrifice = clampi(int(GlobalData.read_number(state, "mana_sacrifice", 0)), 0, maxi(0, floori(base_max_mana - MINIMUM_MANA)))
	buff_manager.restore_run_buffs(state.get("buffs", []))
	meteor_remaining = clampf(GlobalData.read_number(state, "meteor_remaining", METEOR_PERIOD), 0, METEOR_PERIOD)
	meteor_kills = clampi(int(GlobalData.read_number(state, "meteor_kills", 0)), 0, 4)
	life_progress = clampf(GlobalData.read_number(state, "life_progress", 0), 0, 1)
	_update_effective_stats(false)

	# Legacy checkpoints may contain an out-of-range health value. Continue spawns a living player.
	health_component.current_health = clampi(
		int(GlobalData.read_number(state, "health", health_component.max_health)), 1, health_component.max_health)
	_set_shield(int(GlobalData.read_number(state, "shield", max_shield)), max_shield)
	_set_mana(GlobalData.read_number(state, "mana", max_mana), max_mana)
	mana_regen_delay = clampf(GlobalData.read_number(state, "mana_regen_delay", 0), 0.0, 0.75)
	var recharge := clampf(GlobalData.read_number(state, "shield_recharge_remaining", 0), 0.0, shield_recharge_delay)
	if recharge > 0:
		shield_timer.start(recharge)
	elif current_shield < max_shield and not state.has("shield_recharge_remaining"):
		# Saves without timer data should still recover a partially depleted shield.
		shield_timer.start(shield_recharge_delay)

func _process(delta: float) -> void:
	tick_run_buffs(delta)
	if weapon_switch_lockout > 0.0:
		weapon_switch_lockout = maxf(weapon_switch_lockout - delta, 0.0)
	gun.trigger_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	mana_regen_delay = maxf(mana_regen_delay - delta, 0.0)

	var total_mana_regen: float = mana_regen_rate + buff_manager.get_mana_regen_bonus()
	
	#regenerate mana without exceeding maximum capacity 
	if mana_regen_delay <= 0.0 and current_mana < max_mana:
		restore_mana(total_mana_regen * delta)
	# Passive mana regen
	#if current_mana < max_mana:
		#current_mana = min(current_mana + mana_regen_rate * delta, max_mana)

#func _physics_process(_delta: float) -> void:
	#var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#velocity = input_direction * SPEED
	#move_and_slide()

# speed buf movement 
func _physics_process(_delta: float) -> void:
	var status = get_node_or_null("StatusEffectComponent")
	if status and status.has_effect(&"freeze"):
		velocity = Vector2.ZERO
		move_and_slide()	
		return
	
	if temp_speed_time_left > 0.0:
		temp_speed_time_left -= _delta
		if temp_speed_time_left <= 0.0:
			temp_speed_multiplier = 1.0
	
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	
	var final_speed = SPEED * buff_manager.get_speed_multiplier() * temp_speed_multiplier
	velocity = input_direction * final_speed
	move_and_slide()


func _input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and weapon_switch_lockout <= 0.0
	):
		gun.trigger_pressed()
		return
	if event.is_action_pressed("weapon_slot_1"):
		switch_weapon(0)
		return
	if event.is_action_pressed("weapon_slot_2"):
		switch_weapon(1)
		return

func equip_weapon(new_data: WeaponData, drop_position := Vector2.INF) -> void:
	if new_data == null:
		push_error("Cannot equip a null WeaponData.")
		return

	for slot_index in weapon_slots.size():
		var slot_data := weapon_slots[slot_index]
		if slot_data != null and slot_data.id == new_data.id:
			switch_weapon(slot_index)
			return

	for slot_index in weapon_slots.size():
		if weapon_slots[slot_index] == null:
			weapon_slots[slot_index] = new_data
			switch_weapon(slot_index)
			return

	var replaced_data := weapon_slots[active_weapon_slot]
	weapon_slots[active_weapon_slot] = new_data
	gun.cancel_attack()
	gun.set_weapon_data(new_data)
	weapon_switch_lockout = 0.25
	weapon_slots_changed.emit()
	GlobalData.request_save()
	var dropped_item: ItemData = WEAPON_ITEM_DATA.get(replaced_data.id)
	if dropped_item == null:
		# Some weapons, including the starter rifle, have no authored chest pickup.
		dropped_item = ItemData.new()
		dropped_item.item_type = ItemData.Type.GUN
		dropped_item.item_name = replaced_data.display_name
		dropped_item.item_texture = replaced_data.texture
		dropped_item.weapon_data = replaced_data

	var pickup = PICKUP.instantiate()
	pickup.data = dropped_item
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = drop_position if drop_position.is_finite() else global_position + Vector2(0, 18)
	pickup.reset_physics_interpolation()

func switch_weapon(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= weapon_slots.size():
		return
	if weapon_slots[slot_index] == null or slot_index == active_weapon_slot:
		return

	active_weapon_slot = slot_index
	gun.cancel_attack()
	gun.set_weapon_data(weapon_slots[slot_index])
	weapon_switch_lockout = 0.25
	weapon_slots_changed.emit()
	GlobalData.request_save()

# Custom damage filter: shield absorbs first, leftover damages HealthComponent
func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	shield_timer.start(shield_recharge_delay / (1.0 + 0.5 * buff_manager.get_buff_level(&"protection")))

	var absorbed := mini(amount, current_shield)
	_set_shield(current_shield - absorbed, max_shield)
	amount -= absorbed

	if amount > 0:
		health_component.take_damage(amount)
		if health_component.current_health <= 0:
			return
	var wave := buff_manager.get_buff_level(&"shockwave")
	if wave > 0:
		var spikes := buff_manager.get_buff_level(&"spike_guard") > 0
		spawn_impact(IMPACT.Shape.SPIKES if spikes else IMPACT.Shape.WAVE, global_position, wave * (3 if spikes else 2))

func tick_run_buffs(delta: float) -> void:
	var life := buff_manager.get_buff_level(&"life")
	if life > 0 and health_component.current_health < health_component.max_health:
		life_progress += delta * life / 10.0
		if life_progress >= 1:
			health_component.heal(floori(life_progress))
			life_progress = fmod(life_progress, 1.0)
	if buff_manager.get_buff_level(&"meteor") > 0:
		meteor_remaining -= delta
		if meteor_remaining <= 0:
			meteor_remaining = METEOR_PERIOD
			meteor_kills = 0
			var boss := active_boss()
			var at := boss.global_position if boss != null else meteor_target()
			spawn_impact(IMPACT.Shape.METEOR, at, 12, boss)
			GlobalData.request_save()

func active_boss() -> Node2D:
	for boss in get_tree().get_nodes_in_group("boss"):
		if boss is Node2D and not boss.is_queued_for_deletion():
			return boss
	return null

func meteor_target() -> Vector2:
	var view := get_viewport_rect()
	return get_canvas_transform().affine_inverse() * (view.position + Vector2(randf(), randf()) * view.size)

func spawn_impact(shape: int, at: Vector2, power: int, boss: Node2D = null) -> void:
	var impact := IMPACT.new()
	impact.tracked_boss = boss
	impact.shape = shape
	impact.damage = power
	get_tree().current_scene.add_child(impact)
	impact.global_position = at

func _on_enemy_defeated() -> void:
	if buff_manager.get_buff_level(&"meteor") > 0:
		meteor_kills += 1
		if meteor_kills == 5:
			meteor_kills = 0
			meteor_remaining = METEOR_PERIOD
		GlobalData.request_save()
	var room := get_tree().current_scene
	if room == null or GlobalData.clear_rewards.has(room.scene_file_path):
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if room.is_ancestor_of(enemy) and not enemy.is_queued_for_deletion():
			return
	GlobalData.clear_rewards[room.scene_file_path] = "pending"
	_offer_pending_reward()

func _offer_pending_reward() -> void:
	var room := get_tree().current_scene
	if room == null or GlobalData.clear_rewards.get(room.scene_file_path, "") != "pending":
		return
	# Older First Room saves can owe both choices. Give each picker its own pause.
	var starter := get_tree().get_first_node_in_group(&"starting_buff_picker")
	if starter != null:
		if not starter.tree_exited.is_connected(_offer_pending_reward):
			starter.tree_exited.connect(_offer_pending_reward, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		return
	var choices := buff_manager.clear_choices()
	if choices.is_empty():
		GlobalData.clear_rewards[room.scene_file_path] = "claimed"
	GlobalData.request_save()
	if not choices.is_empty():
		var picker := (load("res://scenes/BuffSelection.tscn") as PackedScene).instantiate()
		picker.clear_options = choices
		var layer := CanvasLayer.new()
		layer.layer = 5
		room.add_child(layer)
		layer.add_child(picker)
		picker.tree_exited.connect(layer.queue_free)

func use_mana(cost: float) -> bool:
	if current_mana >= cost:
		_set_mana(current_mana - cost, max_mana)
		if cost > 0.0:
			mana_regen_delay = 0.75
		return true
	return false

func can_restore_stat(stat: Stat, amount: int) -> bool:
	if amount <= 0 or health_component.current_health <= 0:
		return false
	match stat:
		Stat.HEALTH:
			return health_component.current_health < health_component.max_health
		Stat.SHIELD:
			return current_shield < max_shield
		Stat.MANA:
			return current_mana < max_mana
	return false


func restore_stat(stat: Stat, amount: int) -> bool:
	if not can_restore_stat(stat, amount):
		return false
	match stat:
		Stat.HEALTH:
			return health_component.heal(amount)
		Stat.SHIELD:
			return restore_shield(amount)
		Stat.MANA:
			return restore_mana(amount)
	return false


func restore_shield(amount: int) -> bool:
	if amount <= 0:
		return false
	return _set_shield(current_shield + amount, max_shield)


func restore_mana(amount: float) -> bool:
	if amount <= 0.0:
		return false
	return _set_mana(current_mana + amount, max_mana)


func _set_shield(value: int, maximum: int) -> bool:
	value = clampi(value, 0, maximum)
	if value == current_shield and maximum == max_shield:
		return false
	max_shield = maximum
	current_shield = value
	shield_stats_changed.emit(current_shield, max_shield)
	return true


func _set_mana(value: float, maximum: float) -> bool:
	value = clampf(value, 0.0, maximum)
	if value == current_mana and maximum == max_mana:
		return false
	max_mana = maximum
	current_mana = value
	mana_stats_changed.emit(current_mana, max_mana)
	return true


func _on_shield_recharge_timeout() -> void:
	_set_shield(max_shield, max_shield)

func _on_player_died() -> void:
	if GlobalData.player == self:
		GlobalData.finish_run()
	
func can_sacrifice_stat(stat: Stat, amount: int) -> bool:
	if amount <= 0 or health_component.current_health <= 0:
		return false
	match stat:
		Stat.HEALTH:
			return base_max_health - health_sacrifice - amount >= MINIMUM_HEALTH
		Stat.SHIELD:
			return base_max_shield - shield_sacrifice - amount >= MINIMUM_SHIELD
		Stat.MANA:
			return base_max_mana - mana_sacrifice - amount >= MINIMUM_MANA
	return false


func apply_shop_pact(buff: BuffData, stat: Stat, amount: int) -> bool:
	if not can_sacrifice_stat(stat, amount) or not buff_manager.can_add_buff(buff):
		return false

	_commit_sacrifice(stat, amount)
	return buff_manager.add_buff(buff)


func apply_weapon_pact(weapon: WeaponData, stat: Stat, amount: int, drop_position: Vector2) -> bool:
	if weapon == null or not can_sacrifice_stat(stat, amount):
		return false
	for held in weapon_slots:
		if held != null and held.id == weapon.id:
			return false
	_commit_sacrifice(stat, amount)
	_update_effective_stats(false)
	equip_weapon(weapon, drop_position)
	return true


func _commit_sacrifice(stat: Stat, amount: int) -> void:
	match stat:
		Stat.HEALTH:
			health_sacrifice += amount
		Stat.SHIELD:
			shield_sacrifice += amount
		Stat.MANA:
			mana_sacrifice += amount


func _on_buff_added(_buff: BuffData) -> void:
	_update_effective_stats()


func _on_buff_upgraded(_buff: BuffData, _level: int) -> void:
	_update_effective_stats()


func _on_buffs_cleared() -> void:
	life_progress = 0
	meteor_remaining = METEOR_PERIOD
	meteor_kills = 0
	_update_effective_stats()


func _update_effective_stats(adjust_current_shield: bool = true) -> void:
	health_component.set_maximum_health(maxi(MINIMUM_HEALTH, base_max_health - health_sacrifice + buff_manager.get_buff_level(&"life")))
	var shield_bonus := buff_manager.get_shield_bonus()
	var bonus_change := shield_bonus - applied_shield_bonus if adjust_current_shield else 0
	applied_shield_bonus = shield_bonus
	# Keep the existing shield buff capacity adjustment. A sacrifice alone only clamps.
	_set_shield(current_shield + bonus_change, maxi(MINIMUM_SHIELD, base_max_shield - shield_sacrifice + shield_bonus))
	_set_mana(current_mana, maxf(MINIMUM_MANA, base_max_mana - mana_sacrifice))
