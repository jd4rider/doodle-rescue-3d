extends Node
## Campaign catalogue loader and validator.
##
## Levels are data: `Data/levels.json` holds the worlds and every level's
## terrain, anchors, budget, objective and one stored solution stroke. The
## headless test suite builds each level and runs that stroke through the real
## physics before a level is considered shippable.

const DATA_PATH := "res://Data/levels.json"

const MODE_NAMES := {
	"bee": "Bee Defence",
	"bridge": "Bridge Build",
	"dodge": "Danger Dodge",
	"contraption": "Contraption",
}

var worlds: Array = []
var levels: Array = []
var _by_id: Dictionary = {}


func _ready() -> void:
	load_catalog()


func load_catalog() -> void:
	worlds = []
	levels = []
	_by_id = {}
	if not FileAccess.file_exists(DATA_PATH):
		push_error("campaign file missing: %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("campaign file is not a JSON object")
		return
	worlds = (parsed as Dictionary).get("worlds", [])
	levels = (parsed as Dictionary).get("levels", [])
	for level in levels:
		_by_id[int(level.get("id", -1))] = level


func level_count() -> int:
	return levels.size()


func get_level(id: int) -> Dictionary:
	return _by_id.get(id, {})


func get_world(index: int) -> Dictionary:
	if index < 0 or index >= worlds.size():
		return {}
	return worlds[index]


func world_of(id: int) -> int:
	return int(get_level(id).get("world", 0))


func levels_in_world(index: int) -> Array:
	var out: Array = []
	for level in levels:
		if int(level.get("world", -1)) == index:
			out.append(level)
	return out


func first_level_of_world(index: int) -> int:
	var list := levels_in_world(index)
	return int(list[0]["id"]) if not list.is_empty() else 1


func mode_name(mode: String) -> String:
	return MODE_NAMES.get(mode, mode.capitalize())


# --------------------------------------------------------------------------
# validation — used by the tests and by the level editor's sanity check
# --------------------------------------------------------------------------

func validate() -> Dictionary:
	var problems: Array = []
	if worlds.size() < 1:
		problems.append("no worlds")
	if levels.is_empty():
		problems.append("no levels")
	var seen := {}
	var ids := {}
	for level in levels:
		var id := int(level.get("id", 0))
		var name := String(level.get("title", "level %d" % id))
		if id <= 0:
			problems.append("%s has no positive id" % name)
		if ids.has(id):
			problems.append("duplicate id %d" % id)
		ids[id] = true
		if seen.has(name):
			problems.append("duplicate title %s" % name)
		seen[name] = true
		var mode := String(level.get("mode", ""))
		if not MODE_NAMES.has(mode):
			problems.append("%s has unknown mode %s" % [name, mode])
		for key in ["objective", "hint", "budget", "duration", "solution"]:
			if not level.has(key):
				problems.append("%s is missing %s" % [name, key])
		if float(level.get("budget", 0.0)) <= 0.0:
			problems.append("%s has no drawing budget" % name)
		var solution: Array = level.get("solution", [])
		if solution.size() < 2:
			problems.append("%s has no solution stroke" % name)
		elif _stroke_length(solution) > float(level.get("budget", 0.0)):
			problems.append("%s solution is longer than its budget" % name)
		var world := int(level.get("world", -1))
		if world < 0 or world >= worlds.size():
			problems.append("%s has an invalid world" % name)
		var bounds: Array = level.get("bounds", [-7.5, 0.0, 7.5, 8.0])
		if bounds.size() != 4:
			problems.append("%s bounds must be [x0, y0, x1, y1]" % name)
		elif _stroke_outside(solution, bounds):
			problems.append("%s solution leaves the drawing area" % name)
		if mode == "bridge" and not level.has("bridge"):
			problems.append("%s is a bridge level without bridge data" % name)
		if mode == "bee":
			if not level.has("hives"):
				problems.append("%s is a bee level without hives" % name)
			var door: Dictionary = level.get("door", {})
			if door.is_empty():
				problems.append("%s is a bee level without a round doorway" % name)
			elif float(door.get("radius", 0.0)) < 0.6:
				problems.append("%s has a doorway too small to fill" % name)
		if mode == "dodge" and (level.get("hazards", []) as Array).is_empty():
			problems.append("%s is a dodge level without hazards" % name)
		if mode == "contraption" and not level.has("target"):
			problems.append("%s is a contraption level without a target" % name)
	return {"ok": problems.is_empty(), "problems": problems}


func _stroke_length(stroke: Array) -> float:
	var total := 0.0
	for i in range(1, stroke.size()):
		var a := _point(stroke[i - 1])
		var b := _point(stroke[i])
		total += a.distance_to(b)
	return total


func _point(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _stroke_outside(stroke: Array, bounds: Array) -> bool:
	for value in stroke:
		var p := _point(value)
		if p.x < float(bounds[0]) or p.y < float(bounds[1]) or p.x > float(bounds[2]) or p.y > float(bounds[3]):
			return true
	return false
