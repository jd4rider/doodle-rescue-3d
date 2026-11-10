class_name LevelRuntime
extends Node3D
## One level, built from data and run by real 3D physics.
##
## Bee Defence, Bridge Build, Danger Dodge and Contraptions all share the same
## drawing plane, terrain builder and star rule. Each mode only supplies its
## own objective and its own actors. Win and loss are read from the simulation
## that actually ran: bee proximity, the walker's position, a hazard's distance
## to Biscuit, or a ball resting on the target pad.

signal won(stars: int, used: float, seconds: float)
signal lost(reason: String)
signal started
signal feedback(kind: String, position: Vector3)

const GROUND_TOP := 0.28
const PEN_LAYER := 8

var level: Dictionary = {}
var mode := "bee"
var theme := "meadow"
var phase := "draw"
var duration := 10.0
var budget := 10.0
var used := 0.0
var elapsed := 0.0
var draw_bounds := Rect2(-4.2, 0.4, 8.4, 6.8)
var camera: Camera3D

var biscuit: Biscuit
var swarm: BeeSwarm
var walker: CharacterBody3D
var deck: Node3D
var deck_span := 0.0
var ball: RigidBody3D
var hazards: Array = []
var target_position := Vector3.ZERO
var target_radius := 0.9
var strokes: Array = []
var reset_count := 0
var door_center := Vector3.ZERO
var door_radius := 1.15
var door_sockets: PackedVector2Array = PackedVector2Array()
var shoved_count := 0
var _plug_body: Variant = null
var _door_ring: MeshInstance3D
var _door_ring_mat: StandardMaterial3D

var _pending: Array = []
var _goal := Vector3.ZERO
var _warning_root: Node3D
var _target_ring: MeshInstance3D
var _target_fill: MeshInstance3D
var _target_done := 0.0
var _ball_inside := false
var _walker_on := false
var _walker_floor := 0.0
var _sag := 0.0
var _deck_min_x := 999.0
var _deck_max_x := -999.0
var _bees_enabled := false
var _hazard_hit := false
var _time_scale := 1.0
var _theme_colours: Dictionary
var trace := false
var _trace_tick := 0.0


func build(data: Dictionary, cam: Camera3D) -> void:
	level = data
	camera = cam
	mode = String(level.get("mode", "bee"))
	theme = String(level.get("theme", "meadow"))
	duration = float(level.get("duration", 10.0))
	budget = float(level.get("budget", 10.0))
	var bounds: Array = level.get("bounds", [-4.2, 0.4, 4.2, 7.2])
	draw_bounds = Rect2(float(bounds[0]), float(bounds[1]),
		float(bounds[2]) - float(bounds[0]), float(bounds[3]) - float(bounds[1]))
	_theme_colours = Decor.palette(theme)

	_build_backdrop()
	_warning_root = Node3D.new()
	_warning_root.name = "Warnings"
	add_child(_warning_root)

	match mode:
		"bridge":
			_build_bridge()
		"dodge":
			_build_ground_level()
			_build_hazards()
		"contraption":
			_build_ground_level()
			_build_contraption()
		_:
			_build_ground_level()
			_build_bee_level()

	_build_blocks()
	_fit_camera()
	_build_warnings()


# --------------------------------------------------------------------------
# environment
# --------------------------------------------------------------------------

