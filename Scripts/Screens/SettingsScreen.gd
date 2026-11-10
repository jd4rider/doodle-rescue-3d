extends Control
## Settings: audio, motion, quality and the Little Joy account.

var _music_value: Label
var _sfx_value: Label
var _quality: OptionButton


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
	title.add_child(Ui.label("Settings", 25, Ui.INK))
	title.add_child(Ui.label("Make it yours.", 12, Ui.MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := Ui.column(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# audio
	var audio_card := Ui.panel(Color("#fffdf6"), 20, Color("#e8dcc4"), 16, 8)
	list.add_child(audio_card)
	var audio := Ui.column(10)
	audio_card.add_child(audio)
	audio.add_child(Ui.label("Sound", 18, Ui.INK))
	audio.add_child(_slider_row("Music", "music", 0.0, 1.0, func(value: float) -> void:
		Save.set_setting("music", value)))
	audio.add_child(_slider_row("Effects", "sfx", 0.0, 1.0, func(value: float) -> void:
		Save.set_setting("sfx", value)))

	# comfort
	var comfort := Ui.panel(Color("#fffdf6"), 20, Color("#e8dcc4"), 16, 8)
	list.add_child(comfort)
	var comfort_column := Ui.column(8)
	comfort.add_child(comfort_column)
	comfort_column.add_child(Ui.label("Comfort", 18, Ui.INK))
	comfort_column.add_child(_toggle_row("Reduced motion", "reduced_motion",
		"Stops idle bobbing and camera drift."))
	var quality_row := Ui.row(8)
	comfort_column.add_child(quality_row)
	var quality_text := Ui.column(1)
	quality_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(quality_text)
	quality_text.add_child(Ui.label("Graphics quality", 14, Ui.INK))
	quality_text.add_child(Ui.label("Lower it for older phones.", 10, Ui.MUTED))
	_quality = OptionButton.new()
	_quality.focus_mode = Control.FOCUS_NONE
	_quality.add_theme_font_size_override("font_size", 12)
	for entry in ["low", "medium", "high"]:
		_quality.add_item(entry.capitalize())
	_quality.selected = maxi(0, ["low", "medium", "high"].find(String(Save.get_setting("quality", "high"))))
	_quality.item_selected.connect(func(index: int) -> void:
		Save.set_setting("quality", ["low", "medium", "high"][index])
		if Router.main.has_method("apply_quality"):
			Router.main.apply_quality(["low", "medium", "high"][index]))
	quality_row.add_child(_quality)

	# account
	var account := Ui.panel(Color("#fffdf6"), 20, Color("#e8dcc4"), 16, 8)
	list.add_child(account)
	var account_column := Ui.column(6)
	account.add_child(account_column)
	account_column.add_child(Ui.label("Little Joy Arcade", 18, Ui.INK))
	var status := Ui.label(Arcade.status_text(), 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	account_column.add_child(status)
	var account_row := Ui.row(8)
	account_column.add_child(account_row)
	account_row.add_child(Ui.ghost("Sign in / sync", func() -> void:
		Arcade.sign_in()
		Arcade.refresh_identity()
		status.text = Arcade.status_text(), 44, 12))
	account_row.add_child(Ui.ghost("Arcade site", func() -> void: Arcade.open_arcade(), 44, 12))
	account_column.add_child(Ui.label(
		"Progress saves on this device with or without an account. Signing in adds cloud saves across devices.",
		10, Color("#a2957f"), HORIZONTAL_ALIGNMENT_LEFT, true))

	# reset
	var danger := Ui.panel(Color("#fff6ef"), 20, Color("#f0d8c8"), 16, 8)
	list.add_child(danger)
	var danger_column := Ui.column(8)
	danger.add_child(danger_column)
	danger_column.add_child(Ui.label("Start over", 18, Ui.INK))
	danger_column.add_child(Ui.label("Clears stars, trophies and settings on this device.", 11, Ui.MUTED))
	var dialog := ConfirmationDialog.new()
	dialog.title = "Clear all progress?"
	dialog.dialog_text = "Stars, trophies and your place in the journey will be reset. This cannot be undone."
	dialog.ok_button_text = "Clear everything"
	dialog.cancel_button_text = "Keep my progress"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		Save.reset_progress()
		Audio.ui_back()
		Router.toast("Progress cleared. A fresh sketchbook.")
		Router.go("title"))
	danger_column.add_child(Ui.ghost("Reset progress", func() -> void: dialog.popup_centered(), 44, 13, Ui.RED))

	list.add_child(Ui.label("Doodle Rescue 3D · 0.1.0 · Godot 4.7 · Compatibility renderer",
		10, Color("#a2957f"), HORIZONTAL_ALIGNMENT_CENTER, true))
	list.add_child(Ui.spacer(20))


func _slider_row(label: String, key: String, minimum: float, maximum: float, on_change: Callable) -> Control:
	var row := Ui.row(10)
	var text := Ui.label(label, 14, Ui.INK)
	text.custom_minimum_size.x = 74
	row.add_child(text)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = float(Save.get_setting(key, 0.5))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 28
	var value_label := Ui.label("%d%%" % int(slider.value * 100.0), 12, Ui.MUTED)
	value_label.custom_minimum_size.x = 42
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value * 100.0)
		on_change.call(value))
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _toggle_row(label: String, key: String, help: String) -> Control:
	var row := Ui.row(10)
	var text := Ui.column(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Ui.label(label, 14, Ui.INK))
	text.add_child(Ui.label(help, 10, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.button_pressed = bool(Save.get_setting(key, false))
	toggle.toggled.connect(func(value: bool) -> void:
		Save.set_setting(key, value)
		Audio.ui_click())
	row.add_child(toggle)
	return row


func debug_state() -> Dictionary:
	return {"screen": "settings"}
