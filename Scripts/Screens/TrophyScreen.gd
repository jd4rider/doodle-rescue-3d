extends Control
## Trophy shelf. Achievements are stored locally and mirrored to the arcade.

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
	title.add_child(Ui.label("Trophy Shelf", 25, Ui.INK))
	title.add_child(Ui.label("%d of %d earned" % [Save.achievement_count(), Save.ACHIEVEMENTS.size()],
		11, Ui.MUTED))
	header.add_child(Ui.pill("★ %d" % Save.total_stars(), 12, Ui.GOLD))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := Ui.column(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for entry in Save.ACHIEVEMENTS:
		var id := String(entry["id"])
		var earned := Save.has_achievement(id)
		var card := Ui.panel(Color("#fffdf6") if earned else Color("#f4ecdf"), 16,
			Color("#f0d99a") if earned else Color("#e8dcc4"), 13, 6)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := Ui.row(10)
		card.add_child(row)
		var star := Ui.label("★" if earned else "☆", 24, Ui.GOLD if earned else Color("#c8bcaa"),
			HORIZONTAL_ALIGNMENT_CENTER)
		star.custom_minimum_size.x = 34
		row.add_child(star)
		var info := Ui.column(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(Ui.label(String(entry["name"]), 14, Ui.INK if earned else Ui.MUTED))
		info.add_child(Ui.label(String(entry["hint"]), 10, Ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		row.add_child(Ui.label("Earned" if earned else "Locked", 10,
			Ui.GREEN_DARK if earned else Color("#a2957f")))
		list.add_child(card)
	list.add_child(Ui.spacer(20))


func debug_state() -> Dictionary:
	return {"screen": "trophies", "unlocked": Save.achievement_count()}
