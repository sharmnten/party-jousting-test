class_name PickupSpawner
extends Node2D
signal pickup_taken(pickup: ArenaPickup, player: JoustPlayer)
@export var rules: GameRules = preload("res://resources/default_rules.tres")
# Same enum order as PowerupCatalog.Kind. Zero disables a type.
@export var weights: Array[float] = [2.0, 4.0, 3.0, 2.0, 2.0, 1.0, 3.0, 1.0, 1.0, 3.0]
@export_range(25.0, 500.0, 5.0) var powerup_sweep_speed: float = 120.0 # Slower default keeps powerups readable and collectible.
@export_range(25.0, 500.0, 5.0) var coin_sweep_speed: float = 90.0
const COIN := preload("res://scenes/Coin.tscn")
const POWERUP := preload("res://scenes/PowerUp.tscn")
var players: Array[JoustPlayer] = []
var pickups: Array[ArenaPickup] = []
var random := RandomNumberGenerator.new()
var coin_time: float = 0.0
var powerup_time: float = 0.0

func start(roster: Array[JoustPlayer]) -> void:
	players = roster
	random.randomize()
	coin_time = rules.coin_interval
	powerup_time = rules.first_powerup_delay

func tick(delta: float) -> void:
	coin_time -= delta
	powerup_time -= delta
	if coin_time <= 0:
		spawn(true)
		coin_time = maxf(0.1, rules.coin_interval)
	if powerup_time <= 0:
		spawn(false)
		powerup_time = random.randf_range(maxf(0.1, rules.powerup_interval_min), maxf(rules.powerup_interval_min, rules.powerup_interval_max))

func spawn(coin: bool) -> ArenaPickup:
	var count: int = 0
	for pickup in pickups:
		if is_instance_valid(pickup) and not pickup.taken and pickup.is_coin == coin:
			count += 1
	if count >= (rules.max_coins if coin else rules.max_powerups):
		return null
	var direction := 1 if random.randf() < 0.5 else -1
	var location := safe_location(direction)
	if not location.is_finite():
		return null # Crowded arenas skip this spawn; never force an invalid location.
	var selected_kind := choose_kind() if not coin else 0
	if selected_kind < 0:
		return null
	var pickup := (COIN if coin else POWERUP).instantiate() as ArenaPickup
	pickup.position = location
	pickup.kind = selected_kind
	pickup.sweep_direction = direction if direction != 0 else 1
	pickup.sweep_speed = coin_sweep_speed if coin else powerup_sweep_speed
	pickup.sweep_top = rules.boundary_thickness + rules.pickup_boundary_margin + rules.hud_height
	pickup.sweep_bottom = rules.arena_size.y - rules.boundary_thickness - rules.pickup_boundary_margin - 1.0
	pickup.collected.connect(_collected)
	pickup.tree_exiting.connect(_remove.bind(pickup))
	pickups.append(pickup)
	add_child(pickup)
	return pickup

func choose_kind() -> int:
	var total: float = 0.0
	for i in range(mini(weights.size(), PowerupCatalog.Kind.size())):
		total += maxf(0.0, weights[i])
	if total <= 0:
		return -1
	var roll := random.randf() * total
	for i in range(mini(weights.size(), PowerupCatalog.Kind.size())):
		roll -= maxf(0.0, weights[i])
		if roll < 0:
			return i
	return -1

func safe_location(vertical_direction: int = 0) -> Vector2:
	var margin := rules.boundary_thickness + rules.pickup_boundary_margin
	for attempt in range(80):
		var x := random.randf_range(margin, rules.arena_size.x - margin)
		var y := random.randf_range(margin + rules.hud_height, rules.arena_size.y - margin)
		if vertical_direction > 0:
			y = margin + rules.hud_height
		elif vertical_direction < 0:
			# Stay one pixel inside Rect2's exclusive bottom edge.
			y = rules.arena_size.y - margin - 1.0
		var candidate := Vector2(x, y)
		if location_is_safe(candidate):
			return candidate
	return Vector2(INF, INF)

func location_is_safe(candidate: Vector2) -> bool:
	var margin := rules.boundary_thickness + rules.pickup_boundary_margin
	if not Rect2(Vector2(margin, margin + rules.hud_height), rules.arena_size - Vector2(margin * 2, margin * 2 + rules.hud_height)).has_point(candidate):
		return false
	for player in players:
		if player.alive and candidate.distance_to(player.position) < player.radius + 60:
			return false
	for pickup in pickups:
		if is_instance_valid(pickup) and not pickup.taken:
			if candidate.distance_to(pickup.origin_position) < 64:
				return false
	# Also exclude future static hazards/obstacles added to the scene.
	if is_inside_tree():
		var circle := CircleShape2D.new()
		circle.radius = 26
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = circle
		query.transform = Transform2D(0, global_position + candidate)
		query.collision_mask = 14 | 64
		query.collide_with_areas = true
		if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			return false
	return true

func _collected(pickup: ArenaPickup, player: JoustPlayer) -> void:
	pickup_taken.emit(pickup, player)

func _remove(pickup: ArenaPickup) -> void:
	pickups.erase(pickup)
