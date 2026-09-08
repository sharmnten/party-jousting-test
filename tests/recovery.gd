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
	game.join_or_cycle(KEY_P)
	game.start_round()
	var arena: JoustArena = game.arena
	arena.set_physics_process(false)
	arena.feedback.muted = true
	arena._physics_process(3.1)
	var p := arena.players[0]
	var other := arena.players[1]
	p.position = Vector2(300, 450)
	p.protection = 0
	p.effects.apply(PowerupCatalog.Kind.LASER)
	check(p.take_damage(1), "Nonlethal hit starts recovery")
	# Real movement must fall straight down and settle, not auto-flap/bounce away.
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	p._input(event)
	var landed: bool = false
	for i in range(90):
		p.prepare_step(1.0 / 60)
		p.move_step(1.0 / 60)
		if p.recovery == JoustPlayer.Recovery.RESTING and not landed:
			landed = true
			check(is_equal_approx(p.rest_remaining, 2.0), "Full two-second rest begins on landing")
		await physics_frame
	check(is_equal_approx(p.position.x, 300), "Damaged player falls without horizontal movement")
	check(p.position.y > 675 and p.velocity.is_zero_approx(), "Player sits motionless on floor after landing")
	check(p.health == 2, "Recovery landing does not cause extra floor damage")
	check(arena.shots.is_empty(), "Recovery input cannot flap or fire laser")
	var grounded := p.position
	# A player who is merely nearby cannot shove a resting player; actual body
	# contact is covered by tests/combat_pickups.gd and executes the victim.
	other.position = grounded + Vector2(300, 0)
	other.before_position = other.position
	other.before_velocity = Vector2.LEFT * 200
	var pair: Array[JoustPlayer] = [p, other]
	CombatResolver.new().resolve(pair)
	check(p.position.is_equal_approx(grounded), "Collision cannot move the resting player")
	p.protection = 0
	check(not p.take_damage(1) and p.health == 2, "Recovery rejects further normal damage")
	game.toggle_pause()
	var time_before_pause := p.rest_remaining
	await create_timer(0.05).timeout
	check(p.position.is_equal_approx(grounded), "Pause keeps recovery stationary")
	check(p.rest_remaining == time_before_pause, "Pause preserves remaining recovery time")
	game.toggle_pause()
	for i in range(150):
		p.prepare_step(1.0 / 60)
		p.move_step(1.0 / 60)
		# Stop at the recovery launch to inspect protection before another landing.
		if p.velocity.y < 0:
			break
	check(p.velocity.y < 0 and p.protection > 0, "Recovery ends with an upward launch and protection")
	check(not p.pending_flap and arena.shots.is_empty(), "Recovery does not buffer old input for release")
	p._input(event)
	p.prepare_step(1.0 / 60)
	check(p.velocity.y < -300, "Fresh input works after recovery")
	# Shield absorption never removes control; lethal damage still eliminates.
	p.effects.clear()
	p.effects.apply(PowerupCatalog.Kind.SHIELD)
	p.protection = 0
	check(not p.take_damage(1), "Shield still absorbs hit")
	p._input(event)
	check(p.pending_flap, "Shielded hit does not disable controls")
	p.protection = 0
	p.take_damage(99)
	check(not p.alive, "Lethal hits eliminate instead of resting")
	game.free()
	await create_timer(0.12).timeout
	print("RECOVERY RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
