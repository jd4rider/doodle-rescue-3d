class_name BeeSwarm
extends Node3D
## A pooled, steering bee swarm. Bees are CharacterBody3D so they collide with
## the drawn beams and slide around them, but they are not rigid bodies: a
## dozen insects should never cost a dozen full physics simulations.

signal stung
signal bee_reached
signal bonked(position: Vector3)

const SPEED := 2.55
const ACCEL := 9.0
const HONEY := Color("#ffcf4a")
const STRIPE := Color("#3a2a12")

var bees: Array = []
var active := false
var finished := false
var fleeing := false
var biscuit: Node3D
var _hives: Array = []
var _time := 0.0
var _nearest := 999.0
var entry := Vector3.ZERO
var entry_radius := 0.0
var has_entry := false


func setup(hives: Array, target: Node3D, count: int, doorway := Vector3.ZERO, doorway_radius := 0.0) -> void:
	biscuit = target
	_hives = hives
	entry = doorway
	entry_radius = doorway_radius
	has_entry = doorway_radius > 0.0
	for i in range(count):
		_make_bee(i, count)


func _make_bee(index: int, total: int) -> void:
	var hive: Vector3 = Vector3.ZERO
	if not _hives.is_empty():
		hive = _hives[index % _hives.size()]
	var body := CharacterBody3D.new()
	body.name = "Bee%d" % index
	body.collision_layer = 2
	body.collision_mask = 1 | 8
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.position = hive + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.1, 0.1))
	add_child(body)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	shape.shape = sphere
	body.add_child(shape)

	var visual := Node3D.new()
	visual.name = "Visual"
	body.add_child(visual)
	var body_mesh := Decor.sphere(visual, Vector3(0, 0, 0), 0.115, HONEY, Vector3(1.0, 0.9, 1.55), 0.5, "Body")
	for j in range(2):
		Decor.sphere(visual, Vector3(0, 0.005, -0.045 + j * 0.09), 0.105, STRIPE,
			Vector3(1.02, 0.92, 0.22), 0.6, "Stripe")
	Decor.sphere(visual, Vector3(0, 0.01, 0.15), 0.08, Color("#33251b"), Vector3(1, 0.92, 0.85), 0.55, "Head")
	# antennae
	for side in [-1.0, 1.0]:
		Decor.box(visual, Vector3(side * 0.035, 0.09, 0.2), Vector3(0.012, 0.01, 0.11),
			STRIPE, Vector3(0.5, 0, side * 0.5), 0.8, "Antenna")
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var wings: Array = []
	for side in [-1.0, 1.0]:
		var wing := Decor.sphere(visual, Vector3(side * 0.1, 0.075, -0.01), 0.105,
			Color(0.92, 0.98, 1.0, 0.72), Vector3(0.65, 0.12, 1.5), 0.2, "Wing")
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := wing.material_override as StandardMaterial3D
		if material != null:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.emission_enabled = true
			material.emission = Color(0.85, 0.95, 1.0)
			material.emission_energy_multiplier = 0.15
		wings.append(wing)

	bees.append({
		"body": body,
		"visual": visual,
		"wings": wings,
		"hive": hive,
		"delay": 0.5 + float(index) * 0.11,
		"phase": randf() * TAU,
		"speed": SPEED * randf_range(0.88, 1.12),
		"active": false,
		"done": false,
		"bump": 0.0,
	})


func start() -> void:
	active = true


func flee() -> void:
	# A happy ending: the bees give up and drift back over the hedge.
	fleeing = true
	finished = true
	if has_node("/root/Audio"):
		get_node("/root/Audio").bee(0.0)


func nearest_distance() -> float:
	return _nearest


