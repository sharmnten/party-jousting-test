extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/artifacts/" + file + ".png")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await capture("home")
	game.show_lobby()
	for key in [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_U, KEY_I, KEY_O, KEY_P]:
		game.join_or_cycle(key)
	await capture("lobby")
	game.start_round()
	game.arena.set_physics_process(false)
	game.arena._physics_process(3.1)
	game.ui.set_countdown("")
	for i in range(8):
		var player: JoustPlayer = game.arena.players[i]
		player.protection = 0
		player.position = Vector2(180 + i % 4 * 290, 260 + i / 4 * 225)
		player.collect_powerup([0, 1, 9, 5, 4, 2, 3, 7][i])
		player.presentation_step(0.016)
	for i in range(4):
		game.arena.spawner.spawn(false)
	for i in range(8):
		game.arena.spawner.spawn(true)
	await capture("arena")
	game.toggle_pause()
	await capture("pause")
	game.toggle_pause()
	game.ui.show_victory(game.profiles[0])
	await capture("victory")
	game.free()
	await process_frame
	quit()
