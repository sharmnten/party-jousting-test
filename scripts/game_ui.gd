class_name GameUI
extends CanvasLayer
signal play_requested
signal start_requested
signal rematch_requested
signal lobby_requested
signal home_requested
signal resume_requested
signal mute_requested
signal remove_requested(id: int)
signal appearance_requested(id: int)
var root_control: Control
var page: Control
var modal: Control
var countdown_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var theme := Theme.new()
	theme.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := panel_style(Color("24324c") if state == "normal" else Color("34536a"))
		box.content_margin_left = 22
		box.content_margin_right = 22
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		theme.set_stylebox(state, "Button", box)
	root_control.theme = theme

func panel_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	box.border_color = Color("34415b")
	box.set_border_width_all(1)
	return box

func _clear_page() -> void:
	if is_instance_valid(page):
		root_control.remove_child(page)
		page.queue_free()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(page)

func label(text: String, size: int = 20, color: Color = Color("edf3ff")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	return item

func button(text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE # Gameplay Space/Enter cannot accidentally click a focused menu.
	item.pressed.connect(callback)
	return item

func backdrop() -> void:
	var background := ColorRect.new()
	background.color = Color("0d1528")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(background)
	for i in range(8):
		var skin := AnimalSkin.new()
		skin.appearance = i
		skin.position = Vector2(850 + (i % 3) * 105, 160 + (i / 3) * 160)
		skin.scale = Vector2.ONE * 1.8
		page.add_child(skin)

func show_home() -> void:
	_clear_page()
	backdrop()
	var column := VBoxContainer.new()
	column.position = Vector2(90, 100)
	column.size = Vector2(650, 540)
	column.add_theme_constant_override("separation", 22)
	page.add_child(column)
	column.add_child(label("2–8 PLAYERS   /   ONE KEY EACH", 17, Color("75ddc4")))
	column.add_child(label("PARTY\nJOUSTING", 78))
	column.add_child(label("Tiny wings. Terrible intentions.", 26, Color("b1bed5")))
	column.add_child(label("Tap to flap. Stomp from above. Grab a little chaos.\nWalls bounce. Floor and ceiling bite.", 20, Color("a5b3cc")))
	column.add_child(button("PLAY LOCAL    →", func(): play_requested.emit()))
	column.add_child(label("ENTER to join the lobby     •     ESC to pause in a round", 16, Color("8c9bb8")))

func show_lobby(profiles: Array[PlayerProfile]) -> void:
	_clear_page()
	var background := ColorRect.new()
	background.color = Color("0d1528")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(background)
	var column := VBoxContainer.new()
	column.position = Vector2(60, 35)
	column.size = Vector2(1160, 650)
	column.add_theme_constant_override("separation", 12)
	page.add_child(column)
	column.add_child(label("PICK YOUR FIGHT", 42))
	column.add_child(label("Press any unused letter to join. Tap your letter again to change your animal.", 19, Color("b1bed5")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)
	for i in range(8):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(279, 207)
		card.add_theme_stylebox_override("panel", panel_style(Color("18243b")))
		grid.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)
		if i < profiles.size():
			var profile := profiles[i]
			var header := label("P%d    [%s]" % [profile.id + 1, profile.key_label()], 24, AnimalSkin.COLORS[profile.appearance])
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(header)
			var preview := Control.new()
			preview.custom_minimum_size.y = 66
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(preview)
			var skin := AnimalSkin.new()
			skin.appearance = profile.appearance
			skin.position = Vector2(139, 39)
			skin.scale = Vector2.ONE * 1.25
			preview.add_child(skin)
			content.add_child(button(AnimalSkin.NAMES[profile.appearance] + "   ›", func(): appearance_requested.emit(profile.id)))
			var remove := button("Leave", func(): remove_requested.emit(profile.id))
			remove.add_theme_font_size_override("font_size", 13)
			content.add_child(remove)
		else:
			var empty := label("+\nPRESS A LETTER", 22, Color("62728f"))
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content.add_child(empty)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	var start := button("START ROUND  /  ENTER", func(): start_requested.emit())
	start.disabled = profiles.size() < 2
	row.add_child(start)
	row.add_child(button("Home", func(): home_requested.emit()))
	row.add_child(label("%d / 8 joined" % profiles.size(), 18, Color("75ddc4")))
	column.add_child(label("Use spaced-out keys. Some keyboards limit simultaneous presses; test your chosen keys together.", 15, Color("8c9bb8")))

func show_game(players: Array[JoustPlayer]) -> void:
	_clear_page()
	var tip := label("TAP YOUR KEY TO FLAP   •   3 COINS = +1 HEALTH   •   LASER: FLAP TO FIRE   •   ESC PAUSES", 14, Color("94a8c4"))
	tip.position = Vector2(200, 656)
	page.add_child(tip)
	countdown_label = label("3", 108, Color("fff0b8"))
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(countdown_label)

func set_countdown(text: String) -> void:
	if is_instance_valid(countdown_label):
		countdown_label.text = text
		countdown_label.modulate.a = 0.4
		create_tween().tween_property(countdown_label, "modulate:a", 1.0, 0.15)

func hide_modal() -> void:
	if is_instance_valid(modal):
		root_control.remove_child(modal)
		modal.queue_free()
		modal = null

func modal_column() -> VBoxContainer:
	hide_modal()
	modal = ColorRect.new()
	(modal as ColorRect).color = Color(0.025, 0.04, 0.08, 0.88)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(modal)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 450
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	return column

func show_pause(muted: bool) -> void:
	var column := modal_column()
	column.add_child(label("TAKE A BREATHER", 38))
	column.add_child(button("RESUME  /  ESC", func(): resume_requested.emit()))
	column.add_child(button("Sound: " + ("OFF" if muted else "ON"), func(): mute_requested.emit()))
	column.add_child(button("Return to lobby", func(): lobby_requested.emit()))

func show_victory(winner: PlayerProfile) -> void:
	var column := modal_column()
	column.add_child(label("ROUND OVER", 18, Color("75ddc4")))
	column.add_child(label("P%d WINS!" % [winner.id + 1] if winner != null else "IT'S A DRAW!", 64))
	if winner != null:
		column.add_child(label("%s  /  [%s]" % [AnimalSkin.NAMES[winner.appearance], winner.key_label()], 25, AnimalSkin.COLORS[winner.appearance]))
	column.add_child(button("REMATCH  /  ENTER", func(): rematch_requested.emit()))
	column.add_child(button("Return to lobby", func(): lobby_requested.emit()))