func _build_backdrop() -> void:
	var id := int(level.get("id", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7717
	# layered background: clouds, floating islands and far-off trees
	for i in range(5):
		var x := -13.0 + i * 6.4 + rng.randf_range(-1.0, 1.0)
		Decor.cloud(self, Vector3(x, 10.0 + rng.randf_range(-1.5, 2.0), -16.0 - i * 2.0),
			rng.randf_range(1.5, 2.6), 0.82)
	for i in range(3):
		Decor.floating_rock(self, Vector3(-10.0 + i * 10.0 + rng.randf_range(-1.0, 1.0),
			4.0 + rng.randf_range(0.0, 3.0), -9.0 - rng.randf_range(0.0, 4.0)),
			rng.randf_range(0.8, 1.5), theme)
	Decor.butterfly(self, Vector3(rng.randf_range(-3.0, 3.0), 4.4, 1.4), Color(_theme_colours["accent"]))
	Decor.butterfly(self, Vector3(rng.randf_range(-3.0, 3.0), 5.2, 0.8), Color("#ffffff"))


func _build_ground_level() -> void:
	var span: Array = level.get("platform", [draw_bounds.position.x - 1.5, draw_bounds.end.x + 1.5])
	var x0 := float(span[0])
	var x1 := float(span[1])
	var width := x1 - x0
	var centre := (x0 + x1) * 0.5
	var island_root := Decor.island(self, Vector3(centre, 0, 0), width + 1.5, theme)
	Decor.dressing(island_root, Vector3(0, 0, 0), width + 1.5, theme, int(level.get("id", 1)) * 31)
	# readable edge props (bee levels put the kennel here instead)
	if mode != "bee":
		Decor.tree(island_root, Vector3(-width * 0.42, GROUND_TOP, -1.0), 0.7, theme)
		Decor.tree(island_root, Vector3(width * 0.42, GROUND_TOP, -1.4), 0.55, theme)
		Decor.mushroom(island_root, Vector3(-width * 0.30, GROUND_TOP, 0.9), Color(_theme_colours["accent"]), 0.8)
		Decor.rock(island_root, Vector3(width * 0.35, GROUND_TOP, 1.1), 0.55, theme)

	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 2.0, 1.0, 5.0)
	shape.shape = box
	shape.position = Vector3(centre, GROUND_TOP - 0.5, 0)
	body.add_child(shape)

	var b: Array = level.get("biscuit", [0.0, GROUND_TOP])
	biscuit = Biscuit.new()
	biscuit.name = "Biscuit"
	biscuit.position = Vector3(float(b[0]), float(b[1]), 0.5)
	biscuit.scale = Vector3.ONE * 0.88
	add_child(biscuit)


func _build_bee_level() -> void:
	_build_doghouse()
	var hive_list: Array = level.get("hives", [])
	var world_hives: Array = []
	for value in hive_list:
		var pair: Array = value
		var position := Vector3(float(pair[0]), float(pair[1]), 0.0)
		world_hives.append(position + Vector3(0, 0.5, 0))
		Decor.hive(self, position + Vector3(0, -0.55, 0))
		# a little branch arm holding the hive
		Decor.cylinder(self, position + Vector3(0.7, 1.2, 0), 0.07, 1.8,
			Color(_theme_colours["dirt"]).darkened(0.08), Vector3(1, 1, 1), 0.9, "HiveBranch").rotation.z = 0.5
	swarm = BeeSwarm.new()
	swarm.name = "Bees"
	add_child(swarm)
	swarm.setup(world_hives, biscuit, int(level.get("bees", 8)),
		door_center + Vector3(0, 0, 0.2), door_radius)
	swarm.stung.connect(_on_stung)
	swarm.bee_reached.connect(func() -> void:
		if biscuit != null:
			biscuit.set_mood("nervous"))
	swarm.bonked.connect(func(position: Vector3) -> void:
		if has_node("/root/Audio"):
			get_node("/root/Audio").wood_hit()
		feedback.emit("bonk", position))


## A kennel with one round doorway. Biscuit is visible through the hole and
## the bees have to come through it — so the doodle the player draws over the
## opening is the thing the level is actually about.
func _build_doghouse() -> void:
	var data: Dictionary = level.get("door", {})
	var x := float(data.get("x", 0.0))
	var y := float(data.get("y", 1.35))
	var radius := float(data.get("radius", 1.15))
	door_center = Vector3(x, y, 0.0)
	door_radius = radius
	door_sockets = PackedVector2Array()
	# Catch points sit on the wide wooden frame, beyond the physical hole. A
	# doodle that ends here overlaps the wall, so bees cannot squeeze around it.
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		door_sockets.append(Vector2(x + cos(angle) * (radius + 0.45),
			y + sin(angle) * (radius + 0.45)))

	if biscuit != null:
		biscuit.position = Vector3(x, GROUND_TOP, -0.68)
		biscuit.scale = Vector3.ONE * 0.9
		biscuit.rotation.y = 0.0
		biscuit.set_mood("idle")

	var half_w := maxf(2.65, radius + 1.45)
	var top := y + radius + 0.95
	var wood := Color(_theme_colours["dirt"]).lightened(0.14)
	var wood_dark := wood.darkened(0.2)
	var roof_colour := Color(_theme_colours["grass"]).darkened(0.12)

	var front := Node3D.new()
	front.name = "KennelFront"
	add_child(front)
	var wall := StaticBody3D.new()
	wall.name = "KennelWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	front.add_child(wall)

	# Plank grid with a round hole left in it. The collision sits behind the
	# drawing plane so a doodle can be shoved inward without starting life
	# intersecting the wall.
	var tile := 0.7
	var columns := int(ceil((half_w * 2.0) / tile))
	var rows := int(ceil((top - GROUND_TOP) / tile))
	for cx in range(columns):
		for cy in range(rows):
			var px := -half_w + tile * 0.5 + float(cx) * tile
			var py := GROUND_TOP + tile * 0.5 + float(cy) * tile
			if Vector2(px - x, py - y).length() < radius - 0.02:
				continue
			Decor.box(front, Vector3(px, py, -0.28), Vector3(tile + 0.02, tile + 0.02, 0.55),
				wood if (cx + cy) % 2 == 0 else wood_dark, Vector3.ZERO, 0.72, "Plank")
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(tile, tile, 0.34)
			shape.shape = box
			shape.position = Vector3(px, py, -0.78)
			wall.add_child(shape)

	# sides, back and roof: one way in, and it is round
	for side in [-1.0, 1.0]:
		_panel(Vector3(side * half_w, (GROUND_TOP + top) * 0.5, -0.95),
			Vector3(0.34, top - GROUND_TOP, 1.9), wood_dark)
	_panel(Vector3(0, (GROUND_TOP + top) * 0.5, -1.9),
		Vector3(half_w * 2.0 + 0.3, top - GROUND_TOP, 0.3), wood_dark)
	# The roof starts behind the flight lane: an overhang in front of the door
	# would stop the bees before they could ever test the doodle.
	_panel(Vector3(0, top + 0.08, -1.2),
		Vector3(half_w * 2.0 + 0.5, 0.3, 1.8), roof_colour)

	# a wide wooden frame around the doorway, plus the glowing "fill me" guide
	Decor.add_mesh(self, _torus(radius - 0.02, radius + 0.6), Vector3(x, y, 0.34),
		Decor.mat(wood_dark, 0.55, 0.05, 0.0), Vector3.ONE, Vector3(PI * 0.5, 0, 0), "DoorFrame")
	var guide := StandardMaterial3D.new()
	guide.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide.albedo_color = Color("#ffcf5c")
	guide.emission_enabled = true
	guide.emission = Color("#ffcf5c")
	guide.emission_energy_multiplier = 1.4
	_door_ring = Decor.add_mesh(self, _torus(radius + 0.2, radius + 0.27),
		Vector3(x, y, 0.44), guide, Vector3.ONE, Vector3(PI * 0.5, 0, 0), "DoorGuide")
	_door_ring_mat = guide
	_door_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# a blanket and a bowl inside, visible through the round door
	Decor.box(self, Vector3(x - radius * 0.45, GROUND_TOP + 0.03, -1.05),
		Vector3(0.7, 0.06, 0.5), Color("#f2b8c6"), Vector3.ZERO, 0.8, "Blanket")
	Decor.cylinder(self, Vector3(x + radius * 0.55, GROUND_TOP + 0.06, -1.05), 0.16, 0.09,
		Color("#7fb2e5"), Vector3.ONE, 0.5, "Bowl")
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(x, y + 0.4, -1.25)
	lamp.light_color = Color("#ffd9a0")
	lamp.light_energy = 0.8
	lamp.omni_range = 4.0
	lamp.shadow_enabled = false
	add_child(lamp)
	_update_door_ring()


func _panel(centre: Vector3, size: Vector3, colour: Color) -> void:
	var root := Node3D.new()
	root.position = centre
	add_child(root)
	Decor.box(root, Vector3.ZERO, size, colour, Vector3.ZERO, 0.78, "Panel")
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _build_bridge() -> void:
	var data: Dictionary = level.get("bridge", {})
	var left: Array = data.get("left", [-3.5, 3.2])
	var right: Array = data.get("right", [3.5, 2.8])
	var start: Array = data.get("start", [float(left[0]) - 2.0, float(left[1]) + 0.8])
	_goal = Vector3(float(right[0]) + 1.6, float(right[1]), 0)

	var lip_left := Vector2(float(left[0]), float(left[1]))
	var lip_right := Vector2(float(right[0]), float(right[1]))

	# left cliff
	var left_x0 := draw_bounds.position.x - 2.4
	var left_width := lip_left.x - left_x0
	var left_centre := (left_x0 + lip_left.x) * 0.5
	_bridge_cliff(left_centre, left_width, lip_left.y, true)
	# right cliff
	var right_x1 := draw_bounds.end.x + 2.4
	var right_width := right_x1 - lip_right.x
	var right_centre := (lip_right.x + right_x1) * 0.5
	_bridge_cliff(right_centre, right_width, lip_right.y, false)

	# a waterfall and a few rocks in the gap, well below the deck
	for i in range(3):
		Decor.rock(self, Vector3(randf_range(-1.2, 1.2), -2.0 - i * 0.7, -1.2), 0.7 + i * 0.2, theme)
	Decor.cloud(self, Vector3(0, -2.4, -4.0), 1.6, 0.65)

	# glowing anchor rings make the intended lips obvious
	_anchor_ring(Vector3(lip_left.x - 0.1, lip_left.y, 0.3), Color("#8ce88f"))
	_anchor_ring(Vector3(lip_right.x + 0.1, lip_right.y, 0.3), Color("#8ce88f"))

	# finish flag on the far lip
	var flag := Node3D.new()
	flag.position = Vector3(_goal.x, float(right[1]), 0.4)
	add_child(flag)
	Decor.cylinder(flag, Vector3(0, 0.55, 0), 0.035, 1.5, Color("#f4ead8"), Vector3.ONE, 0.8, "Pole")
	Decor.box(flag, Vector3(0.24, 1.1, 0), Vector3(0.48, 0.32, 0.04), Color("#ff9f43"), Vector3.ZERO, 0.6, "Flag")

	walker = CharacterBody3D.new()
	walker.name = "Walker"
	walker.collision_layer = 16
	walker.collision_mask = 1 | 8
	walker.floor_snap_length = 0.55
	walker.floor_max_angle = 0.95
	# Centred on the deck: a walker at the edge of the 0.64 m plank slides off
	# the moment a step-hop nudges him sideways.
	walker.position = Vector3(float(start[0]), float(start[1]) + 0.1, 0.0)
	add_child(walker)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 0.98
	shape.shape = capsule
	shape.position.y = 0.49
	walker.add_child(shape)
	biscuit = Biscuit.new()
	biscuit.position = Vector3(0, 0.05, 0)
	biscuit.scale = Vector3.ONE * 0.78
	walker.add_child(biscuit)
	biscuit.set_mood("curious")
	_walker_floor = walker.position.y


func _bridge_cliff(centre: float, width: float, top: float, is_left: bool) -> void:
	var root := Decor.island(self, Vector3(centre, top - 0.275, 0), maxf(width, 2.2), theme)
	Decor.dressing(root, Vector3(0, 0, 0), maxf(width, 2.2), theme, int(centre * 13.0))
	if width > 2.6:
		Decor.tree(root, Vector3(-width * 0.3, GROUND_TOP, -0.8), 0.6, theme)
	Decor.rock(root, Vector3(width * 0.3, GROUND_TOP, 0.6), 0.5, theme)
	var body := StaticBody3D.new()
	body.name = "Cliff"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 8.0, 4.4)
	shape.shape = box
	shape.position = Vector3(centre, top - 4.0, 0)
	body.add_child(shape)
	# a visible lip so Biscuit's feet meet the cliff exactly
	Decor.box(self, Vector3(centre, top - 0.1, 0), Vector3(width, 0.22, 3.0),
		Color(_theme_colours["grass"]).darkened(0.02), Vector3.ZERO, 0.85, "Lip")


