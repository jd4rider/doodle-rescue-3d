extends Node
## Gentle idle movement for trees, hives and floating rocks. Seeded per prop so
## the whole scene never pulses in sync.

var amplitude := 0.02
var speed := 1.0
var phase := 0.0
var vertical := false
var _time := 0.0
var _rest := Vector3.ZERO


func _ready() -> void:
	_rest = (get_parent() as Node3D).position if get_parent() is Node3D else Vector3.ZERO
	set_process(true)


func _process(delta: float) -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	_time += delta
	var t := _time * speed + phase
	var reduced := false
	if has_node("/root/Save"):
		reduced = bool(get_node("/root/Save").get_setting("reduced_motion", false))
	var amount := 0.15 if reduced else 1.0
	if vertical:
		parent.position = _rest + Vector3(0, sin(t) * amplitude * amount, 0)
	else:
		parent.rotation.z = sin(t) * amplitude * amount
		parent.rotation.x = cos(t * 0.8) * amplitude * 0.5 * amount
