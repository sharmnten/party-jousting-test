extends SceneTree
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://scenes/Player.tscn")
	var a := scene.instantiate() as JoustPlayer
	var b := scene.instantiate() as JoustPlayer
	root.add_child(a)
	root.add_child(b)
	a.activate()
	b.activate()
	a.protection = 0
	b.protection = 0
	var players: Array[JoustPlayer] = [a, b]
	var combat := CombatResolver.new()
	b.before_position = Vector2(400, 400)
	b.position = b.before_position
	b.before_velocity = Vector2.ZERO
	a.before_position = Vector2(400, 355)
	a.position = Vector2(400, 360) # Still four pixels clear of physical contact.
	a.before_velocity = Vector2(0, 300)
	combat.resolve(players)
	check(b.health == 3, "Nearby players must not take damage before actual contact")
	a.before_position = a.position
	a.position.y = 366
	combat.resolve(players)
	check(b.health == 2, "Slow approach through five-pixel gap still damages on first contact")
	# Any meaningful vertical ordering wins the contact: the higher body continues,
	# while the lower body takes damage even when the higher body is not falling.
	a.activate()
	b.activate()
	a.health = 3
	b.health = 3
	a.protection = 0
	b.protection = 0
	a.recovery = JoustPlayer.Recovery.NONE
	b.recovery = JoustPlayer.Recovery.NONE
	a.before_position = Vector2(350, 430)
	a.position = Vector2(440, 430)
	a.before_velocity = Vector2(900, 0)
	b.before_position = Vector2(440, 450)
	b.position = b.before_position
	b.before_velocity = Vector2.ZERO
	CombatResolver.new().resolve(players)
	check(b.health == 2 and a.health == 3, "Higher player damages lower player on collision")
	check(a.velocity.y < 0, "Higher player continues with an upward bounce")
	a.activate()
	b.activate()
	a.health = 3
	b.health = 3
	a.protection = 0
	b.protection = 0
	a.before_position = Vector2(350, 400)
	a.position = Vector2(440, 400)
	a.before_velocity = Vector2(900, 0)
	b.before_position = Vector2(440, 400)
	b.position = b.before_position
	b.before_velocity = Vector2.ZERO
	CombatResolver.new().resolve(players)
	check(a.health == 3 and b.health == 3, "Near-level side collision remains harmless")
	# A shield turns any player-body collision into a counter: consume the
	# shield and damage the colliding player, regardless of who is higher.
	a.activate()
	b.activate()
	a.health = 3
	b.health = 3
	a.effects.clear()
	b.effects.clear()
	b.effects.apply(PowerupCatalog.Kind.SHIELD)
	a.protection = 0
	b.protection = 0
	a.before_position = Vector2(350, 430)
	a.position = Vector2(440, 430)
	a.before_velocity = Vector2(900, 0)
	b.before_position = Vector2(440, 450)
	b.position = b.before_position
	b.before_velocity = Vector2.ZERO
	CombatResolver.new().resolve(players)
	check(not b.effects.has(PowerupCatalog.Kind.SHIELD), "Shield disappears on player collision")
	check(a.health == 2 and b.health == 3, "Shield damages the colliding player regardless of height")
	a.activate()
	b.activate()
	a.health = 3
	b.health = 3
	a.effects.clear()
	b.effects.clear()
	a.effects.apply(PowerupCatalog.Kind.SHIELD)
	a.protection = 0
	b.protection = 0
	a.before_position = Vector2(440, 450)
	a.position = a.before_position
	a.before_velocity = Vector2.ZERO
	b.before_position = Vector2(350, 430)
	b.position = Vector2(440, 430)
	b.before_velocity = Vector2(900, 0)
	CombatResolver.new().resolve(players)
	check(not a.effects.has(PowerupCatalog.Kind.SHIELD), "Lower shield also disappears on collision")
	check(a.health == 3 and b.health == 2, "Shield counter works when shielded player is lower")
	# Grounded victim: a fresh body impact finishes them even during recovery protection.
	a.activate()
	b.activate()
	a.health = 3
	b.health = 3
	b.recovery = JoustPlayer.Recovery.RESTING
	b.rest_remaining = 2
	b.effects.apply(PowerupCatalog.Kind.INVINCIBILITY)
	b.position = Vector2(600, 677.8)
	b.before_position = b.position
	b.before_velocity = Vector2.ZERO
	a.before_position = Vector2(555, 677.8)
	a.position = Vector2(568, 677.8)
	a.before_velocity = Vector2(300, 0)
	combat = CombatResolver.new()
	combat.resolve(players)
	check(not b.alive and b.health == 0, "A body impact instantly eliminates a resting victim regardless of hearts/protection")
	check(a.alive and a.health == 3, "Grounded execution does not hurt attacker")
	combat.resolve(players)
	check(not b.alive, "Eliminated body stays out of subsequent combat")
	# A resting shield counters first, so the incoming player takes damage and
	# the exposed resting player survives with the shield consumed.
	b.free()
	b = scene.instantiate() as JoustPlayer
	root.add_child(b)
	a.activate()
	a.health = 3
	a.effects.clear()
	a.protection = 0
	b.activate()
	b.health = 3
	b.effects.clear()
	b.effects.apply(PowerupCatalog.Kind.SHIELD)
	b.protection = 0
	b.recovery = JoustPlayer.Recovery.RESTING
	b.rest_remaining = 2
	b.position = Vector2(600, 677.8)
	b.before_position = b.position
	b.before_velocity = Vector2.ZERO
	a.before_position = Vector2(555, 677.8)
	a.position = Vector2(568, 677.8)
	a.before_velocity = Vector2(300, 0)
	combat = CombatResolver.new()
	combat.resolve([a, b])
	check(not b.effects.has(PowerupCatalog.Kind.SHIELD), "Resting shield is consumed by a body hit")
	check(b.alive and a.health == 2, "Resting shield damages the incoming player instead of executing")
	# Swap roster ordering to catch asymmetric handling of the grounded player.
	b.free()
	b = scene.instantiate() as JoustPlayer
	root.add_child(b)
	a.activate()
	a.health = 3
	a.effects.clear()
	a.protection = 0
	b.activate()
	b.recovery = JoustPlayer.Recovery.RESTING
	b.position = Vector2(600, 677.8)
	b.before_position = b.position
	b.before_velocity = Vector2.ZERO
	a.before_position = Vector2(600, 630)
	a.position = Vector2(600, 648)
	a.before_velocity = Vector2(0, 300)
	var reversed: Array[JoustPlayer] = [b, a]
	CombatResolver.new().resolve(reversed)
	check(not b.alive and a.velocity.y < 0, "Grounded execution works in either roster order and bounces a falling attacker")
	a.free()
	b.free()
	# Observe the live Area2D, not a draw-only offset: its hitbox must sweep
	# from the top of the arena to the bottom and reverse there.
	var pickup := preload("res://scenes/PowerUp.tscn").instantiate() as ArenaPickup
	pickup.position = Vector2(420, 225)
	root.add_child(pickup)
	var start := pickup.position
	pickup.sweep_direction = 1
	pickup.sweep_speed = 360.0
	pickup.sweep_top = 225.0
	pickup.sweep_bottom = 631.0
	var minimum_y := start.y
	var maximum_y := start.y
	var minimum_x := start.x
	var maximum_x := start.x
	var moving_down := false
	var moving_up := false
	for i in range(300):
		await physics_frame
		minimum_y = minf(minimum_y, pickup.position.y)
		maximum_y = maxf(maximum_y, pickup.position.y)
		minimum_x = minf(minimum_x, pickup.position.x)
		maximum_x = maxf(maximum_x, pickup.position.x)
		moving_down = moving_down or pickup.position.y > start.y + 20
		moving_up = moving_up or pickup.position.y < maximum_y - 20
	check(maximum_y - minimum_y > 350, "Powerup sweeps most of the arena vertically")
	check(moving_down and moving_up, "Powerup reverses at the opposite vertical edge")
	check(maximum_x - minimum_x < 0.01, "Powerup keeps its spawn lane while sweeping")
	check(pickup.get_node("CollisionShape2D").global_position.is_equal_approx(pickup.global_position), "Collection collider follows moving pickup")
	pickup.free()
	# Coins use the same live vertical sweep, not only a visual bob.
	var coin := preload("res://scenes/Coin.tscn").instantiate() as ArenaPickup
	coin.position = Vector2(760, 225)
	root.add_child(coin)
	var coin_start := coin.position
	coin.sweep_direction = 1
	coin.sweep_speed = 240.0
	coin.sweep_top = 225.0
	coin.sweep_bottom = 631.0
	var coin_minimum_y := coin_start.y
	var coin_maximum_y := coin_start.y
	var coin_minimum_x := coin_start.x
	var coin_maximum_x := coin_start.x
	for i in range(180):
		await physics_frame
		coin_minimum_y = minf(coin_minimum_y, coin.position.y)
		coin_maximum_y = maxf(coin_maximum_y, coin.position.y)
		coin_minimum_x = minf(coin_minimum_x, coin.position.x)
		coin_maximum_x = maxf(coin_maximum_x, coin.position.x)
	check(coin_maximum_y - coin_minimum_y > 300, "Coin sweeps vertically")
	check(coin_maximum_x - coin_minimum_x < 0.01, "Coin keeps its spawn lane while sweeping")
	check(coin.get_node("CollisionShape2D").global_position.is_equal_approx(coin.global_position), "Coin collection collider follows movement")
	coin.free()
	print("COMBAT/PICKUP RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
