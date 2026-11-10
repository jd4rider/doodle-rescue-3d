class_name StarRow
extends Control
## Draws the three campaign stars without a font glyph, so they render the same
## everywhere and can animate in one at a time.

var filled := 0
var size_px := 30.0
var gap := 10.0
var dim := Color("#dbcdb4")
var lit := Color("#f5c542")
var edge := Color("#d99a24")
var _progress := [0.0, 0.0, 0.0]


func _ready() -> void:
	custom_minimum_size = Vector2(size_px * 3.0 + gap * 2.0, size_px + 6.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_stars(value: int) -> void:
	filled = clampi(value, 0, 3)
	_progress = [1.0 if filled >= 1 else 0.0, 1.0 if filled >= 2 else 0.0, 1.0 if filled >= 3 else 0.0]
	queue_redraw()


func animate_in() -> void:
	_progress = [0.0, 0.0, 0.0]
	queue_redraw()
	for i in range(3):
		var target := 1.0 if filled > i else 0.0
		var tween := create_tween()
		tween.tween_interval(0.22 + i * 0.20)
		tween.tween_method(func(value: float) -> void:
			_progress[i] = value
			queue_redraw(), 0.0, target, 0.28)


func _draw() -> void:
	var total := size_px * 3.0 + gap * 2.0
	var start := Vector2((size.x - total) * 0.5 + size_px * 0.5, size.y * 0.5 + 2.0)
	for i in range(3):
		var centre := start + Vector2(i * (size_px + gap), 0)
		var radius := size_px * 0.5
		var points := _star_points(centre, radius, radius * 0.46)
		draw_colored_polygon(points, dim)
		var amount: float = _progress[i]
		if amount > 0.01:
			var grown := _star_points(centre, radius * (0.7 + 0.4 * amount), radius * 0.46 * (0.7 + 0.4 * amount))
			draw_colored_polygon(grown, lit)
			draw_polyline(_closed(grown), edge, maxf(1.0, size_px * 0.04), true)


func _star_points(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var radius := outer if i % 2 == 0 else inner
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
