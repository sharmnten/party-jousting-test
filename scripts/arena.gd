class_name JoustArena
extends Node2D
signal round_finished(winner: PlayerProfile)
signal countdown_changed(text: String)
signal status_changed
@export var rules: GameRules = preload("res://resources/default_rules.tres")
const PLAYER := preload("res://scenes/Player.tscn")
const LASER := preload("res://scenes/Laser.tscn")
@onready var spawner: PickupSpawner = $PickupSpawner
@onready var feedback: GameFeedback = $Feedback
var players: Array[JoustPlayer] = []
var shots: Array[LaserShot] = []
var combat := CombatResolver.new()
var running: bool = false
var finished: bool = false
var countdown: float = 3.0
var last_count: int = -1
var freeze: float = 0.0
var shake: float = 0.0
var end_delay: float = -1.0
var go_time: float = 0.0

func _ready() -> void:
	build_boundaries()
	spawner.rules = rules
	spawner.pickup_taken.connect(_pickup_taken)

func setup(profiles: Array[PlayerProfile]) -> void:
	countdown = rules.countdown_seconds
	var places := spawn_positions(profiles.size())
	for i in range(profiles.size()):
		var player := PLAYER.instantiate() as JoustPlayer
		player.rules = rules
		player.profile = profiles[i]
		player.position = places[i]
		player.facing = 1 if places[i].x < rules.arena_size.x / 2 else -1
		$Players.add_child(player)
		players.append(player)
		player.player_damaged.connect(_damaged)
		player.player_eliminated.connect(_eliminated)
		player.laser_requested.connect(_fire)
		player.flapped.connect(_flap)
		player.health_changed.connect(func(_p: JoustPlayer): status_changed.emit())
		player.coin_collected.connect(func(_p: JoustPlayer): status_changed.emit())
		player.powerup_collected.connect(func(_p: JoustPlayer, _kind: int): status_changed.emit())
		player.effects.changed.connect(func(): status_changed.emit())
	spawner.start(players)
	status_changed.emit()

