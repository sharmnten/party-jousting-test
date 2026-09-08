class_name AnimalSkin
extends Node2D
const COLORS: Array[Color] = [Color("75ddc4"), Color("ffbb75"), Color("c1a3ff"), Color("ff84ac"), Color("8ecbff"), Color("f5e478"), Color("a5e48d"), Color("ded9f8")]
const NAMES: Array[String] = ["Frog", "Fox", "Bat", "Bunny", "Bird", "Bee", "Cat", "Owl"]
var appearance: int = 0
var facing: int = 1
var squash := Vector2.ONE
var body_scale: float = 1.0
var shield: bool = false
var invincible: bool = false
var laser: bool = false
var speed_effect: bool = false
var clock: float = 0.0

func _process(delta: float) -> void:
	clock += delta
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	queue_redraw()

func flap() -> void:
	squash = Vector2(1.25, 0.72)

func _draw() -> void:
	var color := COLORS[appearance % COLORS.size()]
	if speed_effect:
		for i in range(1, 5):
			draw_circle(Vector2(-facing * i * 10.0, sin(clock * 12.0 - i) * 3.0), 13.0 - i * 2, Color(color, 0.3 / i))
	draw_set_transform(Vector2.ZERO, 0, squash * body_scale)
	draw_circle(Vector2(0, 3), 19, Color("0c152a"))
	draw_circle(Vector2.ZERO, 18, color)
	match appearance % 8:
		0:
			draw_circle(Vector2(-11, -14), 8, color)
			draw_circle(Vector2(11, -14), 8, color)
		1, 6:
			for x in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([Vector2(x * 17, -6), Vector2(x * 15, -29), Vector2(x * 3, -14)]), color)
		2:
			for x in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([Vector2(x * 12, 0), Vector2(x * 34, -12), Vector2(x * 29, 10)]), color.darkened(0.2))
		3:
			draw_style_box(_ear(color), Rect2(-13, -38, 9, 28))
			draw_style_box(_ear(color), Rect2(4, -38, 9, 28))
		5:
			draw_line(Vector2(-10, -12), Vector2(-10, 12), Color("322a40"), 5)
			draw_line(Vector2(-1, -15), Vector2(-1, 15), Color("322a40"), 5)
	for x in [-1, 1]:
		draw_circle(Vector2(x * 7 + facing * 3, -5), 5.0, Color.WHITE)
		draw_circle(Vector2(x * 7 + facing * 5, -5), 2.4, Color("17223b"))
	draw_colored_polygon(PackedVector2Array([Vector2(facing * 15, 0), Vector2(facing * 26, 5), Vector2(facing * 15, 8)]), Color("ffdb7d"))
	draw_arc(Vector2(0, 3), 8, 0.3, 2.6, 12, Color("17223b"), 1.7, true)
	draw_set_transform(Vector2.ZERO)
	if shield or invincible:
		var ring_color := Color("fff3a1") if invincible else Color("72dbff")
		draw_arc(Vector2.ZERO, 26 * body_scale + sin(clock * 5) * 2, 0, TAU, 48, ring_color, 2.5, true)
	if laser:
		draw_line(Vector2(facing * 18, 2), Vector2(facing * 33, 2), Color("ff6075"), 5)

func _ear(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
