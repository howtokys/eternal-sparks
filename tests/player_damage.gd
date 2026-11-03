# GODOT_MCP_RUNTIME=off XDG_DATA_HOME=/tmp/eternal-sparks-validation godot --headless --path . --script res://tests/player_damage.gd
extends SceneTree

class HostileHitbox extends Area2D:
	var damage: int = 2

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func run_tests() -> void:
	# Fail nonzero even if a script error interrupts this coroutine.
	create_timer(15).timeout.connect(func(): quit(1))
	var arena := Node2D.new()
	var player = load("res://scenes/Player.tscn").instantiate()
	var enemy = load("res://scenes/enemy.tscn").instantiate()
	var hud = load("res://scenes/HUD.tscn").instantiate()
	player.position = Vector2(100, 100)
	enemy.position = Vector2(220, 100)
	check(enemy.contact_damage == 1 and enemy.attack_cooldown == 1.5, "Default contact damage is one point every 1.5 seconds")
	enemy.contact_damage = 2
	arena.add_child(player)
	arena.add_child(enemy)
	arena.add_child(hud)
	root.add_child(arena)
	current_scene = arena
	await frames(3)
	var health: HealthComponent = player.get_node("HealthComponent")
	var shield_timer: Timer = player.get_node("ShieldTimer")
	check(player.current_shield == 5 and health.current_health == 6, "Initial shield and health")
	# The old attack circle could hit from above without touching the body.
	enemy.set_physics_process(false)
	enemy.position = player.position + Vector2(0, -20)
	await frames(3)
	check(not enemy.player_in_attack_range and player.current_shield == 5, "Nearby enemy does not damage player without body contact")
	enemy.position = Vector2(220, 100)
	await frames(3)
	enemy.set_physics_process(true)
	# Enter actual detection and attack areas, without manually setting flags.
	enemy.position = player.position + Vector2(20, 0)
	await frames(4)
	check(enemy.player_in_detection_range and enemy.player_in_attack_range, "Enemy detects physical entry into attack range")
	check(player.current_shield == 3 and health.current_health == 6, "Melee uses configured contact_damage and shield absorbs it")
	check(not enemy.attack_timer.is_stopped(), "Attack cooldown starts")
	check(not shield_timer.is_stopped(), "Hit starts shield recharge delay")
	enemy.attack_player()
	await frames(3)
	check(player.current_shield == 3, "Cooldown prevents repeated immediate hits")
	check(hud.shield_bar.value == 3, "HUD displays damaged shield")
	var second_enemy = load("res://scenes/enemy.tscn").instantiate()
	second_enemy.position = player.position + Vector2(-12, 0)
	arena.add_child(second_enemy)
	await frames(4)
	check(second_enemy.player_in_attack_range and not second_enemy.attack_timer.is_stopped(), "Second enemy attempts a real contact attack")
	check(player.current_shield == 3, "Shared damage grace prevents stacked hits from other enemies")
	second_enemy.queue_free()
	await create_timer(enemy.attack_cooldown + 0.05).timeout
	check(player.current_shield == 1 and health.current_health == 6, "Enemy attacks again after cooldown")
	enemy.set_physics_process(false)
	enemy.position = Vector2(220, 100)
	await frames(3)
	check(not enemy.player_in_attack_range, "Leaving attack range clears flag")

	# Let the grace period from the second melee hit expire.
	await create_timer(player.damage_invulnerability_duration + 0.05).timeout
	# Test actual hostile area entry through HurtBox's area_entered signal.
	player.current_shield = 5
	var hitbox := HostileHitbox.new()
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.add_to_group("enemy_attack")
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5
	collider.shape = shape
	hitbox.add_child(collider)
	hitbox.position = Vector2(400, 400)
	arena.add_child(hitbox)
	await frames(3)
	hitbox.position = player.position + Vector2(4.5, 3)
	await frames(3)
	check(player.current_shield == 3 and health.current_health == 6, "Attack-area damage also uses shields")
	hitbox.queue_free()
	await frames(2)

	# Disable the tested grace period only for the following damage arithmetic
	# and shortened-recharge checks, which deliberately send immediate hits.
	player.damage_invulnerability_duration = 0.0
	player.damage_invulnerability_remaining = 0.0
	var hurtbox: Area2D = player.get_node("HurtBox")
	hurtbox.take_damage(5)
	check(player.current_shield == 0 and health.current_health == 4, "Only damage exceeding remaining shield reaches health")
	hurtbox.take_damage(1)
	check(health.current_health == 3, "Health takes full damage when shield is empty")
	var before_delay := shield_timer.time_left
	hurtbox.take_damage(0)
	hurtbox.take_damage(-1)
	check(health.current_health == 3 and player.current_shield == 0 and shield_timer.time_left == before_delay, "Zero and negative damage do nothing")

	# Shorten only this test instance's recharge delay.
	shield_timer.wait_time = 0.3
	hurtbox.take_damage(1)
	await create_timer(0.2).timeout
	hurtbox.take_damage(1)
	await create_timer(0.2).timeout
	check(player.current_shield == 0, "Further hits restart the recharge delay")
	await create_timer(0.2).timeout
	check(player.current_shield == player.max_shield, "Shield recharges after damage stops")
	check(health.current_health == 1, "Shield recharge preserves damaged health")
	arena.queue_free()
	await process_frame
	print("Player damage tests finished; failures=", failures)
	quit(1 if failures else 0)
