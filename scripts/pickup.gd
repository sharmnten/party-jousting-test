class_name ArenaPickup
extends Area2D
signal collected(pickup: ArenaPickup, player: JoustPlayer)
@export var is_coin: bool = false
@export_range(25.0, 500.0, 5.0) var sweep_speed: float = 180.0
@export_range(-1.0, 1.0, 1.0) var sweep_direction: int = 1
@export var sweep_top: float = 225.0
@export var sweep_bottom: float = 631.0
@export_enum("Shield", "Speed", "Super Flap", "Heavy", "Tiny", "Giant", "Health", "Invincibility", "Random", "Laser") var kind: int = 0
var taken: bool = false
var age: float = 0.0
var origin_position := Vector2.ZERO

func _ready() -> void:
	origin_position = position
	sweep_direction = 1 if sweep_direction >= 0 else -1
	body_entered.connect(_on_body_entered)
	collision_layer = 32 if is_coin else 16
	collision_mask = 1

func _process(_delta: float) -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	if taken:
		return
	age += delta
	# Move the Area2D itself, keeping artwork and collection shape together.
	# Coins and powerups cross the arena from one safe vertical edge to the other, then reverse.
	# Positive direction travels downward; negative direction travels upward.
	var next_y := position.y + sweep_direction * sweep_speed * delta
	if next_y >= sweep_bottom:
		next_y = sweep_bottom
		sweep_direction = -1
	elif next_y <= sweep_top:
		next_y = sweep_top
		sweep_direction = 1
	position = Vector2(origin_position.x, next_y)

func _on_body_entered(body: Node2D) -> void:
	if taken or not body is JoustPlayer:
		return
	var player := body as JoustPlayer
	if not player.alive or not player.active or player.is_recovering():
		return
	taken = true # First callback owns pickup, even if several bodies enter together.
	if is_coin:
		player.collect_coin()
	else:
		player.collect_powerup(kind)
	collected.emit(self, player)
	set_deferred("monitoring", false)
	queue_free()

func _draw() -> void:
	var offset := Vector2(0, sin(age * 3.5) * 3) if is_coin else Vector2.ZERO
	if is_coin:
		draw_circle(offset, 10, Color("ffc857"))
		draw_arc(offset, 7, 0, TAU, 24, Color("fff2b3"), 1.5, true)
		draw_line(offset + Vector2(0, -4), offset + Vector2(0, 4), Color("946a27"), 2)
	else:
		var color := PowerupCatalog.COLORS[kind]
		draw_circle(offset, 24 + sin(age * 4) * 2, Color(color, 0.08))
		draw_style_box(_box(color), Rect2(offset - Vector2(18, 18), Vector2(36, 36)))
		var symbol := PowerupCatalog.SYMBOLS[kind]
		draw_string(ThemeDB.fallback_font, offset + Vector2(-15, 6), symbol, HORIZONTAL_ALIGNMENT_CENTER, 30, 18, Color("111a2e"))
		draw_string(ThemeDB.fallback_font, offset + Vector2(-55, 36), PowerupCatalog.NAMES[kind], HORIZONTAL_ALIGNMENT_CENTER, 110, 13, color)

func _box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	return style
