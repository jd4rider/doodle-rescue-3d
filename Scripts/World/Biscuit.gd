class_name Biscuit
extends Node3D
## Biscuit, the toy puppy. Built from rounded primitives so every reaction —
## blinking, breathing, nervous trembling, a happy hop — is animation on the
## same model that ships in the web build.

const FUR := Color("#f0b878")
const FUR_DARK := Color("#c98b53")
const CREAM := Color("#fff4e2")
const INK := Color("#33251b")
const PINK := Color("#f39aa4")
const COLLAR := Color("#e05d55")
const GOLD := Color("#ffcf5c")

var mood := "idle"
var walking := false
var look_target := Vector3.ZERO
var has_look := false

var _rig: Node3D
var _body: MeshInstance3D
var _belly: MeshInstance3D
var _head: Node3D
var _mouth: MeshInstance3D
var _tongue: MeshInstance3D
var _ears: Array = []
var _eyes: Array = []
var _legs: Array = []
var _tail: Node3D
var _tail_parts: Array = []
var _blink_in := 2.4
var _blink_left := 0.0
var _time := 0.0
var _home_y := 0.0


func _ready() -> void:
	_build()
	set_process(true)


func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	# legs go under the body; pivots at the hip so they can swing
	for i in range(4):
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.31, 0.52, 0.3 if front else -0.28)
		_rig.add_child(pivot)
		Decor.capsule(pivot, Vector3(0, -0.24, 0), 0.115, 0.46, FUR, Vector3.ZERO, "Leg")
		Decor.sphere(pivot, Vector3(0, -0.44, 0.03), 0.115, CREAM, Vector3(1, 0.55, 1.2), 0.8, "Paw")
		_legs.append(pivot)

	_body = Decor.sphere(_rig, Vector3(0, 0.8, -0.02), 0.52, FUR, Vector3(1.32, 1.08, 1.12), 0.72, "Body")
	_belly = Decor.sphere(_rig, Vector3(0, 0.73, 0.26), 0.46, CREAM, Vector3(1.0, 0.98, 0.72), 0.78, "Belly")

	# tail: a pivot with three decreasing puffs
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.0, -0.55)
	_rig.add_child(_tail)
	for i in range(3):
		var puff := Decor.sphere(_tail, Vector3(0, 0.10 + i * 0.16, -0.15 - i * 0.1),
			0.11 - i * 0.02, FUR_DARK, Vector3(1, 1, 1), 0.8, "Tail")
		_tail_parts.append(puff)

	# collar + tag
	var collar := TorusMesh.new()
	collar.inner_radius = 0.27
	collar.outer_radius = 0.35
	var collar_node := Decor.add_mesh(_rig, collar, Vector3(0, 1.15, 0.02),
		Decor.mat(COLLAR, 0.5), Vector3.ONE, Vector3(PI * 0.5, 0, 0), "Collar")
	collar_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Decor.cylinder(_rig, Vector3(0, 1.03, 0.39), 0.075, 0.035, GOLD,
		Vector3(1, 1, 1), 0.35, "Tag").rotation.x = PI * 0.5

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.44, 0.12)
	_rig.add_child(_head)
	var skull := Decor.sphere(_head, Vector3(0, 0.06, 0), 0.5, FUR, Vector3(1.12, 1.04, 1.0), 0.72, "Skull")
	skull.name = "Skull"
	Decor.sphere(_head, Vector3(0, -0.06, 0.4), 0.28, CREAM, Vector3(1.14, 0.82, 0.9), 0.78, "Muzzle")
	Decor.sphere(_head, Vector3(0, 0.03, 0.65), 0.078, INK, Vector3(1.2, 0.85, 0.9), 0.55, "Nose")
	_mouth = Decor.sphere(_head, Vector3(0, -0.13, 0.61), 0.045, INK, Vector3(1.5, 0.7, 0.4), 0.6, "Mouth")
	_tongue = Decor.sphere(_head, Vector3(0, -0.18, 0.63), 0.062, PINK, Vector3(1.25, 0.85, 0.45), 0.65, "Tongue")
	_tongue.visible = false

	# cheeks
	for side in [-1.0, 1.0]:
		Decor.sphere(_head, Vector3(side * 0.33, -0.04, 0.34), 0.085, PINK,
			Vector3(1.1, 0.7, 0.4), 0.9, "Cheek").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# eyes: a white, a pupil and a highlight, grouped so blinking scales all three
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.2, 0.12, 0.42)
		_head.add_child(eye)
		Decor.sphere(eye, Vector3.ZERO, 0.135, Color("#ffffff"), Vector3(1.0, 1.1, 0.5), 0.35, "White")
		Decor.sphere(eye, Vector3(0, -0.005, 0.07), 0.078, INK, Vector3(1, 1.05, 0.5), 0.45, "Pupil")
		Decor.sphere(eye, Vector3(0.026, 0.035, 0.115), 0.027, Color("#ffffff"),
			Vector3(1, 1, 0.5), 0.2, "Glint").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eyes.append(eye)

	# floppy ears
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.4, 0.28, 0.02)
		pivot.rotation.z = side * 0.4
		_head.add_child(pivot)
		Decor.sphere(pivot, Vector3(0, -0.2, 0), 0.26, FUR_DARK, Vector3(0.52, 1.0, 0.4), 0.78, "Ear")
		Decor.sphere(pivot, Vector3(0, -0.22, 0.08), 0.15, PINK, Vector3(0.5, 0.95, 0.25), 0.85, "EarInner")
		_ears.append({"node": pivot, "side": side})

	_home_y = _rig.position.y