func _build_hazards() -> void:
	var list: Array = level.get("hazards", [])
	for entry_value in list:
		var entry: Dictionary = entry_value
		_pending.append({
			"type": String(entry.get("type", "boulder")),
			"at": Vector3(float(entry.get("at", [0, 6])[0]), float(entry.get("at", [0, 6])[1]), 0.0),
			"velocity": entry.get("velocity", [0, 0]),
			"delay": float(entry.get("delay", 0.6)),
			"spawned": false,
		})


func _build_contraption() -> void:
	var data: Dictionary = level.get("ball", {})
	var at: Array = data.get("at", [0, 7])
	var vel: Array = data.get("velocity", [0, 0])
	ball = RigidBody3D.new()
	ball.name = "Ball"
	ball.freeze = true
	ball.collision_layer = 4
	ball.collision_mask = 1 | 8
	ball.mass = 1.1
	ball.continuous_cd = true
	ball.position = Vector3(float(at[0]), float(at[1]), 0.2)
	add_child(ball)
	var material := PhysicsMaterial.new()
	material.bounce = 0.04
	material.friction = 0.75
	ball.physics_material_override = material
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.42
	shape.shape = sphere
	ball.add_child(shape)
	var visual := Node3D.new()
	ball.add_child(visual)
	Decor.sphere(visual, Vector3.ZERO, 0.42, Color("#ff7fb6"), Vector3.ONE, 0.3, "ToyBall")
	Decor.sphere(visual, Vector3(0, 0.09, 0.36), 0.2, Color("#fff4e2"), Vector3(1, 1, 0.35), 0.4, "Stripe")
	Decor.sphere(visual, Vector3(0, -0.06, -0.37), 0.2, Color("#fff4e2"), Vector3(1, 1, 0.35), 0.4, "Stripe")
	var trail := CPUParticles3D.new()
	trail.amount = 16
	trail.lifetime = 0.4
	trail.emitting = true
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.02
	trail.initial_velocity_max = 0.12
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 0.65
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.3
	var spark := QuadMesh.new()
	spark.size = Vector2(0.1, 0.1)
	trail.mesh = spark
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color("#ffd6e8")
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.vertex_color_use_as_albedo = true
	trail.material_override = spark_material
	ball.add_child(trail)
	ball.linear_velocity = Vector3(float(vel[0]), float(vel[1]), 0)

	var target: Array = level.get("target", [3.0, GROUND_TOP])
	target_position = Vector3(float(target[0]), float(target[1]) + 0.12, 0.3)
	target_radius = float(level.get("target_radius", 0.95))
	var approach_side := signf(ball.position.x - target_position.x)
	_build_target(-approach_side if approach_side != 0.0 else 1.0)


