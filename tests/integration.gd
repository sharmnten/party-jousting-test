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
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.show_lobby()
	game.join_or_cycle(KEY_Q)
	game.join_or_cycle(KEY_Q)
	check(game.profiles.size() == 1 and game.profiles[0].appearance == 1, "Repeated join key cycles appearance, never adds duplicate")
	for key in [KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O]:
		game.join_or_cycle(key)
	check(game.profiles.size() == 8, "Lobby caps at eight")
	game.remove_player(3)
	game.join_or_cycle(KEY_P)
	check(game.profiles.size() == 8, "Leaving frees a lobby slot")
	game.start_round()
	var arena: JoustArena = game.arena
	arena.set_physics_process(false)
	check(arena.players.size() == 8, "Round instantiates entire roster")
	for i in range(8):
		var p := arena.players[i]
		check(not p.active, "Countdown prevents early motion")
		check(InputMap.has_action(p.profile.action_name()), "Input actions generated")
		check(p.position.x > 100 and p.position.y > 100 and p.position.y < 600, "Spawn safely inset")
		for j in range(i + 1, 8):
			check(p.position.distance_to(arena.players[j].position) > 100, "Spawns separated")
	arena._physics_process(3.1)
	check(arena.running and arena.players[0].active, "Countdown activates match")
	var a := arena.players[0]
	var b := arena.players[1]
	var event := InputEventKey.new()
	event.physical_keycode = a.profile.key
	event.pressed = true
	a._input(event)
	a.prepare_step(0.016)
	check(a.velocity.y < -300, "Fresh press flaps immediately")
	a.prepare_step(0.1)
	check(a.velocity.y > -300, "Holding does not repeat flap")
	event.echo = true
	a._input(event)
	check(not a.pending_flap, "OS repeat ignored")
	a.collect_powerup(PowerupCatalog.Kind.LASER)
	var before_shots := arena.shots.size()
	event.echo = false
	a._input(event)
	a.prepare_step(0.016)
	check(arena.shots.size() == before_shots + 1, "Laser fires on flap while powered")
	a.effects.tick(5.01)
	a._input(event)
	a.prepare_step(0.016)
	check(arena.shots.size() == before_shots + 1, "Laser ceases after five seconds")
	for shot in arena.shots.duplicate():
		shot.free()
	# Real pair resolver: the higher body damages the lower body and bounces upward.
	a.protection = 0
	b.protection = 0
	a.position = Vector2(400, 300)
	b.position = Vector2(400, 330)
	a.before_position = Vector2(400, 285)
	b.before_position = b.position
	a.before_velocity = Vector2(0, 220)
	b.before_velocity = Vector2.ZERO
	var pair: Array[JoustPlayer] = [a, b]
	var resolver := CombatResolver.new()
	resolver.resolve(pair)
	check(a.health == 3 and b.health == 2 and a.velocity.y < 0, "Top hit damages only victim and rebounds attacker")
	b.protection = 0
	a.position = Vector2(400, 300)
	b.position = Vector2(400, 330)
	resolver.resolve(pair)
	check(b.health == 2, "Same contact cannot hit again after protection expires")
	# Safe powerup/coin placement and configurable caps.
	arena.spawner.random.seed = 12345
	for i in range(12):
		arena.spawner.spawn(false)
		arena.spawner.spawn(true)
	var coin_count: int = 0
	var power_count: int = 0
	var sweep_top := arena.rules.boundary_thickness + arena.rules.pickup_boundary_margin + arena.rules.hud_height
	var sweep_bottom := arena.rules.arena_size.y - arena.rules.boundary_thickness - arena.rules.pickup_boundary_margin - 1.0
	for pickup in arena.spawner.pickups:
		check(pickup.position.y > arena.rules.boundary_thickness + arena.rules.hud_height + 60, "Pickups stay clear of the ceiling")
		check(is_equal_approx(pickup.position.y, sweep_top) or is_equal_approx(pickup.position.y, sweep_bottom), "Pickup starts at a safe vertical edge")
		check(pickup.sweep_speed > 0 and pickup.sweep_direction != 0, "Pickup has a vertical sweep direction and speed")
		if pickup.is_coin:
			coin_count += 1
		else:
			power_count += 1
		for p in arena.players:
			check(pickup.position.distance_to(p.position) >= p.radius + 60, "Pickup not inside player")
	check(coin_count == 10 and power_count == 4, "Separate coin and powerup caps enforced")
	var pickup := arena.spawner.pickups[0]
	pickup._on_body_entered(a)
	pickup._on_body_entered(b)
	check(pickup.taken, "Pickup can be claimed only once")
	# Moving hazard blocks share the vertical edge sweep but damage players.
	arena.hazard_spawner.random.seed = 67890
	for i in range(8):
		arena.hazard_spawner.spawn()
	var hazard_count: int = 0
	var hazard_top := arena.rules.boundary_thickness + arena.rules.pickup_boundary_margin + arena.rules.hud_height
	var hazard_bottom := arena.rules.arena_size.y - arena.rules.boundary_thickness - arena.rules.pickup_boundary_margin - 1.0
	for hazard in arena.hazard_spawner.hazards:
		hazard_count += 1
		check(is_equal_approx(hazard.position.y, hazard_top) or is_equal_approx(hazard.position.y, hazard_bottom), "Hazard starts at a safe vertical edge")
		check(hazard.sweep_speed > 0 and hazard.sweep_direction != 0, "Hazard has a vertical sweep direction and speed")
	check(hazard_count == arena.rules.max_hazards, "Hazard capacity is enforced")
	# Physical boundary contacts use CharacterBody2D movement, including contact latch.
	a.effects.clear()
	a.health = 5
	a.protection = 0
	a.position = Vector2(200, 670)
	a.velocity = Vector2(0, 500)
	await physics_frame
	await physics_frame
	a.move_step(0.05)
	check(a.health == 4 and a.velocity.is_zero_approx() and a.is_recovering(), "Floor damages and starts stationary recovery")
	a.position = Vector2(200, 677.8)
	a.velocity = Vector2(0, 40)
	a.floor_contact = true
	a.protection = 0
	a.move_step(0.02)
	check(a.health == 4, "Continuous floor contact cannot repeat damage")
	# Independent boundary scenario: resume this fixture before testing the ceiling.
	a.activate()
	a.position = Vector2(200, arena.rules.hud_height + 48)
	a.velocity = Vector2(0, -300)
	a.protection = 0
	a.ceiling_contact = false
	a.move_step(0.05)
	check(a.health == 3 and a.velocity.y > 0, "Ceiling damages and bounces downward")
	a.activate()
	a.position = Vector2(45, 300)
	a.velocity = Vector2(-300, 0)
	a.move_step(0.05)
	check(a.facing == 1 and a.health == 3, "Side wall reverses without damage")
	# Swept laser hits at high speed, excludes shooter and does not hurt next victim.
	a.position = Vector2(300, 350)
	b.position = Vector2(380, 350)
	b.activate()
	b.health = 3
	b.protection = 0
	b.effects.clear()
	for i in range(2, 8):
		arena.players[i].position = Vector2(600 + (i - 2) * 80, 500)
	await physics_frame
	await physics_frame
	arena._fire(a)
	var laser: LaserShot = arena.shots[-1]
	laser.tick(0.2)
	check(b.health == 2 and a.health == 3 and laser.spent, "Swept laser damages target once and ignores owner")
	# Pause freezes simulation and effects; resume preserves them.
	a.effects.apply(PowerupCatalog.Kind.SPEED)
	game.toggle_pause()
	var time := a.effects.remaining[PowerupCatalog.Kind.SPEED]
	await process_frame
	await process_frame
	check(paused and a.effects.remaining[PowerupCatalog.Kind.SPEED] == time, "Pause preserves effect duration")
	game.toggle_pause()
	check(not paused, "Resume unpauses scene tree")
	# End-of-frame survivor count and clean rematch.
	for i in range(1, 8):
		var p := arena.players[i]
		p.activate() # Test lethal outcomes outside the intentionally protected recovery state.
		p.effects.clear()
		p.protection = 0
		p.take_damage(99)
	for i in range(6):
		arena._physics_process(0.016)
	check(arena.finished and not a.active, "Last survivor settles round and disables inputs")
	await create_timer(0.95).timeout
	check(game.screen == game.Screen.VICTORY, "Winner overlay appears after elimination animation")
	game.start_round()
	check(game.arena.players.size() == 8 and game.arena.players[0].health == 3 and game.arena.spawner.pickups.is_empty(), "Rematch resets health, effects, pickups")
	game.show_lobby()
	check(game.profiles.size() == 8 and not paused, "Return to lobby retains roster")
	game.start_round()
	game.arena.set_physics_process(false)
	game.arena._physics_process(3.1)
	for p in game.arena.players:
		p.protection = 0
		p.take_damage(99)
	for i in range(6):
		game.arena._physics_process(0.016)
	await create_timer(0.95).timeout
	check(game.screen == game.Screen.VICTORY, "Simultaneous final elimination resolves to draw without indexing empty roster")
	game.free()
	# AudioServer releases stopped mix-thread playback references on its next buffer.
	await create_timer(0.12).timeout
	print("INTEGRATION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
