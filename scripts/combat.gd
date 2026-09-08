class_name CombatResolver
extends RefCounted
# Contacts are latched until separation: cooldown alone cannot repeat a held contact.
var contacts: Dictionary = {}
const VERTICAL_CONTACT_THRESHOLD := 0.15

static func is_stomp(normal: Vector2, attacker_velocity: Vector2, victim_velocity: Vector2, relative_y: float, combined_radius: float) -> bool:
	return normal.y < -0.65 and relative_y < -combined_radius * 0.45 and attacker_velocity.y > 40.0 and attacker_velocity.y - victim_velocity.y > 30.0

func resolve(players: Array[JoustPlayer]) -> void:
	var current: Dictionary = {}
	for i in range(players.size()):
		var a := players[i]
		if not a.alive or a.recovery == JoustPlayer.Recovery.DROPPING:
			continue
		for j in range(i + 1, players.size()):
			if not a.alive or a.recovery == JoustPlayer.Recovery.DROPPING:
				break
			var b := players[j]
			if not b.alive or b.recovery == JoustPlayer.Recovery.DROPPING:
				continue
			if a.is_recovering() and b.is_recovering():
				continue
			var key := Vector2i(i, j)
			var radius := a.radius + b.radius
			var start := a.before_position - b.before_position
			var end := a.position - b.position
			var normal := _swept_normal(start, end, radius)
			# Only retain an EXISTING contact in the separation margin. Proximity
			# must never latch a new pair before its first physical collision.
			if contacts.has(key) and end.length() <= radius + 5.0:
				current[key] = true
			if normal == Vector2.ZERO:
				continue
			current[key] = true
			var shield_contact := false
			if not contacts.has(key):
				# A shield is a contact counter, not a height check: consume it and
				# damage the other player regardless of which body is higher.
				var a_shielded := a.effects.consume_shield()
				var b_shielded := b.effects.consume_shield()
				shield_contact = a_shielded or b_shielded
				if a_shielded:
					b.take_damage(1)
				if b_shielded:
					a.take_damage(1)
			if not shield_contact and b.recovery == JoustPlayer.Recovery.RESTING:
				if a.before_velocity.dot(normal) < -1.0:
					b.finish_grounded()
					if normal.y < -0.5:
						a.velocity.y = -a.rules.attack_bounce
				continue
			if not shield_contact and a.recovery == JoustPlayer.Recovery.RESTING:
				if b.before_velocity.dot(-normal) < -1.0:
					a.finish_grounded()
					if normal.y > 0.5:
						b.velocity.y = -b.rules.attack_bounce
				continue
			if not shield_contact and not contacts.has(key):
				# The contact normal identifies which body is higher at the actual
				# impact point. The upper player wins even while rising or moving
				# sideways; only nearly level contacts remain harmless side bumps.
				if normal.y < -VERTICAL_CONTACT_THRESHOLD:
					b.take_damage(a.effects.stomp_damage())
					a.velocity.y = -a.rules.attack_bounce
					b.velocity.y = maxf(b.velocity.y, 160)
				elif normal.y > VERTICAL_CONTACT_THRESHOLD:
					a.take_damage(b.effects.stomp_damage())
					b.velocity.y = -b.rules.attack_bounce
					a.velocity.y = maxf(a.velocity.y, 160)
				else:
					var side := signf(normal.x)
					if absf(side) < 0.1:
						side = -1.0 if i % 2 == 0 else 1.0
					a.facing = int(side)
					b.facing = -int(side)
					a.knockback_x = side * a.rules.knockback
					b.knockback_x = -side * b.rules.knockback
					if absf(normal.y) > 0.65:
						a.velocity.y = normal.y * 120
						b.velocity.y = -normal.y * 120
			# Correct even a swept pass-through back to the original side of contact.
			if a.is_recovering() or b.is_recovering():
				continue
			var correction := maxf(0, radius + 0.5 - end.dot(normal)) * 0.5
			a.position += normal * correction
			b.position -= normal * correction
	contacts = current
	# Several modest projection passes stabilize crowds and size-changing effects.
	for iteration in range(4):
		for i in range(players.size()):
			var a := players[i]
			if not a.alive or a.is_recovering():
				continue
			for j in range(i + 1, players.size()):
				var b := players[j]
				if not b.alive or b.is_recovering():
					continue
				var difference := a.position - b.position
				var distance := difference.length()
				var depth := a.radius + b.radius + 0.2 - distance
				if depth > 0:
					var normal := difference / distance if distance > 0.001 else Vector2.RIGHT
					a.position += normal * depth * 0.5
					b.position -= normal * depth * 0.5
				a.contain()
				b.contain()

static func _swept_normal(start: Vector2, end: Vector2, radius: float) -> Vector2:
	if start.length_squared() <= radius * radius:
		return start.normalized() if start.length() > 0.001 else Vector2.RIGHT
	var travel := end - start
	var aa := travel.length_squared()
	if aa < 0.000001:
		return Vector2.ZERO
	var bb := 2.0 * start.dot(travel)
	var cc := start.length_squared() - radius * radius
	var discriminant := bb * bb - 4 * aa * cc
	if discriminant < 0:
		return Vector2.ZERO
	var t := (-bb - sqrt(discriminant)) / (2 * aa)
	return (start + travel * t).normalized() if t >= 0 and t <= 1 else Vector2.ZERO
