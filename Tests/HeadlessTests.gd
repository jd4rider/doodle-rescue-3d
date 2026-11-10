extends Node
## Headless validation for the shipped campaign.
##
## Data checks run on every level. Then every level is built in the real 3D
## physics world, its stored solution is drawn through the same BeamBuilder the
## player uses, the simulation is started, and the run must end in "won". A
## level with no working solution fails the build.

var failures: Array = []
var results: Array = []
var _camera: Camera3D
var _only: Array = []
var _last_reason := ""


func _ready() -> void:
	await get_tree().process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int():
			_only.append(int(argument))
	print("Doodle Rescue 3D — headless validation")
	var validation := Levels.validate()
	if validation["ok"]:
		print("  data: %d levels, %d worlds — OK" % [Levels.level_count(), Levels.worlds.size()])
	else:
		_fail("level data: " + "; ".join(validation["problems"]))

	await _check_loose_plug()

	for level in Levels.levels:
		if not _only.is_empty() and not _only.has(int(level.get("id", 0))):
			continue
		await _check_level(level)

	print("")
	for entry in results:
		print("  %-34s %s" % [entry["name"], entry["result"]])
	print("")
	if failures.is_empty():
		print("ALL TESTS PASSED (%d levels simulated)" % results.size())
		get_tree().quit(0)
	else:
		print("FAILURES (%d):" % failures.size())
		for failure in failures:
			print("  - " + failure)
		get_tree().quit(1)


func _on_runtime_lost(message: String) -> void:
	_last_reason = message


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


## The promise of the mechanic, tested directly: a doodle that does not catch
## the rim is pushed out of the doorway by the bees and the level is lost.
func _check_loose_plug() -> void:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 50.0
		add_child(_camera)
	var runtime := LevelRuntime.new()
	add_child(runtime)
	runtime.build(Levels.get_level(1), _camera)
	runtime.add_stroke(PackedVector2Array([Vector2(0.0, 1.35), Vector2(0.45, 1.5)]))
	var loose := runtime.loose_stroke_count()
	runtime.start_simulation()
	var frames := 0
	while frames < 900 and runtime.phase == "sim":
		await get_tree().physics_frame
		frames += 1
	var ok := runtime.phase == "lost" and runtime.shoved_count >= 1 and loose >= 1
	var detail := "PASS — shoved after %d frames" % frames if ok else \
		"FAIL — phase=%s, loose=%d, shoved=%d, frames=%d" % [runtime.phase, loose, runtime.shoved_count, frames]
	results.append({"name": "Mechanic: loose doodle", "result": detail})
	if not ok:
		_fail("a loose doodle was not shoved out of the doorway")
	runtime.queue_free()
	await get_tree().process_frame


func _check_level(level: Dictionary) -> void:
	var name := "L%d %s" % [int(level.get("id", 0)), String(level.get("title", ""))]
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 50.0
		add_child(_camera)
	var runtime := LevelRuntime.new()
	add_child(runtime)
	runtime.build(level, _camera)
	runtime.trace = String(level.get("mode", "")) in ["contraption", "bridge"]
	_last_reason = ""
	runtime.lost.connect(_on_runtime_lost)
	runtime.apply_solution()
	if String(level.get("mode", "")) == "bee" and runtime.loose_stroke_count() > 0:
		_fail("%s: the stored doorway plug is not wedged" % name)
	if runtime.used < 0.2:
		_fail("%s: the stored solution drew nothing" % name)
		runtime.queue_free()
		results.append({"name": name, "result": "NO STROKE"})
		return
	print("  simulating %s (%s)" % [name, String(level.get("mode", "bee"))])
	runtime.start_simulation()
	var limit := int((float(level.get("duration", 10.0)) + 10.0) * 60.0)
	var frames := 0
	while frames < limit and runtime.phase == "sim":
		await get_tree().physics_frame
		frames += 1
	var ok := runtime.phase == "won"
	var detail := "%s in %.1fs (used %.1f/%.1f m, %d frames)%s" % [
		"WON" if ok else "FAILED", runtime.elapsed, runtime.used,
		float(level.get("budget", 10.0)), frames, "" if _last_reason.is_empty() else " — " + _last_reason,
	]
	if not ok:
		_fail("%s: solution did not win (phase=%s, elapsed=%.1f, %s)" % [name, runtime.phase, runtime.elapsed, _last_reason])
	results.append({"name": name, "result": detail})
	runtime.queue_free()
	await get_tree().process_frame