func spawn_positions(count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	# Eight separated cells, with conservative jitter. No pickups exist at countdown.
	var cells: Array[Vector2] = []
	for row in range(2):
		for column in range(4):
			cells.append(Vector2(rules.arena_size.x * (0.2 + column * 0.2), rules.arena_size.y * (0.34 + row * 0.28)))
	cells.shuffle()
	for i in range(mini(count, 8)):
		spots.append(cells[i] + Vector2(randf_range(-15, 15), randf_range(-12, 12)))
	return spots

func _physics_process(delta: float) -> void:
	for player in players:
		player.presentation_step(delta)
	if finished:
		return
	if not running:
		countdown -= delta
		var number := maxi(0, ceili(countdown))
		if number != last_count:
			last_count = number
			countdown_changed.emit(str(number) if number > 0 else "GO!")
			feedback.play("go")
		if countdown <= 0:
			running = true
			go_time = 0.65
			for player in players:
				player.activate()
		return
	if go_time > 0:
		go_time -= delta
		if go_time <= 0:
			countdown_changed.emit("")
	if freeze > 0:
		freeze -= delta
		return
	for player in players:
		player.prepare_step(delta)
	for player in players:
		player.move_step(delta)
	combat.resolve(players)
	for shot in shots.duplicate():
		if is_instance_valid(shot):
			shot.tick(delta)
	spawner.tick(delta)
	var survivors: Array[JoustPlayer] = []
	for player in players:
		if player.alive:
			survivors.append(player)
	if survivors.size() <= 1:
		# Freeze outcomes now; let existing elimination visuals finish before overlay.
		running = false
		finished = true
		for player in players:
			player.active = false
		var winner: PlayerProfile = survivors[0].profile if survivors.size() == 1 else null
		_announce_winner(winner)

func _announce_winner(winner: PlayerProfile) -> void:
	# Presentation delay only; the result is already settled above.
	await get_tree().create_timer(0.85, false).timeout
	if not is_inside_tree():
		return
	feedback.play("win")
	if winner != null:
		for player in players:
			if player.alive:
				feedback.burst(player.position, AnimalSkin.COLORS[winner.appearance], 60)
	round_finished.emit(winner)

func _process(delta: float) -> void:
	shake = move_toward(shake, 0.0, delta * 28)
	$Camera2D.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

func _damaged(player: JoustPlayer, amount: int) -> void:
	feedback.burst(player.position, Color("ff728f"), 18)
	feedback.play("hit")
	shake = 5.0 + amount
	freeze = rules.hit_stop_seconds

func _eliminated(player: JoustPlayer) -> void:
	feedback.burst(player.position, AnimalSkin.COLORS[player.profile.appearance], 25)
	feedback.play("out")
	status_changed.emit()

func _flap(_player: JoustPlayer) -> void:
	feedback.play("flap")

func _fire(player: JoustPlayer) -> void:
	var shot := LASER.instantiate() as LaserShot
	shot.shooter = player
	shot.direction = player.facing
	shot.speed = rules.laser_speed
	# Start within owner's body, exclude owner. This also hits point-blank targets.
	shot.position = player.position + Vector2(player.facing * player.radius * 0.5, 0)
	shot.impacted.connect(func(location: Vector2, color: Color): feedback.burst(location, color, 8))
	shot.tree_exiting.connect(func(): shots.erase(shot))
	shots.append(shot)
	$Projectiles.add_child(shot)

func _pickup_taken(pickup: ArenaPickup, player: JoustPlayer) -> void:
	var color := Color("ffd477") if pickup.is_coin else PowerupCatalog.COLORS[pickup.kind]
	feedback.burst(player.position, color)
	feedback.play("coin" if pickup.is_coin else "power")

func build_boundaries() -> void:
	var size := rules.arena_size
	var thickness := rules.boundary_thickness
	var specs: Array[Rect2] = [Rect2(0, 0, thickness, size.y), Rect2(size.x - thickness, 0, thickness, size.y), Rect2(0, size.y - thickness, size.x, thickness), Rect2(0, 0, size.x, thickness + rules.hud_height)]
	var names: Array[String] = ["LeftWall", "RightWall", "Floor", "Ceiling"]
	for i in range(specs.size()):
		var body := $Boundaries.get_node(names[i]) as StaticBody2D
		body.position = specs[i].get_center()
		body.collision_layer = 2 if i < 2 else (4 if i == 2 else 8)
		body.collision_mask = 0
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = specs[i].size
		collider.shape = rectangle
		body.add_child(collider)
	$Camera2D.position = size * 0.5
	$Camera2D.zoom = Vector2.ONE * minf(1280.0 / size.x, 720.0 / size.y)
	queue_redraw()

func _draw() -> void:
	var size := rules.arena_size
	draw_rect(Rect2(Vector2.ZERO, size), Color("10182c"))
	for x in range(40, int(size.x), 40):
		for y in range(40, int(size.y), 40):
			draw_circle(Vector2(x, y), 1, Color("243049"))
	var t := rules.boundary_thickness
	var ceiling_y := t + rules.hud_height
	for y in [ceiling_y, size.y - t]:
		draw_line(Vector2(t, y), Vector2(size.x - t, y), Color("ff657f"), 3)
		for x in range(int(t), int(size.x - t), 24):
			var direction := -1 if y == ceiling_y else 1
			draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 9, y + direction * 9), Vector2(x + 18, y)]), Color("783851"))
	for x in [t, size.x - t]:
		draw_line(Vector2(x, ceiling_y), Vector2(x, size.y - t), Color("6de2ca"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2 - 180, size.y / 2), "PARTY  /  JOUSTING", HORIZONTAL_ALIGNMENT_CENTER, 360, 32, Color(0.4, 0.5, 0.7, 0.12))