func _physics_process(delta: float) -> void:
	_time += delta
	if biscuit == null or not is_instance_valid(biscuit):
		return
	var target := biscuit.global_position + Vector3(0, 0.85, 0)
	_nearest = 999.0
	for i in range(bees.size()):
		var bee: Dictionary = bees[i]
		if bool(bee["done"]):
			continue
		var body: CharacterBody3D = bee["body"]
		var phase := float(bee["phase"])
		var wing_nodes: Array = bee["wings"]
		var flap := sin(_time * 42.0 + phase) * 0.9
		for w in range(wing_nodes.size()):
			var wing: MeshInstance3D = wing_nodes[w]
			wing.rotation.z = (flap if w == 0 else -flap) * 0.7
			wing.rotation.y = (0.25 if w == 0 else -0.25) + sin(_time * 42.0 + phase) * 0.12

		var distance := body.global_position.distance_to(target)
		_nearest = minf(_nearest, distance)

		if fleeing:
			body.velocity = body.velocity.lerp(Vector3(sin(phase) * 1.2, 2.4, 0.8), 0.04)
			body.move_and_slide()
			var vis: Node3D = bee["visual"]
			vis.rotation.y += delta * 2.0
			continue

		if not active:
			body.global_position = body.global_position.lerp(
				(bee["hive"] as Vector3) + Vector3(sin(_time * 2.0 + phase) * 0.18,
					cos(_time * 2.4 + phase) * 0.14, 0), 0.05)
			continue

		if not bool(bee["active"]):
			if _time < float(bee["delay"]):
				body.global_position = body.global_position.lerp(
					(bee["hive"] as Vector3) + Vector3(sin(_time * 3.0 + phase) * 0.2,
						cos(_time * 3.4 + phase) * 0.15, 0), 0.12)
				continue
			bee["active"] = true
			bee_reached.emit()

		# Bee levels have one round doorway. Flying at the doorway first makes
		# the swarm read as a siege: they pile up at the hole the player plugs,
		# not at whichever wall happens to be between them and Biscuit.
		var aim := target
		if has_entry:
			var flat := Vector2(entry.x - body.global_position.x, entry.y - body.global_position.y)
			if flat.length() > entry_radius * 0.9:
				aim = entry + Vector3(0, 0, 0.25)
		var to_target := aim - body.global_position
		var desired := to_target.normalized() * float(bee["speed"])
		# a lazy figure-eight so the swarm reads as alive rather than homing missiles
		desired += Vector3(sin(_time * 2.2 + phase), cos(_time * 1.7 + phase * 1.3), sin(_time * 1.3 + phase)) * 0.65
		# keep the flight lane near the drawing plane so beams are effective
		desired.z += -body.global_position.z * 1.8
		# light separation
		for j in range(bees.size()):
			if j == i:
				continue
			var other: Dictionary = bees[j]
			if bool(other["done"]) or not bool(other["active"]):
				continue
			var offset: Vector3 = body.global_position - (other["body"] as Node3D).global_position
			var d := offset.length()
			if d > 0.001 and d < 0.75:
				desired += offset.normalized() * (0.75 - d) * 3.2

		var velocity: Vector3 = body.velocity
		velocity = velocity.lerp(desired, clampf(ACCEL * delta, 0.0, 1.0))
		bee["bump"] = maxf(0.0, float(bee["bump"]) - delta)
		if float(bee["bump"]) > 0.0:
			velocity += Vector3(0, 1.4, 0) * delta * 8.0
		body.velocity = velocity
		body.move_and_slide()
		# The drawing plane is the flight lane. A bee that wanders in depth could
		# slip around a beam it visibly hit, which would make shelters feel broken.
		body.global_position.z = clampf(body.global_position.z, -0.2, 0.2)
		# A bee that hits a genuinely wedged doodle bonks, spins away and gives up.
		# A loose doodle is different: the swarm leans on it instead of giving up,
		# and the pressure builds until the doodle is shoved out of the doorway.
		var hit_secure := false
		var hit_loose := false
		for c in range(body.get_slide_collision_count()):
			var collider: Object = body.get_slide_collision(c).get_collider()
			if collider != null and collider.has_method("is_secure"):
				if bool(collider.call("is_secure")):
					hit_secure = true
				else:
					collider.call("shove", delta * 2.8)
					hit_loose = true
		if hit_loose:
			# Hold the bee against the loose doodle so the push reads on screen.
			body.velocity = body.velocity.lerp(Vector3(0, 0.15, 0), 0.2)
		if hit_secure and float(bee["bump"]) <= 0.0:
			bee["bump"] = 999.0
			bee["done"] = true
			body.collision_mask = 0
			var visual_node: Node3D = bee["visual"]
			var spin := create_tween()
			spin.tween_property(visual_node, "scale", Vector3(1.5, 1.5, 1.5), 0.08)
			spin.tween_property(visual_node, "scale", Vector3.ZERO, 0.24)
			bonked.emit(body.global_position)
			bee_reached.emit()
			continue
		# never dive through the island
		if body.global_position.y < 0.45:
			body.global_position.y = 0.45
			body.velocity.y = maxf(0.4, body.velocity.y)

		if velocity.length() > 0.1:
			var visual: Node3D = bee["visual"]
			visual.rotation.y = lerpf(visual.rotation.y, atan2(velocity.x, velocity.z), 0.25)
			visual.rotation.x = lerpf(visual.rotation.x, clampf(-velocity.y * 0.25, -0.4, 0.4), 0.2)

		if distance < 0.92 and not finished:
			finished = true
			bee["done"] = true
			stung.emit()
			return

	# the hum rises as the nearest bee gets close
	if has_node("/root/Audio"):
		get_node("/root/Audio").bee(clampf(1.0 - (_nearest - 0.8) / 6.0, 0.0, 1.0))


func stop() -> void:
	active = false
	finished = true
	if has_node("/root/Audio"):
		get_node("/root/Audio").bee(0.0)
