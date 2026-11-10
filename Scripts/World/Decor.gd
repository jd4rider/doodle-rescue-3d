class_name Decor
extends RefCounted
## Procedural toy-diorama props. Everything is built from rounded primitives and
## shared materials, so there are no external textures to download and the
## whole world stays tiny in the web build.

const PALETTES := {
	"meadow": {
		"grass": "#7ed07a", "grass_light": "#a3e59a", "dirt": "#b98052",
		"rock": "#9a9188", "leaf": "#4fae63", "leaf_light": "#76cf7c",
		"accent": "#ffcf5c", "sky": "#bfe9ff",
	},
	"river": {
		"grass": "#6fc48b", "grass_light": "#94dda2", "dirt": "#8f6a49",
		"rock": "#7f98a6", "leaf": "#3f9a70", "leaf_light": "#63bd8a",
		"accent": "#7fd8ff", "sky": "#c8efff",
	},
	"canyon": {
		"grass": "#d9b263", "grass_light": "#eccd85", "dirt": "#b07648",
		"rock": "#c08858", "leaf": "#8a9a4d", "leaf_light": "#b4bb63",
		"accent": "#ff8a5c", "sky": "#ffe3bd",
	},
	"toybox": {
		"grass": "#8fd8c8", "grass_light": "#b6e9dc", "dirt": "#c78a63",
		"rock": "#9c8fc2", "leaf": "#5ab8a2", "leaf_light": "#85d8bf",
		"accent": "#ff7fb6", "sky": "#dcd4ff",
	},
}

static var _materials: Dictionary = {}


static func palette(theme: String) -> Dictionary:
	return PALETTES.get(theme, PALETTES["meadow"])


static func mat(colour: Color, roughness := 0.7, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [colour.to_html(), roughness, metallic, emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


static func add_mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material,
		scale := Vector3.ONE, rotation := Vector3.ZERO, name := "Mesh") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = position
	node.scale = scale
	node.rotation = rotation
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func sphere(parent: Node3D, position: Vector3, radius: float, colour: Color,
		scale := Vector3.ONE, roughness := 0.7, name := "Sphere") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return add_mesh(parent, mesh, position, mat(colour, roughness), scale, Vector3.ZERO, name)


static func box(parent: Node3D, position: Vector3, size: Vector3, colour: Color,
		rotation := Vector3.ZERO, roughness := 0.7, name := "Box") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return add_mesh(parent, mesh, position, mat(colour, roughness), Vector3.ONE, rotation, name)


static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, colour: Color,
		scale := Vector3.ONE, roughness := 0.7, name := "Cylinder") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 28
	return add_mesh(parent, mesh, position, mat(colour, roughness), scale, Vector3.ZERO, name)


static func capsule(parent: Node3D, position: Vector3, radius: float, height: float, colour: Color,
		rotation := Vector3.ZERO, name := "Capsule") -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	return add_mesh(parent, mesh, position, mat(colour, 0.72), Vector3.ONE, rotation, name)


# --------------------------------------------------------------------------
# terrain
# --------------------------------------------------------------------------

## A rounded grassy island. `width` is the full horizontal span in metres.
static func island(parent: Node3D, position: Vector3, width: float, theme: String,
		depth := 3.6) -> Node3D:
	var colours := palette(theme)
	var root := Node3D.new()
	root.name = "Island"
	root.position = position
	parent.add_child(root)
	var radius := width * 0.5

	var top := cylinder(root, Vector3(0, 0, 0), 1.0, 0.55, Color(colours["grass"]), Vector3(radius, 1, depth * 0.5), 0.85, "GrassTop")
	top.mesh.radial_segments = 40
	# a lighter mown patch makes the top read as grass rather than a disc
	var light := cylinder(root, Vector3(0, 0.29, 0), 0.92, 0.03, Color(colours["grass_light"]),
		Vector3(radius * 0.96, 1, depth * 0.48), 0.9, "GrassLight")
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dirt := cylinder(root, Vector3(0, -0.42, 0), 1.0, 0.7, Color(colours["dirt"]),
		Vector3(radius * 1.01, 1, depth * 0.51), 0.92, "Dirt")
	var rock := cylinder(root, Vector3(0, -1.35, 0), 0.72, 1.35, Color(colours["rock"]),
		Vector3(radius * 0.78, 1, depth * 0.38), 0.95, "Rock")
	var tip := add_mesh(root, _cone(radius * 0.62, 2.4, 20), Vector3(0, -2.9, 0),
		mat(Color(colours["rock"]).darkened(0.16), 0.95), Vector3(1, 1, 0.7), Vector3.ZERO, "Root")
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _cone(radius: float, height: float, segments := 20) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


