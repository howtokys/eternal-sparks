extends CanvasLayer

@onready var health_bar: ProgressBar = $StatBars/VBoxContainer/HealthBar
@onready var shield_bar: ProgressBar = $StatBars/VBoxContainer/ShieldBar
@onready var mana_bar: ProgressBar = $StatBars/VBoxContainer/ManaBar

var player: Node2D

func _ready() -> void:
	# Find the player in the scene
	player = get_tree().get_first_node_in_group("player")
	
	if is_instance_valid(player):
		connect_player_signals()

func _process(_delta: float) -> void:
	# Continuously update Mana bar smoothly if mana regens over time
	if is_instance_valid(player):
		if "current_mana" in player:
			mana_bar.value = player.current_mana
		if "current_shield" in player:
			shield_bar.value = player.current_shield

func connect_player_signals() -> void:
	# Set initial max values
	if "max_shield" in player:
		shield_bar.max_value = player.max_shield
		shield_bar.value = player.current_shield
		
	if "max_mana" in player:
		mana_bar.max_value = player.max_mana
		mana_bar.value = player.current_mana

	# Connect to HealthComponent signals
	var health_comp = player.get_node_or_null("HealthComponent")
	if health_comp:
		health_bar.max_value = health_comp.max_health
		health_bar.value = health_comp.current_health
		health_comp.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health: int) -> void:
	health_bar.value = new_health

# Call this from Player.gd when shield takes damage or recharges
func update_shield_display(current_shield: int) -> void:
	shield_bar.value = current_shield
