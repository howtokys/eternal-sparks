extends CharacterBody2D

const SPEED = 150.0

@export_group("Shield")
@export var max_shield: int = 5
@export var shield_recharge_delay: float = 3.0

@export_group("Mana")
@export var max_mana: float = 50.0
@export var mana_regen_rate: float = 5.0

var current_shield: int
var current_mana: float

@onready var health_component: HealthComponent = $HealthComponent
@onready var shield_timer: Timer = $ShieldTimer
@onready var gun: Node2D = $Gun


func _ready() -> void:
	current_shield = max_shield
	current_mana = max_mana

	health_component.died.connect(_on_player_died)
	
	if shield_timer:
		shield_timer.wait_time = shield_recharge_delay
		shield_timer.one_shot = true
		shield_timer.timeout.connect(_on_shield_recharge_timeout)

func _process(delta: float) -> void:
	# Passive mana regen
	if current_mana < max_mana:
		current_mana = min(current_mana + mana_regen_rate * delta, max_mana)

func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * SPEED
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):
		gun.shoot()

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

func _on_shield_recharge_timeout() -> void:
	current_shield = max_shield

func _on_player_died() -> void:
	queue_free()
