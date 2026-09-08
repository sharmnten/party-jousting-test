extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(24680)
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.show_lobby()
	for key in [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I]:
		game.join_or_cycle(key)
	game.start_round()
	var arena: JoustArena = game.arena
	arena.set_physics_process(false)
	arena.feedback.muted = true
	arena._physics_process(3.1)
	# Seed a crowded cluster. Must separate and remain contained without NaNs.
	for i in range(8):
		arena.players[i].position = Vector2(640 + i * 4, 360)
		arena.players[i].protection = INF
	var peak_shots: int = 0
	for frame in range(3600):
		for p in arena.players:
			if p.velocity.y > 0 and p.position.y > 320 + p.profile.id * 20:
				p.pending_flap = true
			if frame % 300 == 0:
				p.collect_powerup((frame / 300 + p.profile.id) % PowerupCatalog.Kind.size())
		arena._physics_process(1.0 / 60.0)
		peak_shots = maxi(peak_shots, arena.shots.size())
		for p in arena.players:
			var inset := arena.rules.boundary_thickness + p.radius
			if not p.position.is_finite() or p.position.x < inset - 1 or p.position.x > arena.rules.arena_size.x - inset + 1 or p.position.y < inset + arena.rules.hud_height - 1 or p.position.y > arena.rules.arena_size.y - inset + 1:
				failures += 1
		await physics_frame
	var overlaps: int = 0
	for i in range(8):
		for j in range(i + 1, 8):
			var a := arena.players[i]
			var b := arena.players[j]
			if a.position.distance_to(b.position) < a.radius + b.radius - 2:
				overlaps += 1
	if overlaps > 0:
		failures += overlaps
	print("STRESS RESULT: 3600 steps / 60 simulated seconds / 8 players; %d containment failures or final overlaps; peak %d lasers" % [failures, peak_shots])
	game.free()
	await process_frame
	quit(1 if failures else 0)
