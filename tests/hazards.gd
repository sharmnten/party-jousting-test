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
	var hazard := preload("res://scenes/HazardBlock.tscn").instantiate() as HazardBlock
	hazard.position = Vector2(760, 89)
	root.add_child(hazard)
	hazard.sweep_direction = 1
	hazard.sweep_speed = 240.0
	hazard.sweep_top = 89.0
	hazard.sweep_bottom = 630.0
	var start := hazard.position
	var minimum_y := start.y
	var maximum_y := start.y
	var minimum_x := start.x
	var maximum_x := start.x
	for i in range(180):
		await physics_frame
		minimum_y = minf(minimum_y, hazard.position.y)
		maximum_y = maxf(maximum_y, hazard.position.y)
		minimum_x = minf(minimum_x, hazard.position.x)
		maximum_x = maxf(maximum_x, hazard.position.x)
	check(maximum_y - minimum_y > 300, "Hazard block sweeps vertically")
	check(maximum_x - minimum_x < 0.01, "Hazard block keeps its spawn lane")
	check(hazard.get_node("CollisionShape2D").global_position.is_equal_approx(hazard.global_position), "Hazard collider follows movement")

	var player := preload("res://scenes/Player.tscn").instantiate() as JoustPlayer
	root.add_child(player)
	player.activate()
	player.protection = 0
	player.position = Vector2(200, 300)
	hazard._on_body_entered(player)
	check(player.health == 2, "Hazard contact removes one heart")
	hazard._on_body_entered(player)
	check(player.health == 2, "Repeated hazard callback cannot immediately repeat damage")
	hazard._on_body_exited(player)
	player.protection = 0
	player.recovery = JoustPlayer.Recovery.NONE
	hazard._on_body_entered(player)
	check(player.health == 1, "Hazard can damage again after separation")
	player.free()
	hazard.free()
	print("HAZARD RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