static func dressing(parent: Node3D, origin: Vector3, width: float, theme: String, seed := 7) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var colours := palette(theme)
	var root := Node3D.new()
	root.name = "Dressing"
	root.position = origin
	parent.add_child(root)
	var half := width * 0.5 - 0.7
	for i in range(7):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-1.1, 1.1)
		if absf(x) < 1.3 and z > -0.4:
			continue
		grass_tuft(root, Vector3(x, 0.32, z), rng.randf_range(0.7, 1.3), colours)
	for i in range(5):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(0.25, 1.2)
		if absf(x) < 1.2:
			continue
		flower(root, Vector3(x, 0.32, z), Color(colours["accent"]), rng.randf_range(0.8, 1.15))
	return root


static func grass_tuft(parent: Node3D, position: Vector3, scale: float, colours: Dictionary) -> void:
	var knot := Node3D.new()
	knot.position = position
	knot.rotation.y = randf() * TAU
	parent.add_child(knot)
	for i in range(3):
		var blade := box(knot, Vector3((i - 1) * 0.09, 0.14, 0), Vector3(0.05, 0.3, 0.02),
			Color(colours["leaf"]).lightened(0.06), Vector3(0, 0, (i - 1) * 0.35), 1.0, "Blade")
		blade.scale = Vector3.ONE * scale


static func flower(parent: Node3D, position: Vector3, colour: Color, scale := 1.0) -> void:
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	cylinder(root, Vector3(0, 0.16, 0), 0.018, 0.32, Color("#5aa85e"), Vector3.ONE, 0.9, "Stem")
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		sphere(root, Vector3(cos(angle) * 0.07, 0.34, sin(angle) * 0.07), 0.055, colour, Vector3(1, 0.6, 1), 0.65)
	sphere(root, Vector3(0, 0.36, 0), 0.045, Color("#ffe27a"), Vector3(1, 0.7, 1), 0.6, "Centre")


static func tree(parent: Node3D, position: Vector3, scale := 1.0, theme := "meadow") -> Node3D:
	var colours := palette(theme)
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	var trunk := cylinder(root, Vector3(0, 0.95, 0), 0.15, 1.9,
		Color(colours["dirt"]).darkened(0.12), Vector3(1, 1, 1), 0.9, "Trunk")
	trunk.rotation.z = 0.04
	sphere(root, Vector3(0, 2.25, 0), 0.82, Color(colours["leaf"]), Vector3(1.05, 0.9, 1.0), 0.8, "Canopy")
	sphere(root, Vector3(-0.5, 1.95, 0.15), 0.55, Color(colours["leaf_light"]), Vector3(1, 0.85, 1), 0.85)
	sphere(root, Vector3(0.55, 2.0, -0.1), 0.6, Color(colours["leaf"]).lightened(0.05), Vector3(1, 0.9, 1), 0.85)
	sphere(root, Vector3(0.1, 2.7, 0.05), 0.48, Color(colours["leaf_light"]), Vector3(1, 0.9, 1), 0.85)
	# apples, for a little colour
	for i in range(3):
		var angle := float(i) * 2.1 + 0.5
		sphere(root, Vector3(cos(angle) * 0.62, 2.35 + sin(angle) * 0.28, 0.42 + sin(angle) * 0.25),
			0.09, Color("#ef6b5c"), Vector3.ONE, 0.55, "Fruit")
	var sway: Node = load("res://Scripts/World/Sway.gd").new()
	sway.set("amplitude", 0.012)
	sway.set("speed", 0.9 + randf() * 0.3)
	sway.set("phase", randf() * TAU)
	root.add_child(sway)
	return root


static func mushroom(parent: Node3D, position: Vector3, colour: Color, scale := 1.0) -> void:
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	cylinder(root, Vector3(0, 0.12, 0), 0.055, 0.24, Color("#fff3dd"), Vector3.ONE, 0.8, "Stalk")
	var cap := sphere(root, Vector3(0, 0.26, 0), 0.15, colour, Vector3(1.1, 0.62, 1.1), 0.5, "Cap")
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in range(3):
		var angle := float(i) * 2.4
		sphere(root, Vector3(cos(angle) * 0.08, 0.31, sin(angle) * 0.08), 0.022, Color("#fff6e8"), Vector3.ONE, 0.6, "Spot")


static func rock(parent: Node3D, position: Vector3, scale := 1.0, theme := "meadow") -> void:
	var colours := palette(theme)
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	var body := sphere(root, Vector3.ZERO, 0.36, Color(colours["rock"]), Vector3(1.1, 0.75, 0.95), 0.95, "Rock")
	body.rotation.z = randf_range(-0.2, 0.2)
	sphere(root, Vector3(0.24, 0.05, 0.1), 0.17, Color(colours["rock"]).lightened(0.08), Vector3(1, 0.8, 1), 0.95)