func set_mood(value: String) -> void:
	mood = value


func celebrate() -> void:
	mood = "happy"
	_time = 0.0


func look_at_point(point: Vector3) -> void:
	look_target = point
	has_look = true


func clear_look() -> void:
	has_look = false


func _process(delta: float) -> void:
	_time += delta
	var reduced := false
	if has_node("/root/Save"):
		reduced = bool(get_node("/root/Save").get_setting("reduced_motion", false))
	var motion := 0.25 if reduced else 1.0

	# blinking
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_left <= 0.0:
		_blink_left = 0.13
		_blink_in = randf_range(2.4, 5.4)
	var blink_scale := 0.12 if _blink_left > 0.0 else 1.0
	if _blink_left > 0.0:
		_blink_left -= delta
	for eye in _eyes:
		(eye as Node3D).scale = Vector3(1.0, blink_scale, 1.0)

	var breathe := sin(_time * 2.15) * 0.016 * motion
	var bob := 0.0
	var squash := Vector3.ONE
	var ear_target := 0.4
	var tail_speed := 4.0
	var tail_amp := 0.28
	var eye_bonus := 1.0
	_tongue.visible = false
	_mouth.scale = Vector3(1.5, 0.7, 0.4)

	match mood:
		"nervous":
			ear_target = 0.95
			eye_bonus = 1.14
			bob = sin(_time * 26.0) * 0.01 * motion
			tail_speed = 2.0
			tail_amp = 0.1
		"scared":
			ear_target = 1.05
			eye_bonus = 1.2
			bob = -0.09 + sin(_time * 18.0) * 0.008 * motion
			tail_speed = 1.5
			tail_amp = 0.06
			squash = Vector3(1.06, 0.94, 1.06)
		"happy":
			ear_target = 0.12
			tail_speed = 13.0
			tail_amp = 0.55
			bob = absf(sin(_time * 6.5)) * 0.17 * motion
			squash = Vector3(1.0 - absf(sin(_time * 6.5)) * 0.05, 1.0 + absf(sin(_time * 6.5)) * 0.06, 1.0)
			_tongue.visible = true
			_mouth.scale = Vector3(1.3, 1.0, 0.4)
		"curious":
			ear_target = 0.18
			tail_speed = 6.0
			tail_amp = 0.3
			eye_bonus = 1.1
		_:
			bob = sin(_time * 2.15) * 0.02 * motion

	_rig.position.y = lerpf(_rig.position.y, _home_y + bob, 0.18)
	_rig.scale = _rig.scale.lerp(squash, 0.14)
	_body.scale = _body.scale.lerp(Vector3(1.32, 1.08 + breathe, 1.12), 0.12)
	_belly.scale = _belly.scale.lerp(Vector3(1.0, 0.98 + breathe, 0.72), 0.12)

	for entry in _ears:
		var node: Node3D = entry["node"]
		var side := float(entry["side"])
		var target := side * ear_target
		node.rotation.z = lerpf(node.rotation.z, target, 0.12)
		node.rotation.x = lerpf(node.rotation.x, -0.1 if mood == "happy" else 0.0, 0.1)

	var wag := sin(_time * tail_speed) * tail_amp * motion
	_tail.rotation.y = wag
	_tail.rotation.x = -0.25 + sin(_time * tail_speed * 0.5) * 0.1 * motion

	var leg_swing := sin(_time * 8.0) * 0.55 if walking else 0.0
	for i in range(_legs.size()):
		var leg: Node3D = _legs[i]
		var phase := 1.0 if i == 0 or i == 3 else -1.0
		leg.rotation.x = lerpf(leg.rotation.x, leg_swing * phase, 0.2)

	var eye_target := eye_bonus * (1.1 if mood == "happy" else 1.0)
	for eye in _eyes:
		var e := eye as Node3D
		e.scale = Vector3(1.0, blink_scale * eye_target, 1.0)

	if has_look:
		var local := to_local(look_target) - _head.position
		var yaw := atan2(local.x, local.z)
		yaw = clampf(yaw, -0.75, 0.75)
		_head.rotation.y = lerpf(_head.rotation.y, yaw, 0.1)
		_head.rotation.x = lerpf(_head.rotation.x, clampf(-local.y * 0.03, -0.15, 0.2), 0.1)
	else:
		_head.rotation.y = lerpf(_head.rotation.y, sin(_time * 0.6) * 0.12, 0.04)
		_head.rotation.x = lerpf(_head.rotation.x, 0.0, 0.05)
