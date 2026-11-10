extends Control
## Animated title screen. The 3D showcase diorama behind it is built by Main;
## this layer carries the logo, the continue card and the side doors.

var _status_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Save.changed.connect(_refresh_status)


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)
	var column := Ui.column(0)
	margin.add_child(column)

	var brand := Ui.row(8)
	column.add_child(brand)
	var badge := Ui.panel(Color("#fff8e9"), 999, Color("#e3d6bd"), 10, 4)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_child(Ui.label("LITTLE JOY ARCADE", 10, Ui.MUTED))
	brand.add_child(badge)

	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -6)
	column.add_child(logo)
	logo.add_child(_outlined("Doodle", 52))
	logo.add_child(_outlined("Rescue", 52))
	var three := HBoxContainer.new()
	three.add_theme_constant_override("separation", 10)
	logo.add_child(three)
	three.add_child(_outlined("3D", 52))
	var tag := Ui.label("Sketch it. Build it. Save the puppy.", 15, Color("#33506a"))
	tag.add_theme_constant_override("outline_size", 6)
	tag.add_theme_color_override("font_outline_color", Color(1, 0.98, 0.9, 0.75))
	three.add_child(tag)
	three.alignment = BoxContainer.ALIGNMENT_END

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(flex)

	var card := Ui.panel(Color("#fffdf6"), 26, Color("#e8dcc4"), 18, 14)
	column.add_child(card)
	var card_column := Ui.column(10)
	card.add_child(card_column)

	var head := Ui.row(10)
	card_column.add_child(head)
	var level := Levels.get_level(Save.next_level())
	var heading := Ui.column(1)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	heading.add_child(Ui.caption("Next up"))
	heading.add_child(Ui.label("Level %d · %s" % [int(level.get("id", 1)), String(level.get("title", "A Roof for Biscuit"))],
		18, Ui.INK))
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 4)
	head.add_child(stars)
	stars.add_child(Ui.label("★", 20, Ui.GOLD))
	stars.add_child(Ui.label(str(Save.total_stars()), 17, Ui.INK))

	card_column.add_child(Ui.button("Continue", 19, 56, Ui.ORANGE, func() -> void:
		Audio.ui_click()
		Router.main.navigate("game", {"level": Levels.get_level(Save.next_level()), "mode": "campaign"})))

	var doors := Ui.row(8)
	card_column.add_child(doors)
	doors.add_child(_door("Journey", "🗺", func() -> void:
		Audio.ui_click()
		Router.main.navigate("worlds")))
	doors.add_child(_door("Pens", "✏", func() -> void:
		Audio.ui_click()
		Router.main.navigate("pens")))
	doors.add_child(_door("Trophies", "🏆", func() -> void:
		Audio.ui_click()
		Router.main.navigate("trophies")))
	doors.add_child(_door("Settings", "⚙", func() -> void:
		Audio.ui_click()
		Router.main.navigate("settings")))

	_status_label = Ui.label("", 11, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	card_column.add_child(_status_label)
	_refresh_status()
	card_column.add_child(Ui.label("A Little Joy Arcade original · made with Godot 4",
		10, Color("#b3a692"), HORIZONTAL_ALIGNMENT_CENTER))


func _outlined(text: String, size: int) -> Label:
	var node := Ui.label(text, size, Ui.CREAM)
	node.add_theme_constant_override("outline_size", 12)
	node.add_theme_color_override("font_outline_color", Color("#33506a"))
	return node


func _door(label: String, glyph: String, on_press: Callable) -> Button:
	var node := Button.new()
	node.text = "%s\n%s" % [glyph, label]
	node.custom_minimum_size.y = 58
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 12)
	node.add_theme_color_override("font_color", Ui.INK)
	node.add_theme_color_override("font_hover_color", Ui.INK)
	node.add_theme_color_override("font_pressed_color", Ui.INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#f4ecdc")
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	node.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#fbf5e8")
	node.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#e9dfcc")
	node.add_theme_stylebox_override("pressed", pressed)
	node.pressed.connect(on_press)
	return node


func _refresh_status() -> void:
	if _status_label == null:
		return
	_status_label.text = "%d levels · %d stars · %s" % [
		Levels.level_count(), Save.total_stars(), Arcade.status_text(),
	]


func debug_state() -> Dictionary:
	return {"screen": "title", "stars": Save.total_stars(), "levels": Levels.level_count()}
