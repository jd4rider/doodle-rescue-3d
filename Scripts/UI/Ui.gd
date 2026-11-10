class_name Ui
extends RefCounted
## Shared look and feel for every screen: warm cream cards, rounded corners,
## chunky tappable buttons and a small set of hand-drawn accents.

const INK := Color("#2f2a24")
const CREAM := Color("#fff8e9")
const CARD := Color("#fffdf6")
const BORDER := Color("#e3d6bd")
const MUTED := Color("#7d7163")
const ORANGE := Color("#ff9f43")
const ORANGE_DARK := Color("#db7415")
const GREEN := Color("#4fb069")
const GREEN_DARK := Color("#2f7d47")
const BLUE := Color("#3f8fd0")
const RED := Color("#e05d55")
const GOLD := Color("#f5c542")
const NAVY := Color("#263b52")
const WHITE := Color("#ffffff")


static func label(text: String, size: int, colour: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT,
		wrap := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", colour)
	node.horizontal_alignment = align
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func title(text: String, size := 30, colour: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := label(text, size, colour, align, true)
	node.add_theme_constant_override("outline_size", 0)
	return node


static func caption(text: String) -> Label:
	var node := label(text.to_upper(), 11, MUTED)
	node.add_theme_constant_override("outline_size", 0)
	return node


static func row(separation := 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func column(separation := 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func spacer(height := 8) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func panel(colour: Color = CARD, radius := 24, border: Color = BORDER, margin := 16,
		shadow := 10) -> PanelContainer:
	var node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	if shadow > 0:
		style.shadow_color = Color(0.16, 0.11, 0.07, 0.22)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0, 5)
	node.add_theme_stylebox_override("panel", style)
	return node


static func button(text: String, size: int, height: int, colour: Color, on_press: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", size)
	var ink := INK if _luminance(colour) > 0.55 else WHITE
	node.add_theme_color_override("font_color", ink)
	node.add_theme_color_override("font_hover_color", ink)
	node.add_theme_color_override("font_pressed_color", ink)
	node.add_theme_color_override("font_focus_color", ink)
	node.add_theme_stylebox_override("normal", _box(colour, 18, 0))
	node.add_theme_stylebox_override("hover", _box(colour.lightened(0.10), 18, 0))
	node.add_theme_stylebox_override("pressed", _box(colour.darkened(0.12), 18, 0))
	node.add_theme_stylebox_override("disabled", _box(colour.darkened(0.08).lerp(Color("#d8cfc1"), 0.55), 18, 0))
	node.add_theme_stylebox_override("focus", _box(colour, 18, 0))
	node.pressed.connect(on_press)
	_wire_feel(node)
	return node


static func ghost(text: String, on_press: Callable, height := 48, size := 15,
		colour: Color = Color("#7d7163")) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", colour)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_focus_color", colour)
	node.add_theme_stylebox_override("normal", _box(Color("#f4ecdc"), 16, 0))
	node.add_theme_stylebox_override("hover", _box(Color("#f9f3e6"), 16, 0))
	node.add_theme_stylebox_override("pressed", _box(Color("#e8ddc9"), 16, 0))
	node.add_theme_stylebox_override("focus", _box(Color("#f4ecdc"), 16, 0))
	node.pressed.connect(on_press)
	_wire_feel(node)
	return node


static func icon_button(glyph: String, on_press: Callable, size := 46) -> Button:
	var node := Button.new()
	node.text = glyph
	node.custom_minimum_size = Vector2(size, size)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", int(size * 0.42))
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_stylebox_override("normal", _box(Color("#fff8e9"), 999, 2))
	node.add_theme_stylebox_override("hover", _box(Color("#ffffff"), 999, 2))
	node.add_theme_stylebox_override("pressed", _box(Color("#efe4d2"), 999, 2))
	node.add_theme_stylebox_override("focus", _box(Color("#fff8e9"), 999, 2))
	node.pressed.connect(on_press)
	_wire_feel(node)
	return node


static func _box(colour: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = Color("#eadfcb")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func _wire_feel(node: Button) -> void:
	node.mouse_entered.connect(func() -> void:
		if not node.disabled:
			node.create_tween().tween_property(node, "scale", Vector2(1.025, 1.025), 0.10))
	node.mouse_exited.connect(func() -> void:
		if not node.disabled:
			node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.10))
	node.button_down.connect(func() -> void:
		node.pivot_offset = node.size * 0.5
		node.create_tween().tween_property(node, "scale", Vector2(0.97, 0.97), 0.06))
	node.button_up.connect(func() -> void:
		node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.10))


static func _luminance(colour: Color) -> float:
	return colour.r * 0.299 + colour.g * 0.587 + colour.b * 0.114


static func pill(text: String, size := 12, colour: Color = GREEN) -> PanelContainer:
	var node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	node.add_theme_stylebox_override("panel", style)
	var ink := INK if _luminance(colour) > 0.55 else WHITE
	node.add_child(label(text, size, ink, HORIZONTAL_ALIGNMENT_CENTER))
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func format_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func fit(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func safe_margin(inset := 18) -> MarginContainer:
	var node := MarginContainer.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_theme_constant_override("margin_left", inset)
	node.add_theme_constant_override("margin_right", inset)
	node.add_theme_constant_override("margin_top", inset + 12)
	node.add_theme_constant_override("margin_bottom", inset + 12)
	return node
