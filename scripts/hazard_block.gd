class_name HazardBlock
extends Area2D

signal player_hit(hazard: HazardBlock, player: JoustPlayer)

@export_range(25.0, 500.0, 5.0) var sweep_speed: float = 95.0
@export_range(-1.0, 1.0, 1.0) var sweep_direction: int = 1
@export var sweep_top: float = 89.0
@export var sweep_bottom: float = 630.0
@export var damage: int = 1

var age: float = 0.0
var origin_position := Vector2.ZERO
var contacts: Dictionary = {}

func _ready() -> void:
	origin_position = position
	sweep_direction = 1 if sweep_direction >= 0 else -1
	collision_layer = 64
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	age += delta
	# Move the Area2D itself so the visible block and its damage shape stay together.
	var next_y := position.y + sweep_direction * sweep_speed * delta
	if next_y >= sweep_bottom:
		next_y = sweep_bottom
		sweep_direction = -1
	elif next_y <= sweep_top:
		next_y = sweep_top
		sweep_direction = 1
	position = Vector2(origin_position.x, next_y)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body is JoustPlayer:
		return
	var player := body as JoustPlayer
	var id := player.get_instance_id()
	if contacts.has(id) or not player.alive or not player.active:
		return
	contacts[id] = true
	player.take_damage(damage)
	player_hit.emit(self, player)

func _on_body_exited(body: Node2D) -> void:
	if body is JoustPlayer:
		contacts.erase((body as JoustPlayer).get_instance_id())

func _draw() -> void:
	var pulse := 1.0 + sin(age * 5.0) * 0.04
	var size := Vector2(44, 44) * pulse
	draw_rect(Rect2(-size * 0.5, size), Color("e05263"), true)
	draw_rect(Rect2(-size * 0.5, size), Color("ff9a72"), false, 3.0)
	draw_line(Vector2(-13, -13), Vector2(13, 13), Color("5c203d"), 3.0)
	draw_line(Vector2(13, -13), Vector2(-13, 13), Color("5c203d"), 3.0)
