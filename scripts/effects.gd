class_name PlayerEffects
extends Node
signal changed
var rules: GameRules = GameRules.new()
# Enum-indexed arrays avoid unchecked dictionary keys and independent timer nodes.
var remaining: Array[float] = []

func _init() -> void:
	remaining.resize(PowerupCatalog.Kind.size())
	remaining.fill(0.0)

func has(kind: int) -> bool:
	return kind >= 0 and kind < remaining.size() and remaining[kind] > 0.0

func apply(kind: int) -> void:
	if kind < 0 or kind >= remaining.size():
		return
	if kind == PowerupCatalog.Kind.TINY:
		remaining[PowerupCatalog.Kind.GIANT] = 0.0
	elif kind == PowerupCatalog.Kind.GIANT:
		remaining[PowerupCatalog.Kind.TINY] = 0.0
	var duration := rules.effect_duration
	if kind == PowerupCatalog.Kind.SHIELD:
		duration = INF
	elif kind == PowerupCatalog.Kind.LASER:
		duration = rules.laser_duration
	elif kind == PowerupCatalog.Kind.INVINCIBILITY:
		duration = rules.invincibility_duration
	remaining[kind] = duration
	changed.emit()

func tick(delta: float) -> void:
	var expired := false
	for i in range(remaining.size()):
		if remaining[i] > 0.0 and is_finite(remaining[i]):
			remaining[i] = maxf(0.0, remaining[i] - delta)
			if remaining[i] == 0.0:
				expired = true
	if expired:
		changed.emit()

func consume_shield() -> bool:
	if not has(PowerupCatalog.Kind.SHIELD):
		return false
	remaining[PowerupCatalog.Kind.SHIELD] = 0.0
	changed.emit()
	return true

func clear() -> void:
	remaining.fill(0.0)
	changed.emit()

func speed_multiplier() -> float:
	return 1.65 if has(PowerupCatalog.Kind.SPEED) else 1.0

func flap_multiplier() -> float:
	return 1.3 if has(PowerupCatalog.Kind.SUPER_FLAP) else 1.0

func gravity_multiplier() -> float:
	return 1.45 if has(PowerupCatalog.Kind.HEAVY) else 1.0

func size_multiplier() -> float:
	if has(PowerupCatalog.Kind.TINY):
		return 0.65
	return 1.5 if has(PowerupCatalog.Kind.GIANT) else 1.0

func stomp_damage() -> int:
	return 2 if has(PowerupCatalog.Kind.HEAVY) or has(PowerupCatalog.Kind.GIANT) else 1