static func cloud(parent: Node3D, position: Vector3, scale := 1.0, opacity := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	var material := mat(Color(1, 1, 1, opacity), 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if opacity < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	for i in range(4):
		var x := (i - 1.5) * 0.62
		var y := sin(float(i) * 1.7) * 0.17
		var radius := 0.5 + (0.16 if i % 2 == 0 else 0.0)
		var puff := sphere(root, Vector3(x, y, 0), radius, Color(1, 1, 1, opacity), Vector3(1, 0.72, 0.9), 1.0, "Puff")
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func floating_rock(parent: Node3D, position: Vector3, scale := 1.0, theme := "meadow") -> Node3D:
	var colours := palette(theme)
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	cylinder(root, Vector3.ZERO, 1.0, 0.22, Color(colours["grass"]), Vector3(1.1, 1, 0.85), 0.9)
	add_mesh(root, _cone(0.75, 1.5, 14), Vector3(0, -0.85, 0),
		mat(Color(colours["rock"]).darkened(0.12), 0.95), Vector3(1, 1, 0.8), Vector3.ZERO, "Underside")
	var bob: Node = load("res://Scripts/World/Sway.gd").new()
	bob.set("amplitude", 0.16)
	bob.set("speed", 0.55)
	bob.set("phase", randf() * TAU)
	bob.set("vertical", true)
	root.add_child(bob)
	return root


static func hive(parent: Node3D, position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Hive"
	root.position = position
	parent.add_child(root)
	var honey := Color("#f2b544")
	var shade := Color("#d1952e")
	# hanging branch
	cylinder(root, Vector3(0, 1.25, 0), 0.09, 2.4, Color("#8a6440"), Vector3(1, 1, 1), 0.9, "Branch")
	sphere(root, Vector3(0, 0.72, 0), 0.39, honey, Vector3(1, 1.18, 1), 0.75, "HiveBody")
	for i in range(3):
		var ring := cylinder(root, Vector3(0, 0.42 + i * 0.27, 0), 0.405 - i * 0.035, 0.07,
			shade, Vector3(1, 1, 1), 0.8, "Ring")
		ring.scale.z = 0.98
	sphere(root, Vector3(0, 0.52, 0.34), 0.13, Color("#3d2a18"), Vector3(1, 1.25, 0.6), 0.9, "Entrance")
	var wobble: Node = load("res://Scripts/World/Sway.gd").new()
	wobble.set("amplitude", 0.025)
	wobble.set("speed", 0.7)
	wobble.set("phase", 1.3)
	root.add_child(wobble)
	return root


static func butterfly(parent: Node3D, position: Vector3, colour: Color) -> Node3D:
	var root := Node3D.new()
	root.position = position
	parent.add_child(root)
	var left := sphere(root, Vector3(-0.07, 0, 0), 0.075, colour, Vector3(0.7, 0.9, 0.25), 0.6, "LeftWing")
	var right := sphere(root, Vector3(0.07, 0, 0), 0.075, colour, Vector3(0.7, 0.9, 0.25), 0.6, "RightWing")
	left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flutter: Node = load("res://Scripts/World/Flutter.gd").new()
	flutter.set("left", left)
	flutter.set("right", right)
	root.add_child(flutter)
	return root


## The title screen diorama: a toy island with Biscuit, a tree, a hive and bees.
static func build_showcase(parent: Node3D) -> void:
	var colours := palette("meadow")
	var island_root := island(parent, Vector3(0, 0, 0), 12.0, "meadow")
	dressing(island_root, Vector3(0, 0, 0), 12.0, "meadow", 21)
	tree(island_root, Vector3(-4.2, 0.25, -0.6), 1.15, "meadow")
	tree(island_root, Vector3(3.8, 0.25, -1.2), 0.9, "meadow")
	mushroom(island_root, Vector3(-2.3, 0.3, 1.2), Color("#ef6b5c"), 1.0)
	mushroom(island_root, Vector3(2.4, 0.3, 1.5), Color("#f0a04b"), 0.8)
	rock(island_root, Vector3(-1.7, 0.4, -0.9), 0.8, "meadow")
	hive(island_root, Vector3(-3.9, 4.15, -0.4))
	var pup: Node3D = load("res://Scripts/World/Biscuit.gd").new()
	pup.position = Vector3(0.1, 0.28, 0.6)
	pup.rotation.y = -0.18
	pup.set("scale", Vector3.ONE * 1.35)
	island_root.add_child(pup)
	if pup.has_method("set_mood"):
		pup.call("set_mood", "idle")

	for i in range(6):
		var x := -9.5 + i * 3.7
		cloud(parent, Vector3(x, 7.4 + sin(i * 2.1) * 1.1, -12.0 - i * 1.3), 1.5, 0.92)
	cloud(parent, Vector3(6.5, 9.2, -15.0), 2.2, 0.8)
	floating_rock(parent, Vector3(-8.2, 3.1, -6.0), 1.15, "meadow")
	floating_rock(parent, Vector3(8.6, 4.2, -7.0), 0.85, "meadow")
	butterfly(parent, Vector3(1.7, 3.4, 1.2), Color("#ffd166"))
	butterfly(parent, Vector3(-1.4, 4.0, 0.8), Color("#ff9ec4"))
