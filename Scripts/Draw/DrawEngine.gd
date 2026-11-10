class_name DrawEngine
extends Node
## Screen-to-world drawing on a stable world plane.
##
## Pointer or finger -> camera ray -> intersection with z = 0 -> clamped world
## point. Points are distance-filtered while drawing, simplified when the stroke
## ends, and turned into a real 3D beam by BeamBuilder. The preview is a glowing
## ribbon plus a sparkle cursor; it never pretends to be the physical object.

signal stroke_started
signal stroke_changed(length: float)
signal stroke_finished(points: PackedVector2Array, length: float)
signal stroke_cancelled
signal budget_exhausted

const MIN_POINT_DISTANCE := 0.085
const MIN_STROKE := 0.22
const MAX_POINTS := 90
const SNAP_LIMIT := 0.75

var camera: Camera3D
var plane_z := 0.0
var bounds := Rect2(-7.5, 0.0, 15.0, 8.0)
var budget := 12.0
var spent := 0.0
var enabled := true
var colour := Color("#ffb545")
var snap_targets: PackedVector2Array = PackedVector2Array()

var _drawing := false
var _points: PackedVector2Array = PackedVector2Array()
var _length := 0.0
var _root: Node3D
var _preview: MeshInstance3D
var _cursor: MeshInstance3D
var _sparkles: CPUParticles3D
var _preview_material: StandardMaterial3D
var _cursor_material: StandardMaterial3D


func setup(parent: Node3D, cam: Camera3D, area: Rect2, pen_budget: float, pen_colour: Color) -> void:
	camera = cam
	bounds = area
	budget = pen_budget
	colour = pen_colour
	_root = Node3D.new()
	_root.name = "Drawing"
	parent.add_child(_root)

	_preview = MeshInstance3D.new()
	_preview.name = "Preview"
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_material = BeamBuilder.preview_material(colour)
	_preview.material_override = _preview_material
	_root.add_child(_preview)

	_cursor = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.13
	orb.height = 0.26
	orb.radial_segments = 16
	orb.rings = 8
	_cursor.mesh = orb
	_cursor_material = BeamBuilder.preview_material(colour)
	_cursor_material.albedo_color = Color(1, 1, 1, 0.95)
	_cursor_material.emission = colour
	_cursor_material.emission_energy_multiplier = 1.6
	_cursor.material_override = _cursor_material
	_cursor.visible = false
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_cursor)

	_sparkles = CPUParticles3D.new()
	_sparkles.amount = 26
	_sparkles.lifetime = 0.55
	_sparkles.emitting = false
	_sparkles.one_shot = false
	_sparkles.local_coords = false
	_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparkles.emission_sphere_radius = 0.18
	_sparkles.gravity = Vector3.ZERO
	_sparkles.initial_velocity_min = 0.35
	_sparkles.initial_velocity_max = 1.0
	_sparkles.scale_amount_min = 0.4
	_sparkles.scale_amount_max = 1.0
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var particle := CPUParticles3D.new()
	particle.mesh = _make_spark_mesh()
	particle.material_override = spark_material
	_sparkles.add_child(particle)
	_root.add_child(_sparkles)


func _exit_tree() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
		_root = null


func _make_spark_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	return mesh


func set_colour(value: Color) -> void:
	colour = value
	if _preview_material != null:
		_preview_material.emission = value
		_preview_material.albedo_color = Color(value.r, value.g, value.b, 0.72)
	if _cursor_material != null:
		_cursor_material.emission = value


func set_spent(value: float) -> void:
	spent = value


## Doorway rims are magnetic: release a stroke near a rim point and its ends
## snap onto the wood. This is the difference between a doodle that holds and
## one that merely floats in the opening.
func set_snap_targets(points: PackedVector2Array) -> void:
	snap_targets = points


func remaining() -> float:
	return maxf(0.0, budget - spent)


func is_drawing() -> bool:
	return _drawing


func can_draw() -> bool:
	return enabled and remaining() > 0.25


func handle_event(event: InputEvent) -> bool:
	if not enabled or camera == null:
		return false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mouse.pressed:
			return _begin(mouse.position)
		return _end()
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _drawing and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			return _add(motion.position)
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			return _begin(touch.position)
		return _end()
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _drawing:
			return _add(drag.position)
	return false


func _world_at(screen: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.z) < 0.00001:
		return null
	var t := (plane_z - origin.z) / direction.z
	if t <= 0.0:
		return null
	var point := origin + direction * t
	if point.x < bounds.position.x or point.x > bounds.end.x:
		return null
	if point.y < bounds.position.y or point.y > bounds.end.y:
		return null
	return Vector2(point.x, point.y)