func _build_target(backstop_side: float) -> void:
	var pad := Node3D.new()
	pad.position = target_position
	add_child(pad)
	_target_fill = Decor.cylinder(pad, Vector3(0, 0.02, 0), target_radius, 0.12,
		Color("#d9f2c9"), Vector3(1, 1, 1), 0.6, "Pad")
	var ring := Decor.add_mesh(pad, _torus(target_radius, target_radius + 0.09),
		Vector3(0, 0.09, 0), Decor.mat(Color("#4fb069"), 0.4, 0.2, 0.4), Vector3.ONE,
		Vector3(PI * 0.5, 0, 0), "Ring")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring = ring
	Decor.cylinder(pad, Vector3(target_radius + 0.35, 0.55, 0), 0.03, 1.1,
		Color("#f4ead8"), Vector3.ONE, 0.8, "FlagPole")
	Decor.box(pad, Vector3(target_radius + 0.55, 1.0, 0), Vector3(0.36, 0.26, 0.03),
		Color("#4fb069"), Vector3.ZERO, 0.6, "Flag")
	# Low catch walls turn the pad into a little basket, so a rolling ball settles
	# instead of skittering straight across it.
	for side in [-1.0, 1.0]:
		var offset := Vector3((target_radius + 0.32) * side, 0.22, 0)
		Decor.box(pad, offset, Vector3(0.16, 0.44, 1.7), Color("#9fce8d"), Vector3.ZERO, 0.8, "Catch")
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		pad.add_child(wall)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.16, 0.44, 1.7)
		shape.shape = box
		shape.position = offset
		wall.add_child(shape)
	# a tall backstop on the far side of the pad catches the arriving ball
	var back := Vector3((target_radius + 0.34) * backstop_side, 0.62, 0)
	Decor.box(pad, back, Vector3(0.2, 1.24, 2.0), Color("#7fbf7a"), Vector3.ZERO, 0.75, "Backstop")
	var back_body := StaticBody3D.new()
	back_body.collision_layer = 1
	back_body.collision_mask = 0
	pad.add_child(back_body)
	var back_shape := CollisionShape3D.new()
	var back_box := BoxShape3D.new()
	back_box.size = Vector3(0.2, 1.24, 2.0)
	back_shape.shape = back_box
	back_shape.position = back
	back_body.add_child(back_shape)


func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	return mesh


func _build_blocks() -> void:
	var blocks: Array = level.get("blocks", [])
	for value in blocks:
		var block: Array = value
		var x := float(block[0])
		var y := float(block[1])
		var w := float(block[2])
		var h := float(block[3])
		var node := Node3D.new()
		node.position = Vector3(x, y, 0)
		add_child(node)
		Decor.box(node, Vector3.ZERO, Vector3(w, h, 1.4), Color(_theme_colours["rock"]),
			Vector3.ZERO, 0.9, "Block")
		var lip := Decor.box(node, Vector3(0, h * 0.5 - 0.06, 0), Vector3(w + 0.08, 0.12, 1.5),
			Color(_theme_colours["grass"]), Vector3.ZERO, 0.85, "BlockTop")
		lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		node.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w, h, 1.4)
		shape.shape = box
		body.add_child(shape)


