extends AnimatedSprite2D

const MOVEMENT := preload("res://scripts/Shop/movement_surge.tres")
const SPIKE := preload("res://scripts/Shop/spike_guard.tres")
const METEOR := preload("res://scripts/Shop/meteor.tres")
const REFLECT_TRADE := preload("res://scripts/Shop/reflect_exchange.tres")

@export var fallback_weapons: Array[WeaponData]

@onready var movement := $"../PactPedestal"
@onready var spike := $"../SpikePedestal"
@onready var meteor := $"../MeteorPedestal"

func _ready() -> void:
	$Proximity.body_entered.connect(_greet.bind(true))
	$Proximity.body_exited.connect(_greet.bind(false))
	_connect_inventory.call_deferred()


func _greet(body: Node2D, nearby: bool) -> void:
	if body is DungeonPlayer:
		$Greeting.visible = nearby


func _connect_inventory() -> void:
	var player := GlobalData.player as DungeonPlayer
	if not is_instance_valid(player):
		return
	var buffs := player.buff_manager
	buffs.buff_added.connect(_refresh_inventory.unbind(1))
	buffs.buffs_cleared.connect(_refresh_inventory)
	player.weapon_slots_changed.connect(_refresh_inventory)
	_refresh_inventory()


func _refresh_inventory() -> void:
	var player := GlobalData.player as DungeonPlayer
	var stands := [movement, spike, meteor]
	var primary: Array[ShopItemData] = [MOVEMENT, SPIKE, METEOR]
	var reserved := player.weapon_slots.duplicate()
	for i in stands.size():
		var stand = stands[i]
		if stand.sold or stand.purchasing:
			continue
		var pact := primary[i]
		if pact.available_to(player) and not pact.is_owned(player):
			stand.change_offer(REFLECT_TRADE if pact == METEOR and REFLECT_TRADE.available_to(player) else pact)
			continue
		# Five different weapons cover three stands even with both player slots full.
		for offset in fallback_weapons.size():
			var weapon := fallback_weapons[(i + offset) % fallback_weapons.size()]
			if weapon in reserved:
				continue
			reserved.append(weapon)
			if stand.offer.weapon != weapon:
				var fallback := ShopItemData.new()
				fallback.kind = ShopItemData.Kind.WEAPON
				fallback.weapon = weapon
				fallback.stat = pact.stat
				fallback.sacrifice_amount = pact.sacrifice_amount
				stand.change_offer(fallback)
			break
