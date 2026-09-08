class_name PlayerProfile
extends Resource
@export var id: int = 0
@export var key: int = KEY_Q
@export var appearance: int = 0

func action_name() -> StringName:
	return StringName("flap_%d" % id)

func key_label() -> String:
	return OS.get_keycode_string(key)
