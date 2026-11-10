class_name BeamBuilder
extends RefCounted
## Turns a drawn polyline into real 3D geometry with real collision.
##
## Visuals are overlapping capsules (a rounded toy beam, alternating light and
## dark segments like a candy stripe). Collision is one oriented box per
## segment, which is cheap, stable and exactly matches the visible beam. A
## bridge deck can be an AnimatableBody3D so its sag moves the collision too.

const THICKNESS := 0.145
const DEPTH := 0.64
const COLLISION_LAYER := 8  # layer 4, drawn structures


static func build_stroke(parent: Node3D, points: PackedVector2Array, colour: Color,
		animated := false) -> Dictionary:
	var body: CollisionObject3D
	if animated:
		var animatable := AnimatableBody3D.new()
		animatable.sync_to_physics = true
		body = animatable
	else:
		body = StaticBody3D.new()
	body.name = "Stroke"
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	parent.add_child(body)

	var length := 0.0
	var material := Decor.mat(colour, 0.42, 0.08, 0.0)
	var light := Decor.mat(colour.lightened(0.16), 0.38, 0.08, 0.0)
	var dark := Decor.mat(colour.darkened(0.10), 0.5, 0.06, 0.0)
	var capsule := CapsuleMesh.new()
	capsule.radius = THICKNESS
	capsule.radial_segments = 12
	capsule.rings = 4
	var joint := SphereMesh.new()
	joint.radius = THICKNESS
	joint.height = THICKNESS * 2.0
	joint.radial_segments = 12
	joint.rings = 6

	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var delta := b - a
		var segment_length := delta.length()
		if segment_length < 0.001:
			continue
		length += segment_length
		var mid := (a + b) * 0.5
		var angle := atan2(delta.y, delta.x)
		# capsule's long axis is Y, so rotate it onto the segment
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "Beam"
		mesh_node.mesh = capsule.duplicate()
		(mesh_node.mesh as CapsuleMesh).height = segment_length + THICKNESS * 1.7
		mesh_node.position = Vector3(mid.x, mid.y, 0)
		mesh_node.rotation.z = angle - PI * 0.5
		# a chunky toy marker, deep enough that its silhouette matches the
		# collision box bees and walkers actually meet
		mesh_node.scale.z = 2.2
		mesh_node.material_override = (light if i % 2 == 0 else dark)
		body.add_child(mesh_node)
		if i == 0:
			mesh_node.set_meta("first", true)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(segment_length + THICKNESS * 1.2, THICKNESS * 2.0, DEPTH)
		shape.shape = box
		shape.position = Vector3(mid.x, mid.y, 0)
		shape.rotation.z = angle
		body.add_child(shape)

	for i in range(1, points.size() - 1):
		var knot := MeshInstance3D.new()
		knot.mesh = joint
		knot.position = Vector3(points[i].x, points[i].y, 0)
		knot.material_override = material
		knot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(knot)

	# soft end caps so a finished stroke reads as a rounded toy beam
	for index in [0, points.size() - 1]:
		var point := points[index]
		var cap := MeshInstance3D.new()
		cap.mesh = joint
		cap.position = Vector3(point.x, point.y, 0)
		cap.material_override = material
		body.add_child(cap)
		var cap_shape := CollisionShape3D.new()
		var cap_sphere := SphereShape3D.new()
		cap_sphere.radius = THICKNESS * 0.9
		cap_shape.shape = cap_sphere
		cap_shape.position = Vector3(point.x, point.y, 0)
		body.add_child(cap_shape)

	return {
		"node": body,
		"body": body,
		"length": length,
		"points": points.duplicate(),
		"animated": animated,
	}


static func build_preview(points: PackedVector2Array, colour: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if points.size() < 2:
		return mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ribbon := 0.17
	var z := 0.34
	var distance := 0.0
	for i in range(points.size()):
		var point := points[i]
		var direction: Vector2
		if i == 0:
			direction = points[1] - point
		elif i == points.size() - 1:
			direction = point - points[i - 1]
		else:
			direction = points[i + 1] - points[i - 1]
		if direction.length_squared() < 0.000001:
			direction = Vector2.RIGHT
		var normal := Vector2(-direction.y, direction.x).normalized()
		if i > 0:
			distance += point.distance_to(points[i - 1])
		vertices.append(Vector3(point.x + normal.x * ribbon, point.y + normal.y * ribbon, z))
		vertices.append(Vector3(point.x - normal.x * ribbon, point.y - normal.y * ribbon, z))
		normals.append(Vector3(0, 0, 1))
		normals.append(Vector3(0, 0, 1))
		uvs.append(Vector2(0, distance))
		uvs.append(Vector2(1, distance))
		if i < points.size() - 1:
			var base := i * 2
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func preview_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour.r, colour.g, colour.b, 0.72)
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
