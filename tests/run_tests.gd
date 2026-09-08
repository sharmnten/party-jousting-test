extends SceneTree

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Missing health/effect/combat implementations must fail before authoring them.
	for path in ["res://scenes/Player.tscn", "res://scripts/combat.gd", "res://scripts/effects.gd"]:
		check(ResourceLoader.exists(path), "Required playable system missing: " + path)
	if failures > 0:
		finish()
		return
	var scene = load("res://scenes/Player.tscn")
	var player = scene.instantiate()
	root.add_child(player)
	player.activate()
	player.protection = 0.0
	check(player.take_damage(1), "First unprotected hit should damage")
	check(player.health == 2, "Hit removes one of three hearts")
	check(not player.take_damage(1), "Consecutive hit must respect protection")
	# Reactivate this fixture for independent coin/effect checks; recovery has its own suite.
	player.activate()
	player.collect_coin()
	player.collect_coin()
	check(player.health == 2, "Two coins cannot heal")
	player.collect_coin()
	check(player.health == 3 and player.coins == 0, "Three coins heal and reset counter")
	for i in range(12):
		player.collect_coin()
	check(player.health == 5, "Coin healing cannot exceed five")
	var catalog = load("res://scripts/powerup_catalog.gd")
	player.effects.apply(catalog.Kind.SPEED)
	player.effects.apply(catalog.Kind.SPEED)
	check(is_equal_approx(player.effects.speed_multiplier(), 1.65), "Repeated speed refreshes without multiplication")
	player.effects.tick(5.1)
	check(is_equal_approx(player.effects.speed_multiplier(), 1.0), "Speed expiry restores baseline")
	player.effects.apply(catalog.Kind.TINY)
	check(is_equal_approx(player.effects.size_multiplier(), 0.65), "Tiny changes collision-size multiplier")
	player.effects.apply(catalog.Kind.GIANT)
	check(not player.effects.has(catalog.Kind.TINY), "Giant replaces Tiny")
	check(player.effects.stomp_damage() == 2, "Giant increases stomp damage")
	player.effects.apply(catalog.Kind.HEAVY)
	check(player.effects.stomp_damage() == 2 and player.effects.gravity_multiplier() > 1.0, "Heavy adds weight without stacking Giant damage")
	player.effects.apply(catalog.Kind.SUPER_FLAP)
	check(player.effects.flap_multiplier() > 1.0, "Super Flap increases impulse")
	player.effects.tick(5.1)
	check(player.effects.size_multiplier() == 1.0 and player.effects.stomp_damage() == 1 and player.effects.flap_multiplier() == 1.0 and player.effects.gravity_multiplier() == 1.0, "All temporary derived stats restore on expiry")
	player.effects.apply(catalog.Kind.INVINCIBILITY)
	player.protection = 0
	check(not player.take_damage(2) and player.health == 5, "Invincibility blocks powerful damage")
	player.effects.tick(3.1)
	check(player.take_damage(1) and player.health == 4, "Invincibility expires cleanly")
	player.activate()
	player.collect_powerup(catalog.Kind.HEALTH)
	check(player.health == 5, "Health pickup restores one heart")
	player.effects.apply(catalog.Kind.SHIELD)
	player.protection = 0.0
	check(not player.take_damage(1), "Shield blocks damage")
	check(not player.effects.has(catalog.Kind.SHIELD), "Shield consumed on hit")
	player.effects.clear()
	player.collect_powerup(catalog.Kind.RANDOM)
	check(not player.effects.has(catalog.Kind.RANDOM) and not player.effects.has(catalog.Kind.HEAVY), "Mystery resolves to beneficial effect without recursive mystery")
	player.effects.clear()
	player.protection = 0.0
	player.take_damage(99)
	check(not player.alive and player.health == 0, "Lethal damage eliminates")
	player.collect_coin()
	check(player.health == 0, "Coins never revive eliminated players")
	var combat = load("res://scripts/combat.gd")
	check(combat.is_stomp(Vector2(0, -1), Vector2(0, 200), Vector2.ZERO, -40, 36), "Falling top contact is stomp")
	check(not combat.is_stomp(Vector2.LEFT, Vector2(200, 100), Vector2.ZERO, -5, 36), "Side contact does not damage")
	check(not combat.is_stomp(Vector2.UP, Vector2(0, -100), Vector2(0, -200), -40, 36), "Rising upper player cannot stomp")
	check(not combat.is_stomp(Vector2.UP, Vector2(0, 100), Vector2(0, 200), -40, 36), "Separating contact cannot stomp")
	player.free()
	finish()

func finish() -> void:
	print("TEST RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