func _anchor_ring(position: Vector3, colour: Color) -> void:
	var ring := Decor.add_mesh(self, _torus(0.34, 0.44), position,
		Decor.mat(colour, 0.35, 0.1, 0.7), Vector3.ONE, Vector3(PI * 0.5, 0, 0), "Anchor")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _fit_camera() -> void:
	if camera == null:
		return
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size if viewport != null else Vector2(720, 1280)
	var aspect := size.x / maxf(1.0, size.y)
	var centre := draw_bounds.get_center()
	var width := draw_bounds.size.x + 3.6
	var height := draw_bounds.size.y + 3.2
	var half_fov := deg_to_rad(camera.fov) * 0.5
	var distance_for_height := (height * 0.5) / tan(half_fov)
	var distance_for_width := (width * 0.5) / (tan(half_fov) * maxf(aspect, 0.3))
	var distance := maxf(distance_for_height, distance_for_width) * 1.02 + 2.4
	var camera_y := centre.y + 0.85
	camera.position = Vector3(centre.x, camera_y, distance)
	camera.look_at(Vector3(centre.x, centre.y - 0.35, 0.0))
	camera.fov = 50.0


func _build_warnings() -> void:
	var colour := Color("#e05d55")
	var sources: Array = []
	if mode == "bee":
		for value in (level.get("hives", []) as Array):
			var pair: Array = value
			sources.append(Vector3(float(pair[0]), float(pair[1]), 0.35))
	elif mode == "dodge":
		for value in (level.get("hazards", []) as Array):
			var entry: Dictionary = value
			var at: Array = entry.get("at", [0, 6])
			sources.append(Vector3(float(at[0]), float(at[1]), 0.35))
	if biscuit == null:
		return
	for source in sources:
		var target: Vector3 = biscuit.global_position + Vector3(0, 0.9, 0.4)
		if mode == "bee":
			target = door_center + Vector3(0, 0, 0.55)
		var count := 5
		for i in range(1, count + 1):
			var t := float(i) / float(count + 1)
			var point := (source as Vector3).lerp(target, t)
			var dot := Decor.sphere(_warning_root, point, 0.055, colour, Vector3.ONE, 0.4, "Warning")
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := dot.material_override as StandardMaterial3D
			if material != null:
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(0.9, 0.32, 0.3, 0.55)
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


# --------------------------------------------------------------------------
# drawing
# --------------------------------------------------------------------------

func add_stroke(points: PackedVector2Array) -> Dictionary:
	if phase != "draw" or points.size() < 2:
		return {}
	if mode == "bee":
		points = _snap_to_door(points)
	var animated := mode == "bridge"
	if animated:
		# A bridge is drawn along its walking surface, so the finished deck sits
		# just under the stroke rather than half a beam above it.
		var lowered := PackedVector2Array()
		for point in points:
			lowered.append(point - Vector2(0, BeamBuilder.THICKNESS))
		points = lowered
	var stroke := BeamBuilder.build_stroke(self, points, Save.pen_colour(), animated)
	var body: Variant = stroke["body"]
	if body != null:
		if body.has_signal("shoved"):
			body.shoved.connect(_on_stroke_shoved.bind(body))
		if mode == "bee" and _plug_body == null and _stroke_near_door(points):
			_attach_plug(body)
	strokes.append(stroke)
	used += float(stroke["length"])
	if mode == "bee":
		_evaluate_strokes()
		if body != null:
			feedback.emit("secure_doodle" if body.is_secure() else "loose_doodle", Vector3.ZERO)
	if mode == "bridge" and deck == null:
		deck = stroke["node"] as Node3D
		_compute_deck_span(points)
	_play_place_burst(points)
	if has_node("/root/Audio"):
		get_node("/root/Audio").draw_end()
	return stroke


func remove_last_stroke() -> bool:
	if strokes.is_empty() or phase != "draw":
		return false
	var stroke: Dictionary = strokes.pop_back()
	if stroke["body"] == _plug_body:
		_plug_body = null
	used = maxf(0.0, used - float(stroke["length"]))
	if stroke["node"] == deck:
		deck = null
		deck_span = 0.0
	(stroke["node"] as Node).queue_free()
	if mode == "bee":
		_evaluate_strokes()
	return true


func clear_strokes() -> void:
	for stroke in strokes:
		var node: Node = stroke["node"]
		if node != null and is_instance_valid(node):
			node.queue_free()
	strokes.clear()
	_plug_body = null
	used = 0.0
	deck = null
	deck_span = 0.0
	if mode == "bee":
		_evaluate_strokes()


func _compute_deck_span(points: PackedVector2Array) -> void:
	_deck_min_x = 999.0
	_deck_max_x = -999.0
	for point in points:
		_deck_min_x = minf(_deck_min_x, point.x)
		_deck_max_x = maxf(_deck_max_x, point.x)
	deck_span = _deck_max_x - _deck_min_x


func remaining() -> float:
	return maxf(0.0, budget - used)


func stars_for(used_length: float) -> int:
	if used_length <= budget * 0.66:
		return 3
	if used_length <= budget * 0.86:
		return 2
	return 1


# --------------------------------------------------------------------------
# simulation
# --------------------------------------------------------------------------

func start_simulation() -> void:
	if phase != "draw":
		return
	if used < 0.2:
		feedback.emit("empty", Vector3.ZERO)
		return
	phase = "sim"
	elapsed = 0.0
	if _warning_root != null:
		_warning_root.visible = false
	match mode:
		"bee":
			_evaluate_strokes()
			if swarm != null:
				swarm.start()
			_bees_enabled = true
			if biscuit != null:
				biscuit.set_mood("nervous")
		"bridge":
			_walker_on = true
			if biscuit != null:
				biscuit.walking = true
				biscuit.set_mood("curious")
		"contraption":
			if ball != null and is_instance_valid(ball):
				ball.freeze = false
		"dodge":
			pass
	started.emit()


func _process(delta: float) -> void:
	if phase != "sim":
		_update_idle(delta)
		return
	elapsed += delta
	match mode:
		"bee":
			if elapsed >= duration:
				_win()
		"dodge":
			spawn_pending_hazards()
			_update_dodge()
			if phase == "sim" and elapsed >= duration:
				_win()
		"contraption":
			_update_contraption(delta)
			if phase == "sim" and elapsed >= duration:
				_lose("The ball never found the pad. Try a longer ramp.")
		"bridge":
			if elapsed >= duration:
				_lose("Biscuit ran out of time on the bridge.")


