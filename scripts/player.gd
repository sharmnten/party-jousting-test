class_name JoustPlayer
extends CharacterBody2D
enum Recovery { NONE, DROPPING, RESTING }
signal player_damaged(player: JoustPlayer, amount: int)
signal player_eliminated(player: JoustPlayer)
signal coin_collected(player: JoustPlayer)
signal health_changed(player: JoustPlayer)
signal flapped(player: JoustPlayer)
signal laser_requested(player: JoustPlayer)
signal powerup_collected(player: JoustPlayer, kind: int)
@export var rules: GameRules = preload("res://resources/default_rules.tres")
@export var profile: PlayerProfile = PlayerProfile.new()
@onready var effects: PlayerEffects = $Effects
@onready var skin: AnimalSkin = $Skin
@onready var shape: CollisionShape2D = $CollisionShape2D
var health: int = 3
var coins: int = 0
var alive: bool = true
var active: bool = false
var protection: float = 0.0
var facing: int = 1
var radius: float = 18.0
var knockback_x: float = 0.0
var before_position := Vector2.ZERO
var before_velocity := Vector2.ZERO
var pending_flap: bool = false
var floor_contact: bool = false
var ceiling_contact: bool = false
var death_time: float = 0.0
var recovery: Recovery = Recovery.NONE
var rest_remaining: float = 0.0

func is_recovering() -> bool:
	return recovery != Recovery.NONE

func _ready() -> void:
	health = rules.starting_health
	radius = rules.player_radius
	effects.rules = rules
	shape.shape = shape.shape.duplicate()
	skin.appearance = profile.appearance
	collision_layer = 1
	collision_mask = 14 # Walls + floor + ceiling. Combat resolver owns player pairs.

func _input(event: InputEvent) -> void:
	if not active or not alive or is_recovering():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed(profile.action_name()):
			pending_flap = true

func activate() -> void:
	active = true
	recovery = Recovery.NONE
	rest_remaining = 0.0
	protection = rules.spawn_protection
	pending_flap = false
	velocity = Vector2(facing * rules.horizontal_speed, -90)

func prepare_step(delta: float) -> void:
	if not alive or not active:
		return
	protection = maxf(0.0, protection - delta)
	effects.tick(delta)
	radius = rules.player_radius * effects.size_multiplier()
	(shape.shape as CircleShape2D).radius = radius
	if is_recovering():
		pending_flap = false
		knockback_x = 0.0
		velocity.x = 0.0
		if recovery == Recovery.RESTING:
			position.y = rules.arena_size.y - rules.boundary_thickness - radius - 0.2
			rest_remaining = maxf(0.0, rest_remaining - delta)
			velocity = Vector2.ZERO
			if rest_remaining <= 0:
				recovery = Recovery.NONE
				protection = rules.damage_protection
				velocity.y = -rules.floor_bounce
			else:
				before_position = position
				before_velocity = velocity
				return
		else:
			velocity.y = minf(maxf(0.0, velocity.y) + rules.gravity * delta, rules.max_fall_speed)
			before_position = position
			before_velocity = velocity
			return
	knockback_x = move_toward(knockback_x, 0.0, 260.0 * delta)
	velocity.x = facing * rules.horizontal_speed * effects.speed_multiplier() + knockback_x
	velocity.y = minf(velocity.y + rules.gravity * effects.gravity_multiplier() * delta, rules.max_fall_speed)
	if pending_flap:
		pending_flap = false
		velocity.y = -rules.flap_strength * effects.flap_multiplier()
		skin.flap()
		flapped.emit(self)
		if effects.has(PowerupCatalog.Kind.LASER):
			laser_requested.emit(self)
	before_position = position
	before_velocity = velocity

func move_step(delta: float) -> void:
	if not alive or not active:
		return
	if recovery == Recovery.RESTING:
		velocity = Vector2.ZERO
		return
	var motion := velocity * delta
	for iteration in range(3):
		var hit := move_and_collide(motion)
		if hit == null:
			break
		var normal := hit.get_normal()
		if absf(normal.x) > 0.5:
			facing = 1 if normal.x > 0 else -1
			knockback_x = 0.0
			velocity.x = facing * rules.horizontal_speed * effects.speed_multiplier()
		elif normal.y < -0.5:
			if not floor_contact:
				take_damage(1)
			floor_contact = true
			if is_recovering():
				recovery = Recovery.RESTING
				rest_remaining = rules.damage_rest_seconds
				velocity = Vector2.ZERO
				position.y = rules.arena_size.y - rules.boundary_thickness - radius - 0.2
				break
			velocity.y = -rules.floor_bounce
		elif normal.y > 0.5:
			if not ceiling_contact:
				take_damage(1)
			ceiling_contact = true
			velocity.y = rules.ceiling_bounce
		motion = hit.get_remainder().bounce(normal) * rules.bounce_damping
		if not alive:
			break
	# Re-arm damage only after the body truly leaves the surface.
	var top := rules.boundary_thickness + rules.hud_height + radius
	var bottom := rules.arena_size.y - rules.boundary_thickness - radius
	if position.y < bottom - 3:
		floor_contact = false
	if position.y > top + 3:
		ceiling_contact = false
	contain()

