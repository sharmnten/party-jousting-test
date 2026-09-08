class_name HazardSpawner
extends Node2D

signal hazard_hit(hazard: HazardBlock, player: JoustPlayer)

@export var rules: GameRules = preload("res://resources/default_rules.tres")
@export_range(25.0, 500.0, 5.0) var hazard_sweep_speed: float = 95.0
const HAZARD := preload("res://scenes/HazardBlock.tscn")

var players: Array[JoustPlayer] = []
var hazards: Array[HazardBlock] = []
var random := RandomNumberGenerator.new()
var hazard_time: float = 0.0

func start(roster: Array[JoustPlayer]) -> void:
	players = roster
	random.randomize()
	hazard_time = rules.first_hazard_delay

func tick(delta: float) -> void:
	hazard_time -= delta
	if hazard_time <= 0.0:
		spawn()
		hazard_time = random.randf_range(maxf(0.1, rules.hazard_interval_min), maxf(rules.hazard_interval_min, rules.hazard_interval_max))

func spawn() -> HazardBlock:
	var count := 0
	for hazard in hazards:
		if is_instance_valid(hazard):
			count += 1
	if count >= rules.max_hazards:
		return null
	var direction := 1 if random.randf() < 0.5 else -1
	var location := safe_location(direction)
	if not location.is_finite():
		return null
	var hazard := HAZARD.instantiate() as HazardBlock
	hazard.position = location
	hazard.sweep_direction = direction
	hazard.sweep_speed = hazard_sweep_speed
	hazard.sweep_top = rules.boundary_thickness + rules.pickup_boundary_margin + rules.hud_height
	hazard.sweep_bottom = rules.arena_size.y - rules.boundary_thickness - rules.pickup_boundary_margin - 1.0
	hazard.player_hit.connect(_hazard_hit)
	hazard.tree_exiting.connect(_remove.bind(hazard))
	hazards.append(hazard)
	add_child(hazard)
	return hazard

func safe_location(vertical_direction: int) -> Vector2:
	var margin := rules.boundary_thickness + rules.pickup_boundary_margin
	for attempt in range(80):
		var candidate := Vector2(random.randf_range(margin, rules.arena_size.x - margin), random.randf_range(margin + rules.hud_height, rules.arena_size.y - margin))
		if vertical_direction > 0:
			candidate.y = margin + rules.hud_height
		else:
			candidate.y = rules.arena_size.y - margin - 1.0
		if location_is_safe(candidate):
			return candidate
	return Vector2(INF, INF)

func location_is_safe(candidate: Vector2) -> bool:
	var margin := rules.boundary_thickness + rules.pickup_boundary_margin
	if not Rect2(Vector2(margin, margin + rules.hud_height), rules.arena_size - Vector2(margin * 2, margin * 2 + rules.hud_height)).has_point(candidate):
		return false
	for player in players:
		if player.alive and candidate.distance_to(player.position) < player.radius + 70.0:
			return false
	for hazard in hazards:
		if is_instance_valid(hazard) and candidate.distance_to(hazard.origin_position) < 80.0:
			return false
	if is_inside_tree():
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(44, 44)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = rectangle
		query.transform = Transform2D(0, global_position + candidate)
		query.collision_mask = 14 | 16 | 32 | 64
		query.collide_with_areas = true
		if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			return false
	return true

func _hazard_hit(hazard: HazardBlock, player: JoustPlayer) -> void:
	hazard_hit.emit(hazard, player)

func _remove(hazard: HazardBlock) -> void:
	hazards.erase(hazard)
