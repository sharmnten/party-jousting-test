class_name LaserShot
extends Node2D
signal impacted(location: Vector2, color: Color)
var shooter: JoustPlayer
var direction: int = 1
var speed: float = 850.0
var lifetime: float = 1.8
var spent: bool = false

func tick(delta: float) -> void:
	if spent:
		return
	lifetime -= delta
	if lifetime <= 0:
		spent = true
		queue_free()
		return
	var target := global_position + Vector2(direction * speed * delta, 0)
	var ray := PhysicsRayQueryParameters2D.create(global_position, target, 15)
	if is_instance_valid(shooter):
		ray.exclude = [shooter.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var body: Object = hit.get("collider")
		if body is JoustPlayer and body != shooter:
			(body as JoustPlayer).take_damage(1)
		global_position = hit.get("position", target)
		impacted.emit(global_position, Color("ff708a"))
		spent = true
		queue_free()
	else:
		global_position = target

func _draw() -> void:
	draw_line(Vector2(-direction * 21, 0), Vector2(direction * 3, 0), Color("ff4d7a"), 7, true)
	draw_line(Vector2(-direction * 17, 0), Vector2(direction * 3, 0), Color("fff4ed"), 2, true)