func _update_idle(delta: float) -> void:
	if phase != "draw":
		return
	if mode == "dodge" and biscuit != null:
		biscuit.set_mood("curious")
	if mode == "bee":
		if biscuit != null:
			biscuit.set_mood("idle")
		if _door_ring != null and is_instance_valid(_door_ring):
			var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.025
			_door_ring.scale = Vector3(pulse, pulse, pulse)


func _physics_process(delta: float) -> void:
	if phase != "sim":
		return
	if mode == "bridge":
		_update_walker(delta)
	elif mode == "dodge":
		_check_hazards()


func _update_walker(delta: float) -> void:
	if trace:
		_trace_tick += delta
		if _trace_tick >= 0.25:
			_trace_tick = 0.0
			print("    walker t=%.2f pos=%s vel=%s floor=%s deck=%s" % [elapsed, str(walker.global_position), str(walker.velocity), str(walker.is_on_floor()), str(deck != null)])
	if not _walker_on or walker == null:
		return
	var velocity := walker.velocity
	velocity.y -= 18.0 * delta
	velocity.x = 1.85
	velocity.z = 0.0
	# A lip, a plank or a small step is not a wall to a puppy: hop over it.
	if walker.is_on_floor() and (walker.is_on_wall() or walker.get_slide_collision_count() > 0):
		velocity.y = 4.8
		feedback.emit("hop", walker.global_position)
	walker.velocity = velocity
	walker.move_and_slide()
	# The deck is a straight plank; keep the crossing one-dimensional.
	walker.position.z = 0.0
	if biscuit != null:
		biscuit.walking = absf(walker.velocity.x) > 0.1
		biscuit.rotation.y = PI * 0.5
		if walker.is_on_floor():
			biscuit.set_mood("curious")

	# the deck visibly carries the walker's weight
	if deck != null and is_instance_valid(deck) and _deck_max_x > _deck_min_x:
		var x := walker.global_position.x
		var inside := x > _deck_min_x - 0.4 and x < _deck_max_x + 0.4
		var target := 0.0
		if inside:
			var half := maxf(0.4, (_deck_max_x - _deck_min_x) * 0.5)
			var t := clampf((x - _deck_min_x) / maxf(0.1, _deck_max_x - _deck_min_x), 0.0, 1.0)
			target = -0.05 - sin(t * PI) * minf(0.30, half * 0.035)
		_sag = lerpf(_sag, target, 0.12)
		deck.position.y = _sag

	if walker.global_position.x >= _goal.x - 0.5:
		_win()
	elif walker.global_position.y < -5.0:
		_lose("Biscuit fell into the ravine.")


func _update_dodge() -> void:
	if _hazard_hit:
		return
	for hazard in hazards:
		var node: RigidBody3D = hazard
		if not is_instance_valid(node):
			continue
		if node.global_position.y < -7.0:
			continue
		if biscuit != null and node.global_position.distance_to(
				biscuit.global_position + Vector3(0, 0.7, 0)) < 1.05:
			_hazard_hit = true
			_lose("A rolling toy bumped into Biscuit.")
			return
	if biscuit != null:
		var nearest := 99.0
		for hazard in hazards:
			var node: RigidBody3D = hazard
			if is_instance_valid(node):
				nearest = minf(nearest, node.global_position.distance_to(
					biscuit.global_position + Vector3(0, 0.7, 0)))
		biscuit.set_mood("scared" if nearest < 2.6 else "nervous" if nearest < 5.0 else "idle")


func _check_hazards() -> void:
	_update_dodge()


