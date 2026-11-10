extends Control
## Pen tin: cosmetic pencils unlocked with stars. A pen changes the colour of
## the beams, never their physics.

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
	var title := Ui.column(0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	title.add_child(Ui.label("Pen Tin", 25, Ui.INK))
	title.add_child(Ui.label("Cosmetic only — every pen builds the same physics.", 11, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	header.add_child(Ui.pill("★ %d" % Save.total_stars(), 12, Ui.GOLD))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := Ui.column(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for pen in Save.PENS:
		list.add_child(_pen_card(pen))
	list.add_child(Ui.spacer(20))


func _pen_card(pen: Dictionary) -> Control:
	var id := String(pen["id"])
	var available := Save.pen_available(id)
	var selected := Save.selected_pen() == id
	var colour := Color(String(pen["colour"]))
	var card := Ui.panel(Color("#fffdf6") if available else Color("#f1eade"), 20,
		colour if selected else Color("#e8dcc4"), 14, 8)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := Ui.row(12)
	card.add_child(row)
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(54, 54)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	swatch.add_theme_stylebox_override("panel", style)
	row.add_child(swatch)
	var info := Ui.column(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(Ui.label(String(pen["name"]), 16, Ui.INK if available else Ui.MUTED))
	info.add_child(Ui.label(String(pen["tip"]), 11, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	if available:
		info.add_child(Ui.label("Selected" if selected else "Tap to use", 10,
			Ui.GREEN_DARK if selected else Color("#a8792a")))
	else:
		info.add_child(Ui.label("Unlocks at ★ %d" % int(pen["stars"]), 10, Color("#a8792a")))
	if available and not selected:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				Save.choose_pen(id)
				Audio.ui_click()
				Router.toast("%s selected." % String(pen["name"]))
				Router.go("pens"))
	return card


func debug_state() -> Dictionary:
	return {"screen": "pens", "pen": Save.selected_pen()}
