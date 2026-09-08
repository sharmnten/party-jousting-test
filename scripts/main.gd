extends Node
enum Screen { HOME, LOBBY, MATCH, VICTORY }
const ARENA := preload("res://scenes/Arena.tscn")
const JOIN_KEYS: Array[int] = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M]
@export var rules: GameRules = preload("res://resources/default_rules.tres")
@onready var ui: GameUI = $UI
var profiles: Array[PlayerProfile] = []
var arena: JoustArena
var screen: Screen = Screen.HOME
var muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui.play_requested.connect(show_lobby)
	ui.start_requested.connect(start_round)
	ui.rematch_requested.connect(start_round)
	ui.lobby_requested.connect(show_lobby)
	ui.home_requested.connect(show_home)
	ui.resume_requested.connect(toggle_pause)
	ui.mute_requested.connect(toggle_mute)
	ui.remove_requested.connect(remove_player)
	ui.appearance_requested.connect(cycle_appearance)
	show_home()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ESCAPE:
		if screen == Screen.MATCH:
			toggle_pause()
		elif screen == Screen.LOBBY:
			show_home()
		return
	if get_tree().paused:
		return
	if key == KEY_ENTER:
		match screen:
			Screen.HOME: show_lobby()
			Screen.LOBBY, Screen.VICTORY: start_round()
		return
	if screen == Screen.LOBBY and JOIN_KEYS.has(key):
		join_or_cycle(key)

func join_or_cycle(key: int) -> void:
	if not JOIN_KEYS.has(key):
		return
	for profile in profiles:
		if profile.key == key:
			cycle_appearance(profile.id)
			return
	if profiles.size() >= 8:
		return
	var profile := PlayerProfile.new()
	var used_ids: Array[int] = []
	for existing in profiles:
		used_ids.append(existing.id)
	for id in range(8):
		if not used_ids.has(id):
			profile.id = id
			break
	profile.key = key
	profile.appearance = profile.id
	profiles.append(profile)
	ui.show_lobby(profiles)

func cycle_appearance(id: int) -> void:
	for profile in profiles:
		if profile.id == id:
			profile.appearance = (profile.appearance + 1) % AnimalSkin.NAMES.size()
	ui.show_lobby(profiles)

func remove_player(id: int) -> void:
	for i in range(profiles.size() - 1, -1, -1):
		if profiles[i].id == id:
			profiles.remove_at(i)
	ui.show_lobby(profiles)

func clear_arena() -> void:
	get_tree().paused = false
	ui.hide_modal()
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
		arena = null

func show_home() -> void:
	clear_arena()
	screen = Screen.HOME
	ui.show_home()

func show_lobby() -> void:
	clear_arena()
	screen = Screen.LOBBY
	ui.show_lobby(profiles)

func bind_controls() -> void:
	for id in range(8):
		var action := StringName("flap_%d" % id)
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	for profile in profiles:
		InputMap.add_action(profile.action_name())
		var event := InputEventKey.new()
		event.physical_keycode = profile.key
		InputMap.action_add_event(profile.action_name(), event)

func start_round() -> void:
	if profiles.size() < 2:
		return
	clear_arena()
	bind_controls()
	screen = Screen.MATCH
	arena = ARENA.instantiate() as JoustArena
	arena.rules = rules
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	arena.feedback.muted = muted
	arena.round_finished.connect(_finished)
	arena.countdown_changed.connect(ui.set_countdown)
	arena.setup(profiles)
	ui.show_game(arena.players)

func _finished(winner: PlayerProfile) -> void:
	screen = Screen.VICTORY
	ui.set_countdown("")
	ui.show_victory(winner)

func toggle_pause() -> void:
	if screen != Screen.MATCH:
		return
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		for player in arena.players:
			player.pending_flap = false
		ui.show_pause(muted)
	else:
		ui.hide_modal()

func toggle_mute() -> void:
	muted = not muted
	if is_instance_valid(arena):
		arena.feedback.muted = muted
	ui.show_pause(muted)
