extends Control
## Level grid for one world, with stars, locks and a one-tap start.

var world_index := 0
var _grid: GridContainer


func configure(payload: Dictionary) -> void:
	world_index = int(payload.get("world", 0))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var world: Dictionary = Levels.get_world(world_index)
	var levels: Array = Levels.levels_in_world(world_index)
	var accent := Color(String(world.get("accent", "#7ed07a")))
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
	title_box.add_child(Ui.label(String(world.get("name", "World")), 25, Ui.INK))
	title_box.add_child(Ui.label("%s · %d levels" % [Levels.mode_name(String(world.get("mode", "bee"))), levels.size()],
		12, Ui.MUTED))
	header.add_child(Ui.pill("★ %d/%d" % [Save.world_stars(world_index), levels.size() * 3], 12, accent))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	for level in levels:
		_grid.add_child(_tile(level, accent))
	_grid.add_child(Ui.spacer(8))


func _tile(level: Dictionary, accent: Color) -> Control:
	var id := int(level.get("id", 1))
	var unlocked := Save.is_unlocked(id)
	var stars := Save.stars_for(id)
	var card := Ui.panel(Color("#fffdf6") if unlocked else Color("#f1eade"), 20,
		Color("#e5d8c0"), 13, 8)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 132
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	var column := Ui.column(3)
	card.add_child(column)

	var top := Ui.row(4)
	column.add_child(top)
	top.add_child(Ui.caption("Level %d" % id))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	if not unlocked:
		top.add_child(Ui.label("🔒", 13, Ui.MUTED))
	var title := Ui.label(String(level.get("title", "")), 14, Ui.INK if unlocked else Ui.MUTED,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	title.custom_minimum_size.y = 38
	column.add_child(title)
	var stars_row := StarRow.new()
	stars_row.size_px = 18.0
	stars_row.gap = 4.0
	stars_row.set_stars(stars)
	stars_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(stars_row)
	var foot := Ui.row(4)
	column.add_child(foot)
	foot.add_child(Ui.label(Levels.mode_name(String(level.get("mode", "bee"))), 10, Ui.MUTED))
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(right)
	if unlocked:
		foot.add_child(Ui.label("Play →", 12, accent.darkened(0.35)))

	if unlocked:
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				Audio.ui_click()
				Router.main.navigate("game", {"level": level, "mode": "campaign"}))
	return card


func debug_state() -> Dictionary:
	return {"screen": "levels", "world": world_index}
