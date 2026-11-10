extends Control
## Journey map: four worlds, each with its own colour, mode and progress.

var _stars_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var margin := Ui.safe_margin(18)
	add_child(margin)
	var column := Ui.column(12)
	margin.add_child(column)

	var header := Ui.row(10)
	column.add_child(header)
	header.add_child(Ui.icon_button("<", func() -> void:
		Audio.ui_back()
		Router.main.go_back(), 44))
	var title_box := Ui.column(0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(Ui.label("Biscuit's Journey", 26, Ui.INK))
	title_box.add_child(Ui.label("Four little worlds to draw back together.", 13, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	_stars_label = Ui.label("★ %d" % Save.total_stars(), 18, Color("#c98c14"))
	header.add_child(_stars_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := Ui.column(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for index in range(Levels.worlds.size()):
		list.add_child(_world_card(index))
	list.add_child(Ui.spacer(12))


func _world_card(index: int) -> Control:
	var world: Dictionary = Levels.get_world(index)
	var levels: Array = Levels.levels_in_world(index)
	var cleared := Save.world_cleared(index)
	var stars := Save.world_stars(index)
	var unlocked := Save.world_unlocked(index)
	var accent := Color(String(world.get("accent", "#7ed07a")))

	var card := Ui.panel(Color("#fffdf6") if unlocked else Color("#f1eade"), 24,
		Color("#e5d8c0"), 16, 10)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	var column := Ui.column(7)
	card.add_child(column)

	var top := Ui.row(8)
	column.add_child(top)
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(48, 48)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var swatch_style := StyleBoxFlat.new()
	swatch_style.bg_color = accent
	swatch_style.corner_radius_top_left = 14
	swatch_style.corner_radius_top_right = 14
	swatch_style.corner_radius_bottom_left = 14
	swatch_style.corner_radius_bottom_right = 14
	swatch.add_theme_stylebox_override("panel", swatch_style)
	top.add_child(swatch)
	var swatch_label := Ui.label(String(world.get("name", "World")).substr(0, 1), 22, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER)
	swatch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swatch.add_child(swatch_label)
	var info := Ui.column(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(Ui.label(String(world.get("name", "World")), 20, Ui.INK if unlocked else Ui.MUTED))
	info.add_child(Ui.label(String(world.get("blurb", "")), 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var mode_pill := Ui.pill(Levels.mode_name(String(world.get("mode", "bee"))), 10, accent)
	mode_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(mode_pill)

	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 8
	progress.max_value = maxf(1.0, float(levels.size()))
	progress.value = cleared
	progress.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#ece2d2")
	background.corner_radius_top_left = 99
	background.corner_radius_top_right = 99
	background.corner_radius_bottom_left = 99
	background.corner_radius_bottom_right = 99
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 99
	fill.corner_radius_top_right = 99
	fill.corner_radius_bottom_left = 99
	fill.corner_radius_bottom_right = 99
	progress.add_theme_stylebox_override("background", background)
	progress.add_theme_stylebox_override("fill", fill)
	column.add_child(progress)

	var foot := Ui.row(6)
	column.add_child(foot)
	foot.add_child(Ui.label("%d/%d cleared" % [cleared, levels.size()], 11, Ui.MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(Ui.label("★ %d/%d" % [stars, levels.size() * 3], 11, Color("#c98c14")))
	if not unlocked:
		var lock := Ui.pill("Locked · clear the world before", 10, Color("#c9bcaa"))
		column.add_child(lock)
	else:
		var open := Ui.ghost("Open world  →", func() -> void:
			Audio.ui_click()
			Router.main.navigate("levels", {"world": index}), 40, 13, accent.darkened(0.35))
		column.add_child(open)

	if unlocked:
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				Audio.ui_click()
				Router.main.navigate("levels", {"world": index}))
	return card


func debug_state() -> Dictionary:
	return {"screen": "worlds", "worlds": Levels.worlds.size()}
