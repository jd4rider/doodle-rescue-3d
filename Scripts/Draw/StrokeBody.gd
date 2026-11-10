extends StaticBody3D
## A finished doodle.
##
## It behaves like a solid beam while it is wedged into the doorway. If it is
## only floating in the opening, bees that bump into it add pressure until the
## doodle shakes loose and is shoved out of the way. This is what turns a
## scribble into a structural choice: a roof that is not caught on the rim can
## be moved by the swarm.

signal shoved

const SHOVE_AT := 0.85

var secure := true
var _push := 0.0
var _shake := 0.0
var _shoving := false
var _base := Vector3.ZERO


func _ready() -> void:
	add_to_group("drawn_beams")
	_base = position
	set_process(false)


func is_secure() -> bool:
	return secure


func set_secure(value: bool) -> void:
	secure = value
	if secure:
		_push = 0.0
		_shake = 0.0
		if not _shoving:
			position = _base
			set_process(false)


## Called by every bee that is pressed against this doodle. `amount` is in
## "bee-seconds": one bee pushing for about a third of a second is enough once
## the pressure crosses SHOVE_AT.
func shove(amount := 0.05) -> void:
	if secure or _shoving:
		return
	_push += amount
	_shake = minf(0.32, _shake + amount * 1.7)
	set_process(true)
	if _push >= SHOVE_AT:
		_release()


func _process(delta: float) -> void:
	if _shoving or _shake <= 0.0:
		set_process(false)
		return
	_shake = maxf(0.0, _shake - delta * 0.9)
	var wobble := sin(Time.get_ticks_msec() * 0.08) * 0.045 * (_shake / 0.32)
	position = _base + Vector3(wobble, absf(wobble) * 0.35, 0)
	if _shake <= 0.0 and not _shoving:
		position = _base
		set_process(false)


func _release() -> void:
	_shoving = true
	set_process(false)
	collision_layer = 0
	var target := _base + Vector3(randf_range(-0.18, 0.18), -1.0, -0.9)
	var tween := create_tween()
	tween.tween_property(self, "position", target, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shoved.emit()