func _begin(screen: Vector2) -> bool:
	if not can_draw():
		if enabled:
			budget_exhausted.emit()
		return true
	var hit: Variant = _world_at(screen)
	if hit == null:
		return true
	_drawing = true
	_points = PackedVector2Array([hit as Vector2])
	_length = 0.0
	_cursor.visible = true
	_cursor.position = Vector3((hit as Vector2).x, (hit as Vector2).y, 0.42)
	_sparkles.emitting = true
	_sparkles.global_position = Vector3((hit as Vector2).x, (hit as Vector2).y, 0.45)
	stroke_started.emit()
	if has_node("/root/Audio"):
		get_node("/root/Audio").draw_start()
	return true


func _add(screen: Vector2) -> bool:
	if not _drawing:
		return false
	var hit: Variant = _world_at(screen)
	if hit == null:
		return true
	var point := hit as Vector2
	var last := _points[_points.size() - 1]
	var delta := point.distance_to(last)
	if delta < MIN_POINT_DISTANCE:
		return true
	var room := remaining() - _length
	if room <= 0.02:
		_finish_stroke()
		budget_exhausted.emit()
		return true
	if delta > room:
		point = last + (point - last).normalized() * room
		delta = room
	_points.append(point)
	_length += delta
	_cursor.position = Vector3(point.x, point.y, 0.42)
	_sparkles.global_position = Vector3(point.x, point.y, 0.45)
	_rebuild_preview()
	stroke_changed.emit(_length)
	if _points.size() >= MAX_POINTS or remaining() - _length <= 0.02:
		_finish_stroke()
		if remaining() <= 0.02:
			budget_exhausted.emit()
	return true


func _end() -> bool:
	if not _drawing:
		return false
	_finish_stroke()
	return true


func _finish_stroke() -> void:
	_drawing = false
	_cursor.visible = false
	_sparkles.emitting = false
	_preview.mesh = null
	var simplified := _simplify(_points)
	if simplified.size() >= 2 and _length >= MIN_STROKE:
		simplified = _snap_ends(simplified)
		stroke_finished.emit(simplified, _length)
	else:
		stroke_cancelled.emit()
	_points = PackedVector2Array()
	_length = 0.0


func _snap_ends(points: PackedVector2Array) -> PackedVector2Array:
	if snap_targets.is_empty() or points.size() < 2:
		return points
	var first := _nearest_target(points[0])
	var last := _nearest_target(points[points.size() - 1])
	if first.x > -900.0:
		points[0] = first
	if last.x > -900.0:
		points[points.size() - 1] = last
	return points


func _nearest_target(point: Vector2) -> Vector2:
	var best := Vector2(-9999, -9999)
	var best_distance := SNAP_LIMIT
	for target in snap_targets:
		var distance := point.distance_to(target)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


func cancel() -> void:
	_drawing = false
	_points = PackedVector2Array()
	_length = 0.0
	_preview.mesh = null
	_cursor.visible = false
	_sparkles.emitting = false


func _rebuild_preview() -> void:
	if _points.size() < 2:
		return
	_preview.mesh = BeamBuilder.build_preview(_smooth(_points), colour)


## Chaikin smoothing keeps the preview silky without changing the committed
## stroke, which is simplified instead so the collision stays stable.
func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var out := PackedVector2Array()
	out.append(points[0])
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	out.append(points[points.size() - 1])
	return out


## Ramer–Douglas–Peucker. Drops pointer jitter before it becomes physics shapes.
func _simplify(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var keep := PackedByteArray()
	keep.resize(points.size())
	keep.fill(0)
	keep[0] = 1
	keep[points.size() - 1] = 1
	_rdp(points, 0, points.size() - 1, 0.035, keep)
	var out := PackedVector2Array()
	for i in range(points.size()):
		if keep[i] == 1:
			out.append(points[i])
	return out


func _rdp(points: PackedVector2Array, first: int, last: int, epsilon: float, keep: PackedByteArray) -> void:
	if last <= first + 1:
		return
	var a := points[first]
	var b := points[last]
	var ab := b - a
	var ab_len := ab.length()
	var best := -1.0
	var index := -1
	for i in range(first + 1, last):
		var p := points[i]
		var d := 0.0
		if ab_len < 0.0001:
			d = p.distance_to(a)
		else:
			d = absf((p - a).cross(ab)) / ab_len
		if d > best:
			best = d
			index = i
	if best > epsilon and index >= 0:
		keep[index] = 1
		_rdp(points, first, index, epsilon, keep)
		_rdp(points, index, last, epsilon, keep)
