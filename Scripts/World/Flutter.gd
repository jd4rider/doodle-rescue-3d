extends Node
## Butterfly wing flap and a slow rising loop.

var left: Node3D
var right: Node3D
var _time := 0.0
var _base := Vector3.ZERO


func _ready() -> void:
	_time = randf() * TAU
	if get_parent() is Node3D:
		_base = (get_parent() as Node3D).position


func _process(delta: float) -> void:
	_time += delta
	if left != null and is_instance_valid(left):
		left.rotation.z = sin(_time * 13.0) * 0.9
	if right != null and is_instance_valid(right):
		right.rotation.z = -sin(_time * 13.0) * 0.9
	var parent := get_parent() as Node3D
	if parent == null:
		return
	parent.position = _base + Vector3(sin(_time * 0.7) * 0.7, sin(_time * 1.3) * 0.25, cos(_time * 0.5) * 0.3)