func _update_contraption(delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if trace:
		_trace_tick += delta
		if _trace_tick >= 0.25:
			_trace_tick = 0.0
			print("    ball t=%.2f pos=%s vel=%s" % [elapsed, str(ball.global_position), str(ball.linear_velocity)])
	var d := Vector2(ball.global_position.x - target_position.x, ball.global_position.y - target_position.y).length()
	var inside := d < target_radius
	if inside:
		_target_done += delta
	else:
		_target_done = maxf(0.0, _target_done - delta * 0.5)
	_ball_inside = inside
	if ball.global_position.y < -7.0:
		_lose("The ball rolled out of the toybox.")
		return
	if biscuit != null:
		biscuit.look_at_point(ball.global_position)
		biscuit.set_mood("happy" if inside else "curious")
	if _target_ring != null:
		var pulse := 1.0 + sin(elapsed * 6.0) * 0.06
		_target_ring.scale = Vector3(pulse, pulse, pulse)
		(_target_ring.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5 if inside else 0.5
	if _target_fill != null:
		(_target_fill.material_override as StandardMaterial3D).albedo_color = \
			Color("#b8ed9a") if inside else Color("#d9f2c9")
	if _target_done >= 0.18:
		_win()


func spawn_pending_hazards() -> void:
	for entry in _pending:
		if bool(entry["spawned"]):
			continue
		if elapsed < float(entry["delay"]):
			continue
		entry["spawned"] = true
		_make_hazard(String(entry["type"]), entry["at"] as Vector3, entry["velocity"] as Array)


func _make_hazard(kind: String, at: Vector3, velocity: Array) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 1 | 8
	body.continuous_cd = true
	body.position = at
	body.contact_monitor = true
	body.max_contacts_reported = 2
	add_child(body)
	var shape := CollisionShape3D.new()
	var material := PhysicsMaterial.new()
	material.bounce = 0.22
	material.friction = 0.7
	body.physics_material_override = material
	var visual := Node3D.new()
	body.add_child(visual)

	if kind == "crate":
		body.mass = 3.4
		var box := BoxShape3D.new()
		box.size = Vector3(0.78, 0.78, 0.78)
		shape.shape = box
		Decor.box(visual, Vector3.ZERO, Vector3(0.78, 0.78, 0.78), Color("#d8a15c"), Vector3.ZERO, 0.8, "Crate")
		for i in range(2):
			Decor.box(visual, Vector3(0, 0, 0.4 - i * 0.8), Vector3(0.86, 0.1, 0.04),
				Color("#b57a3d"), Vector3.ZERO, 0.85, "Slat")
		Decor.box(visual, Vector3(0, 0.3, 0.41), Vector3(0.5, 0.16, 0.03), Color("#b57a3d"),
			Vector3.ZERO, 0.85, "Label")
	elif kind == "ball":
		body.mass = 1.0
		material.bounce = 0.68
		var sphere := SphereShape3D.new()
		sphere.radius = 0.36
		shape.shape = sphere
		Decor.sphere(visual, Vector3.ZERO, 0.36, Color("#5fbfe8"), Vector3.ONE, 0.35, "Bouncy")
		Decor.sphere(visual, Vector3(0, 0.26, 0), 0.12, Color("#ffffff"), Vector3(1, 0.6, 1), 0.4, "Spot")
	else:
		body.mass = 6.5
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 0.7
		shape.shape = sphere_shape
		var rock := Decor.sphere(visual, Vector3.ZERO, 0.7, Color("#a49a8b"), Vector3(1.05, 0.96, 1.0), 0.95, "Boulder")
		rock.rotation.z = 0.2
		for i in range(3):
			var angle := float(i) * 2.2
			Decor.sphere(visual, Vector3(cos(angle) * 0.5, sin(angle) * 0.3, 0.45), 0.22,
				Color("#8e8477"), Vector3(1, 0.9, 1), 0.95, "Chip")
	body.add_child(shape)
	body.linear_velocity = Vector3(float(velocity[0]), float(velocity[1]), 0)
	body.angular_velocity = Vector3(0, 0, -float(velocity[0]) * 0.4)
	body.body_entered.connect(func(_other: Node) -> void:
		if has_node("/root/Audio"):
			get_node("/root/Audio").thud()
		feedback.emit("impact", body.global_position))
	hazards.append(body)


func _on_stung() -> void:
	if phase != "sim":
		return
	if biscuit != null:
		biscuit.set_mood("scared")
	_lose("A bee got through the round doorway. Fill it with a doodle that catches the rim on both sides.")


func _win() -> void:
	if phase != "sim":
		return
	phase = "won"
	if swarm != null:
		swarm.flee()
	if biscuit != null:
		biscuit.celebrate()
	_celebrate_burst()
	if has_node("/root/Audio"):
		get_node("/root/Audio").win()
	won.emit(stars_for(used), used, elapsed)


func _lose(reason: String) -> void:
	if phase != "sim":
		return
	phase = "lost"
	if swarm != null:
		swarm.stop()
	if biscuit != null:
		biscuit.set_mood("scared")
	if has_node("/root/Audio"):
		get_node("/root/Audio").bee(0.0)
		get_node("/root/Audio").fail()
	lost.emit(reason)


func _celebrate_burst() -> void:
	var burst := CPUParticles3D.new()
	burst.amount = 36
	burst.lifetime = 1.4
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.emitting = true
	burst.gravity = Vector3(0, -5.0, 0)
	burst.initial_velocity_min = 2.4
	burst.initial_velocity_max = 5.2
	burst.spread = 70.0
	burst.direction = Vector3(0, 1, 0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.5
	burst.scale_amount_min = 0.4
	burst.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	burst.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	burst.material_override = material
	var ramp := Gradient.new()
	ramp.set_color(0, Color("#ffcf5c"))
	ramp.add_point(0.5, Color("#ff7fb6"))
	ramp.set_color(ramp.get_point_count() - 1, Color("#7fe0c0"))
	burst.color_ramp = ramp
	add_child(burst)
	burst.position = biscuit.position + Vector3(0, 1.2, 0.5) if biscuit != null else Vector3(0, 2, 0.5)
	var life := Timer.new()
	life.wait_time = 1.8
	life.one_shot = true
	life.timeout.connect(burst.queue_free)
	burst.add_child(life)
	life.start()


func _play_place_burst(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var puff := CPUParticles3D.new()
	puff.amount = 12
	puff.lifetime = 0.5
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.emitting = true
	puff.gravity = Vector3(0, -2.0, 0)
	puff.initial_velocity_min = 0.4
	puff.initial_velocity_max = 1.4
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	puff.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#fff1c7")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material_override = material
	add_child(puff)
	puff.position = Vector3(points[points.size() - 1].x, points[points.size() - 1].y, 0.4)
	var life := Timer.new()
	life.wait_time = 0.9
	life.one_shot = true
	life.timeout.connect(puff.queue_free)
	puff.add_child(life)
	life.start()


# --------------------------------------------------------------------------
# tests and debug
# --------------------------------------------------------------------------

func apply_solution() -> void:
	var raw: Array = level.get("solution", [])
	var points := PackedVector2Array()
	for value in raw:
		var pair: Array = value
		points.append(Vector2(float(pair[0]), float(pair[1])))
	add_stroke(points)


func debug_state() -> Dictionary:
	return {
		"mode": mode,
		"phase": phase,
		"used": used,
		"budget": budget,
		"stars": stars_for(used),
		"elapsed": elapsed,
		"duration": duration,
		"hazards": hazards.size(),
		"bees": swarm.bees.size() if swarm != null else 0,
		"door": door_status(),
		"secure_strokes": secure_stroke_count(),
		"loose_strokes": loose_stroke_count(),
		"shoved": shoved_count,
	}


# --------------------------------------------------------------------------
# doorway structure
# --------------------------------------------------------------------------

func door_snap_points() -> PackedVector2Array:
	return door_sockets


func secure_stroke_count() -> int:
	var total := 0
	for stroke in strokes:
		var body: Variant = stroke["body"]
		if body != null and bool(body.is_secure()):
			total += 1
	return total


func loose_stroke_count() -> int:
	var total := 0
	for stroke in strokes:
		var body: Variant = stroke["body"]
		if body != null and not bool(body.is_secure()):
			total += 1
	return total


## "wedged" means a secure doodle crosses the middle of the doorway.
## "loose" means a doodle is sitting in the doorway but nothing holds it.
func door_status() -> String:
	if mode != "bee":
		return ""
	if _plug_body != null and is_instance_valid(_plug_body):
		return "wedged" if bool(_plug_body.is_secure()) else "loose"
	return "open"


## A doodle over the doorway fills the whole round opening with a plug. The
## structural verdict stays on the stroke: if its ends bite the frame, the plug
## is wedged; if it is floating, the plug shakes loose and the bees pour in.
func _attach_plug(body: Variant) -> void:
	_plug_body = body
	var colour := Save.pen_colour()
	var disc := MeshInstance3D.new()
	disc.name = "DoodlePlug"
	var mesh := CylinderMesh.new()
	mesh.top_radius = door_radius + 0.24
	mesh.bottom_radius = door_radius + 0.24
	mesh.height = 0.1
	mesh.radial_segments = 24
	disc.mesh = mesh
	disc.position = Vector3(door_center.x, door_center.y, -0.12)
	disc.rotation.x = PI * 0.5
	disc.material_override = Decor.mat(colour, 0.62, 0.0, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(disc)
	var rim := Decor.add_mesh(body, _torus(door_radius + 0.12, door_radius + 0.2),
		Vector3(door_center.x, door_center.y, -0.06),
		Decor.mat(colour.darkened(0.22), 0.7, 0.0, 0.0), Vector3.ONE,
		Vector3(PI * 0.5, 0, 0), "PlugRim")
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = door_radius + 0.35
	cylinder.height = 0.5
	shape.shape = cylinder
	shape.position = Vector3(door_center.x, door_center.y, -0.05)
	shape.rotation.x = PI * 0.5
	body.add_child(shape)


func _snap_to_door(points: PackedVector2Array) -> PackedVector2Array:
	if door_sockets.is_empty() or points.size() < 2:
		return points
	var first := _nearest_socket(points[0])
	if first.x > -900.0:
		points[0] = first
	var last := _nearest_socket(points[points.size() - 1])
	if last.x > -900.0:
		points[points.size() - 1] = last
	return points


func _nearest_socket(point: Vector2) -> Vector2:
	var best := Vector2(-9999, -9999)
	var best_distance := 0.75
	for socket in door_sockets:
		var distance := point.distance_to(socket)
		if distance < best_distance:
			best_distance = distance
			best = socket
	return best


func _evaluate_strokes() -> void:
	if mode != "bee":
		return
	for i in range(strokes.size()):
		var stroke: Dictionary = strokes[i]
		var body: Variant = stroke["body"]
		if body == null:
			continue
		var points: PackedVector2Array = stroke["points"]
		var catches := _rim_catches(points)
		var joints := 0
		for j in range(strokes.size()):
			if i == j:
				continue
			var other: PackedVector2Array = strokes[j]["points"]
			if _strokes_touch(points, other):
				joints += 1
		var grounded := _touches_ground(points)
		body.set_secure(catches >= 2 or (catches >= 1 and (joints >= 1 or grounded)))
	_update_door_ring()


## Counts distinct spots on the wooden rim that the doodle actually bites into.
## Two catches is a plug. One catch is a flap that the bees can lever out.
func _rim_catches(points: PackedVector2Array) -> int:
	var hits := {}
	for point in _sample_points(points):
		for socket_index in range(door_sockets.size()):
			if point.distance_to(door_sockets[socket_index]) < 0.14:
				hits[socket_index] = true
	return hits.size()


func _strokes_touch(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var ends := [a[0], a[a.size() - 1]]
	for point in ends:
		for other in b:
			if (point as Vector2).distance_to(other) < 0.42:
				return true
	return false


func _touches_ground(points: PackedVector2Array) -> bool:
	for point in points:
		if point.y <= GROUND_TOP + 0.16:
			return true
	return false


func _stroke_covers_door(points: PackedVector2Array) -> bool:
	for point in _sample_points(points):
		if Vector2(point.x - door_center.x, point.y - door_center.y).length() < door_radius * 0.5:
			return true
	return false


func _stroke_near_door(points: PackedVector2Array) -> bool:
	for point in _sample_points(points, 0.18):
		if Vector2(point.x - door_center.x, point.y - door_center.y).length() < door_radius + 1.0:
			return true
	return false


func _sample_points(points: PackedVector2Array, step := 0.12) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / step)))
		for s in range(steps):
			out.append(a.lerp(b, float(s) / float(steps)))
	out.append(points[points.size() - 1])
	return out


func _update_door_ring() -> void:
	if _door_ring_mat == null:
		return
	var colour := Color("#ffcf5c")
	match door_status():
		"wedged":
			colour = Color("#7ed07a")
		"loose":
			colour = Color("#e05d55")
	_door_ring_mat.albedo_color = colour
	_door_ring_mat.emission = colour


func _on_stroke_shoved(body) -> void:
	shoved_count += 1
	if body is Node3D:
		feedback.emit("shoved", (body as Node3D).global_position)
	else:
		feedback.emit("shoved", door_center)
	_update_door_ring()


func set_phase_for_test(value: String) -> void:
	phase = value