func contain() -> void:
	var inset := rules.boundary_thickness + radius + 0.2
	position.x = clampf(position.x, inset, rules.arena_size.x - inset)
	position.y = clampf(position.y, inset + rules.hud_height, rules.arena_size.y - inset)

func take_damage(amount: int) -> bool:
	if not alive or not active or is_recovering() or protection > 0.0 or effects.has(PowerupCatalog.Kind.INVINCIBILITY):
		return false
	protection = rules.damage_protection
	if effects.consume_shield():
		powerup_collected.emit(self, PowerupCatalog.Kind.SHIELD)
		return false
	_apply_health_damage(amount)
	return true

func finish_grounded() -> void:
	# Deliberate body-contact finishing rule: bypass shield and protection only
	# while resting on the floor. Ordinary hits/lasers still use take_damage().
	if alive and active and recovery == Recovery.RESTING:
		_apply_health_damage(health)

func _apply_health_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	if health > 0:
		recovery = Recovery.DROPPING
		rest_remaining = 0.0
		pending_flap = false
		knockback_x = 0.0
		velocity = Vector2(0, maxf(velocity.y, 0.0))
	health_changed.emit(self)
	player_damaged.emit(self, amount)
	if health == 0:
		alive = false
		active = false
		recovery = Recovery.NONE
		rest_remaining = 0.0
		pending_flap = false
		collision_layer = 0
		collision_mask = 0
		effects.clear()
		velocity = Vector2(facing * 95, -170)
		player_eliminated.emit(self)

func heal() -> void:
	if alive:
		health = mini(rules.max_health, health + 1)
		health_changed.emit(self)

func collect_coin() -> void:
	if not alive or not active or is_recovering():
		return
	coins += 1
	if coins >= 3:
		coins -= 3
		heal()
	coin_collected.emit(self)

func collect_powerup(kind: int) -> void:
	if not alive or not active or is_recovering():
		return
	if kind == PowerupCatalog.Kind.RANDOM:
		kind = PowerupCatalog.BENEFICIAL.pick_random()
	if kind == PowerupCatalog.Kind.HEALTH:
		heal()
	else:
		effects.apply(kind)
	powerup_collected.emit(self, kind)

func presentation_step(delta: float) -> void:
	if not alive:
		death_time += delta
		velocity.y += rules.gravity * delta
		position += velocity * delta
		skin.rotation += delta * 9.0
		modulate.a = maxf(0.0, 1.0 - death_time / 0.8)
		return
	skin.facing = facing
	skin.body_scale = effects.size_multiplier()
	skin.shield = effects.has(PowerupCatalog.Kind.SHIELD)
	skin.invincible = effects.has(PowerupCatalog.Kind.INVINCIBILITY)
	skin.laser = effects.has(PowerupCatalog.Kind.LASER)
	skin.speed_effect = effects.has(PowerupCatalog.Kind.SPEED)
	skin.modulate.a = 0.35 if protection > 0 and int(protection * 14) % 2 == 0 else 1.0
	if is_recovering():
		skin.modulate.a = 0.55
	queue_redraw()

func _draw() -> void:
	if not alive:
		return
	var color := AnimalSkin.COLORS[profile.appearance % 8]
	var headroom := radius * (2.2 if profile.appearance == 3 else 1.6)
	if is_recovering():
		var message := "EXPOSED %ds" % ceili(rest_remaining) if recovery == Recovery.RESTING else "DOWN"
		draw_string(ThemeDB.fallback_font, Vector2(-40, -headroom - 42), message, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color("ffe29c"))
	draw_string(ThemeDB.fallback_font, Vector2(-6, -headroom - 21), profile.key_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	for i in range(rules.max_health):
		var x := (i - (rules.max_health - 1) / 2.0) * 8
		draw_circle(Vector2(x, -headroom - 10), 2.8, Color("ff708f") if i < health else Color("414962"))
