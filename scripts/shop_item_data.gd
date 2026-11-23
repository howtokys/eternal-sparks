class_name ShopItemData
extends Resource

enum Kind { RESTORATION, PACT, NORMAL_BUFF, WEAPON }

const STAT_NAMES: Array[String] = ["health", "shield", "mana"]
const RESTORE_UNITS: Array[String] = ["HP", "shield", "mana"]

@export var kind: Kind = Kind.RESTORATION
@export var item_name: String
@export var icon: Texture2D
@export var stat: DungeonPlayer.Stat
@export var coin_cost: int
@export var restore_amount: int
@export var weapon: WeaponData
@export var buff: BuffData
@export var sacrifice_amount: int
@export var prerequisite: StringName
@export var trade_buff: StringName
@export_range(0, 99) var discount_percent := 0

func price() -> int:
	return ceili(coin_cost * (1.0 - discount_percent / 100.0))

func available_to(player: DungeonPlayer) -> bool:
	if not is_instance_valid(player):
		return false
	for required: StringName in [prerequisite, trade_buff]:
		if not required.is_empty() and player.buff_manager.get_buff_level(required) == 0:
			return false
	return true


func display_name() -> String:
	if kind == Kind.WEAPON and weapon != null:
		return weapon.display_name
	return buff.buff_name if kind != Kind.RESTORATION and buff != null else item_name


func display_icon() -> Texture2D:
	if kind == Kind.WEAPON and weapon != null:
		return weapon.texture
	return buff.buff_icon if kind != Kind.RESTORATION and buff != null else icon


func description() -> String:
	if kind == Kind.WEAPON and weapon != null:
		return "%d x %d dmg" % [weapon.pellet_count, weapon.damage] if weapon.pellet_count > 1 else "%d dmg" % weapon.damage
	if kind != Kind.RESTORATION:
		return buff.description if buff != null else "Pact unavailable."
	return "Restores up to %d %s." % [restore_amount, RESTORE_UNITS[stat]]


func cost_text() -> String:
	if not trade_buff.is_empty():
		return "Trade Reflect (no maximum stat loss)"
	if discount_percent > 0:
		return "%d coins (was %d, %d%% off)" % [price(), coin_cost, discount_percent]
	if kind == Kind.PACT:
		return "Permanent cost: -%d max %s" % [sacrifice_amount, STAT_NAMES[stat]]
	return "%d coins" % coin_cost


func is_owned(player: DungeonPlayer) -> bool:
	return kind != Kind.RESTORATION and buff != null and is_instance_valid(player) and player.buff_manager.get_buff_level(buff.buff_id) > 0


func purchase_error(player: DungeonPlayer) -> String:
	if not is_instance_valid(player) or player.is_queued_for_deletion() or player.health_component.current_health <= 0:
		return "No active player."

	if not available_to(player):
		return "Required buff missing."
	if is_owned(player):
		return "Already owned."
	if kind == Kind.PACT:
		if not trade_buff.is_empty():
			return "" if player.buff_manager.can_add_buff(buff) else "Pact unavailable."
		if not player.buff_manager.can_add_buff(buff) or buff.max_level != 1 or sacrifice_amount <= 0:
			return "Pact unavailable."
		if not player.can_sacrifice_stat(stat, sacrifice_amount):
			return "Must keep at least %s." % _minimum_text()
		return ""

	if kind == Kind.NORMAL_BUFF:
		if not player.buff_manager.can_add_buff(buff):
			return "Buff unavailable."
	elif kind == Kind.WEAPON:
		if weapon == null:
			return "Weapon unavailable."
		for held in player.weapon_slots:
			if held != null and held.id == weapon.id:
				return "Already equipped."
	elif restore_amount <= 0:
		return "Item unavailable."
	if price() <= 0:
		return "Item unavailable."
	if kind == Kind.RESTORATION and not player.can_restore_stat(stat, restore_amount):
		return "%s is full." % STAT_NAMES[stat].capitalize()
	if price() > GlobalData.money:
		return "Need %d more coins." % (price() - GlobalData.money)
	return ""


func purchase(player: DungeonPlayer, drop_position := Vector2.INF) -> String:
	var failure := purchase_error(player)
	if not failure.is_empty():
		return failure
	match kind:
		Kind.PACT:
			if not trade_buff.is_empty():
				if not player.buff_manager.exchange_buff(trade_buff, buff):
					return "Trade unavailable."
			elif not player.apply_shop_pact(buff, stat, sacrifice_amount):
				return "Pact unavailable."
		Kind.WEAPON, Kind.NORMAL_BUFF, Kind.RESTORATION:
			if not GlobalData.try_spend_money(price()):
				return "Not enough coins."
			if not is_instance_valid(player) or player.is_queued_for_deletion() or not _grant_coin_item(player, drop_position):
				GlobalData.add_money(price())
				return "Item could not be used."
	GlobalData.request_save()
	return ""


func _grant_coin_item(player: DungeonPlayer, drop_position: Vector2) -> bool:
	if kind == Kind.WEAPON:
		player.equip_weapon(weapon, drop_position)
		return true
	if kind == Kind.NORMAL_BUFF:
		return player.buff_manager.add_buff(buff)
	return player.restore_stat(stat, restore_amount)

func _minimum_text() -> String:
	match stat:
		DungeonPlayer.Stat.HEALTH:
			return "%d max HP" % DungeonPlayer.MINIMUM_HEALTH
		DungeonPlayer.Stat.SHIELD:
			return "%d base shield" % DungeonPlayer.MINIMUM_SHIELD
		DungeonPlayer.Stat.MANA:
			return "%d max mana" % DungeonPlayer.MINIMUM_MANA
	return ""
