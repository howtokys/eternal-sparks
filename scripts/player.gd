extends CharacterBody2D

const SPEED = 150.0
const PICKUP = preload("uid://ddfou1e6ljx0n")
const WEAPON_ITEM_DATA := {
	"pistol": preload("res://Chest_loot/weapon_pistol.tres"),
	"long_katana": preload("res://Chest_loot/weapon_long_katana.tres"),
	"ember_staff": preload("res://Chest_loot/weapon_ember_staff.tres"),
	#"railgun": preload("res://Chest_loot/weapon_railgun.tres"),
}

#for the player buff (speed)
#@export_group("Buffs")
#@export var starting_buff: BuffData

@export_group("Shield")
@export var max_shield: int = 5
@export var shield_recharge_delay: float = 3.0

@export_group("Mana")
@export var max_mana: float = 50.0
@export var mana_regen_rate: float = 5.0

var current_shield: int
var current_mana: float
var weapon_slots: Array[WeaponData] = []
var active_weapon_slot: int = 0
var weapon_switch_lockout: float = 0.0

# shield buff to preserve the orinal shield capacity
var base_max_shield: int

@onready var health_component: HealthComponent = $HealthComponent
@onready var buff_manager: BuffManager = $BuffManager  #for the speed buff
@onready var shield_timer: Timer = $ShieldTimer
@onready var gun: Weapon = $Gun


func _ready() -> void:
	GlobalData.player = self
	base_max_shield = max_shield  #shield buff
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
		
	if GlobalData.is_loading_save:
		global_position = GlobalData.saved_position
		GlobalData.is_loading_save = false
		
	GlobalData.save_game()

func _process(delta: float) -> void:
	if weapon_switch_lockout > 0.0:
		weapon_switch_lockout = maxf(weapon_switch_lockout - delta, 0.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and weapon_switch_lockout <= 0.0:
		gun.shoot()
	
	var total_mana_regen: float = mana_regen_rate + buff_manager.get_mana_regen_bonus()
	
	#regenerate mana without exceeding maximum capacity 
	if current_mana < max_mana:
		current_mana = minf(
			current_mana + total_mana_regen * delta,
			max_mana
		)
	# Passive mana regen
	#if current_mana < max_mana:
		#current_mana = min(current_mana + mana_regen_rate * delta, max_mana)

#func _physics_process(_delta: float) -> void:
	#var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#velocity = input_direction * SPEED
	#move_and_slide()

# speed buf movement 
func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var speed_multiplier: float = buff_manager.get_speed_multiplier()

	velocity = input_direction * SPEED * speed_multiplier
	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_slot_1"):
		switch_weapon(0)
		return
	if event.is_action_pressed("weapon_slot_2"):
		switch_weapon(1)
		return

func equip_weapon(new_data: WeaponData) -> void:
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
	var dropped_item: ItemData = WEAPON_ITEM_DATA.get(replaced_data.id)
	if dropped_item == null:
		push_warning("Weapon '%s' was discarded because it has no pickup ItemData." % replaced_data.id)
		return

	var pickup = PICKUP.instantiate()
	pickup.visible = false
	get_tree().current_scene.add_child(pickup)
	pickup.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pickup.global_position = global_position + Vector2(0, 18)
	pickup.data = dropped_item
	pickup.reset_physics_interpolation()
	await get_tree().process_frame
	pickup.visible = true

func switch_weapon(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= weapon_slots.size():
		return
	if weapon_slots[slot_index] == null or slot_index == active_weapon_slot:
		return

	active_weapon_slot = slot_index
	gun.cancel_attack()
	gun.set_weapon_data(weapon_slots[slot_index])
	weapon_switch_lockout = 0.25

# Custom damage filter: shield absorbs first, leftover damages HealthComponent
func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	shield_timer.start()

	if current_shield > 0:
		if amount <= current_shield:
			current_shield -= amount
			amount = 0
		else:
			amount -= current_shield
			current_shield = 0

	if amount > 0:
		health_component.take_damage(amount)

func use_mana(cost: float) -> bool:
	if current_mana >= cost:
		current_mana -= cost
		return true
	return false

func restore_mana(amount: float) -> void:
	print("Before mana restore - Current: ", current_mana, " / Max: ", max_mana)
	current_mana = minf(current_mana + amount, max_mana)
	print("After mana restore - Current: ", current_mana)

func _on_shield_recharge_timeout() -> void:
	current_shield = max_shield

func _on_player_died() -> void:
	queue_free()
	
# new buff signal handlers

#called whenever a new buff is added 
func _on_buff_added(_buff: BuffData) -> void:
	update_shield_from_buffs()

# Called whenever a buff is upgraded
func _on_buff_upgraded(_buff: BuffData, _level: int) -> void:
	update_shield_from_buffs()


# Called whenever buffs are cleared
func _on_buffs_cleared() -> void:
	update_shield_from_buffs()

# shiled calculations 
func update_shield_from_buffs() -> void:
	# Calculate maximum shield with active buffs
	var new_max_shield: int = maxi(
		0,
		base_max_shield + buff_manager.get_shield_bonus()
	)

	# Determine how much shield capacity changed
	var shield_difference: int = new_max_shield - max_shield

	# Update maximum shield
	max_shield = new_max_shield

	# Adjust current shield without exceeding maximum
	current_shield = clampi(
		current_shield + shield_difference,
		0,
		max_shield
	)

	print("Current Shield: ", current_shield)
	print("Maximum Shield: ", max_shield)
