extends Node
## Local-first save data for Doodle Rescue 3D.
##
## Written to `user://` after every meaningful event, mirrored to the Little Joy
## Arcade cloud when someone is signed in. Versioned, merged with defaults, and a
## corrupt file is backed up instead of deleted. Nothing here decides whether a
## level is won: LevelRuntime does, from the physics that actually ran.

signal changed
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://doodle_rescue_save.json"
const BACKUP_PATH := "user://doodle_rescue_save.corrupt.json"
const SCHEMA_VERSION := 1

const ACHIEVEMENTS: Array = [
	{"id": "first_rescue", "name": "First Rescue", "hint": "Save Biscuit for the first time.", "stat": "solved", "need": 1},
	{"id": "rescue_5", "name": "Good Neighbour", "hint": "Complete five levels.", "stat": "solved", "need": 5},
	{"id": "rescue_20", "name": "Every Path Home", "hint": "Complete all 20 levels.", "stat": "solved", "need": 20},
	{"id": "three_stars_1", "name": "Clean Line", "hint": "Earn three stars on a level.", "stat": "three_stars", "need": 1},
	{"id": "three_stars_10", "name": "Steady Paw", "hint": "Earn three stars on ten levels.", "stat": "three_stars", "need": 10},
	{"id": "three_stars_all", "name": "Master Doodler", "hint": "Earn three stars on every level.", "stat": "three_stars", "need": 20},
	{"id": "world_1", "name": "Meadow Graduate", "hint": "Clear Sunny Meadows.", "stat": "world_1", "need": 1},
	{"id": "world_2", "name": "Bridge Builder", "hint": "Clear River Run.", "stat": "world_2", "need": 1},
	{"id": "world_3", "name": "Boulder Dodger", "hint": "Clear Rocky Canyon.", "stat": "world_3", "need": 1},
	{"id": "world_4", "name": "Toybox Tinkerer", "hint": "Clear Toybox Town.", "stat": "world_4", "need": 1},
	{"id": "bridge_first", "name": "Across the Gap", "hint": "Guide Biscuit over a drawn bridge.", "stat": "bridges", "need": 1},
	{"id": "dodge_first", "name": "Not Today", "hint": "Survive a rolling hazard.", "stat": "dodges", "need": 1},
	{"id": "contraption_first", "name": "Rube Would Be Proud", "hint": "Finish a contraption level.", "stat": "contraptions", "need": 1},
	{"id": "frugal_5", "name": "Waste Not", "hint": "Use under a third of the pen on five levels.", "stat": "frugal", "need": 5},
	{"id": "no_reset_5", "name": "First Try", "hint": "Finish five levels without resetting.", "stat": "no_reset", "need": 5},
	{"id": "stars_30", "name": "Star Collector", "hint": "Collect 30 stars.", "stat": "stars", "need": 30},
	{"id": "stars_60", "name": "Constellation", "hint": "Collect 60 stars.", "stat": "stars", "need": 60},
	{"id": "pens_all", "name": "Full Tin", "hint": "Unlock every pen.", "stat": "pens", "need": 5},
]

const PENS: Array = [
	{"id": "classic", "name": "Classic Pencil", "stars": 0, "colour": "#ffb545", "tip": "The reliable orange pencil."},
	{"id": "wooden", "name": "Wooden Pencil", "stars": 6, "colour": "#c98b53", "tip": "Warm timber beams."},
	{"id": "neon", "name": "Neon Pen", "stars": 18, "colour": "#4ff0c8", "tip": "Glowing mint strokes."},
	{"id": "candy", "name": "Candy Crayon", "stars": 36, "colour": "#ff7fb6", "tip": "Pink and cream stripes."},
	{"id": "steel", "name": "Steel Pen", "stars": 60, "colour": "#b9c7d8", "tip": "Cool polished metal."},
]


static func _defaults() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"created": int(Time.get_unix_time_from_system()),
		"savedAt": 0,
		"profile": {"name": "Guest"},
		"settings": {
			"music": 0.4,
			"sfx": 0.8,
			"reduced_motion": false,
			"quality": "high",
			"tutorial_done": false,
		},
		"progress": {
			"stars": {},
			"times": {},
			"attempts": {},
			"last_level": 1,
		},
		"stats": {
			"solved": 0,
			"three_stars": 0,
			"no_reset": 0,
			"resets": 0,
			"hints": 0,
			"seconds": 0,
			"frugal": 0,
			"bridges": 0,
			"dodges": 0,
			"contraptions": 0,
			"materials": 0,
			"worlds": {},
		},
		"cosmetics": {"pens": ["classic"], "selected": "classic"},
		"achievements": {},
	}


var data: Dictionary = {}
var _timer: Timer
var _writing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.6
	_timer.timeout.connect(flush)
	add_child(_timer)
	load_data()


func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		queue_save()
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup(text)
		queue_save()
		return
	data = _merge(parsed, _defaults())
	data["schema"] = SCHEMA_VERSION
	changed.emit()


func _backup(text: String) -> void:
	push_warning("Doodle Rescue save could not be parsed; keeping a backup.")
	var file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


func _merge(target: Dictionary, defaults: Dictionary) -> Dictionary:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key]
		elif typeof(target[key]) == TYPE_DICTIONARY and typeof(defaults[key]) == TYPE_DICTIONARY:
			_merge(target[key], defaults[key])
	return target


func queue_save() -> void:
	if _timer and _timer.is_inside_tree():
		_timer.start()


func flush() -> void:
	if _writing:
		return
	_writing = true
	data["savedAt"] = int(Time.get_unix_time_from_system() * 1000.0)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.flush()
		file.close()
		if has_node("/root/Arcade"):
			get_node("/root/Arcade").on_local_save(data)
		if has_node("/root/Audio"):
			get_node("/root/Audio").apply_settings(data["settings"])
	_writing = false


# --------------------------------------------------------------------------
# settings
# --------------------------------------------------------------------------

func get_setting(key: String, fallback: Variant = null) -> Variant:
	if data.has("settings") and data["settings"].has(key):
		return data["settings"][key]
	return fallback


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	queue_save()
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_settings(data["settings"])
	changed.emit()


# --------------------------------------------------------------------------
# progress
# --------------------------------------------------------------------------

func stars_for(id: int) -> int:
	return int((data["progress"]["stars"] as Dictionary).get(str(id), 0))


func is_cleared(id: int) -> bool:
	return stars_for(id) > 0


func best_time(id: int) -> int:
	return int((data["progress"]["times"] as Dictionary).get(str(id), 0))


func is_unlocked(id: int) -> bool:
	if id <= 1:
		return true
	return is_cleared(id - 1)


func total_stars() -> int:
	var total := 0
	for value in (data["progress"]["stars"] as Dictionary).values():
		total += int(value)
	return total


func cleared_count() -> int:
	var total := 0
	for value in (data["progress"]["stars"] as Dictionary).values():
		if int(value) > 0:
			total += 1
	return total


func next_level() -> int:
	var count: int = Levels.level_count()
	for id in range(1, count + 1):
		if not is_cleared(id):
			return id
	return count


func world_stars(world: int) -> int:
	var total := 0
	for level in Levels.levels_in_world(world):
		total += stars_for(int(level["id"]))
	return total


func world_cleared(world: int) -> int:
	var total := 0
	for level in Levels.levels_in_world(world):
		if is_cleared(int(level["id"])):
			total += 1
	return total


func world_unlocked(world: int) -> bool:
	if world <= 0:
		return true
	var previous: Array = Levels.levels_in_world(world - 1)
	if previous.is_empty():
		return true
	# Clearing every level in the previous world opens the next one, and so does
	# enough stars, so a stuck player is never walled in.
	return world_cleared(world - 1) >= previous.size() or total_stars() >= world * 8


## Records one clean completion. `used` is the material actually spent, so the
## efficiency star is earned from the stroke the player drew, not from an answer
## table.
func record_solve(id: int, stars: int, seconds: float, used: float, budget: float,
		mode: String, reset_count: int, hints_used: int) -> Dictionary:
	var key := str(id)
	var previous := stars_for(id)
	if stars > previous:
		(data["progress"]["stars"] as Dictionary)[key] = stars
	var times: Dictionary = data["progress"]["times"]
	if not times.has(key) or int(times[key]) == 0 or seconds < float(times[key]):
		times[key] = int(seconds)
	var stats: Dictionary = data["stats"]
	stats["solved"] = int(stats["solved"]) + 1
	stats["seconds"] = int(stats["seconds"]) + int(seconds)
	stats["materials"] = int(stats["materials"]) + int(used * 10.0)
	stats["hints"] = int(stats["hints"]) + hints_used
	stats["resets"] = int(stats["resets"]) + reset_count
	if stars >= 3:
		stats["three_stars"] = int(stats["three_stars"]) + 1
	if reset_count == 0:
		stats["no_reset"] = int(stats["no_reset"]) + 1
	if used <= budget * 0.34:
		stats["frugal"] = int(stats["frugal"]) + 1
	match mode:
		"bridge":
			stats["bridges"] = int(stats["bridges"]) + 1
		"dodge":
			stats["dodges"] = int(stats["dodges"]) + 1
		"contraption":
			stats["contraptions"] = int(stats["contraptions"]) + 1
	(data["progress"]["attempts"] as Dictionary)[key] = int(
		(data["progress"]["attempts"] as Dictionary).get(key, 0)) + 1
	data["progress"]["last_level"] = mini(Levels.level_count(), id + 1)
	var world := Levels.world_of(id)
	if world_cleared(world) >= Levels.levels_in_world(world).size():
		(stats["worlds"] as Dictionary)[str(world)] = true
	_sync_cosmetics()
	var unlocked := check_achievements()
	queue_save()
	changed.emit()
	return {"unlocked": unlocked, "stars": total_stars()}


func register_reset() -> void:
	data["stats"]["resets"] = int(data["stats"]["resets"]) + 1
	queue_save()


func register_hint() -> void:
	data["stats"]["hints"] = int(data["stats"]["hints"]) + 1
	queue_save()


# --------------------------------------------------------------------------
# cosmetics
# --------------------------------------------------------------------------

func _sync_cosmetics() -> void:
	var owned: Array = data["cosmetics"]["pens"]
	for pen in PENS:
		if total_stars() >= int(pen["stars"]) and not owned.has(String(pen["id"])):
			owned.append(String(pen["id"]))


func pen_available(id: String) -> bool:
	for pen in PENS:
		if String(pen["id"]) == id:
			return total_stars() >= int(pen["stars"])
	return false


func selected_pen() -> String:
	var id := String(data["cosmetics"].get("selected", "classic"))
	return id if pen_available(id) else "classic"


func pen_colour() -> Color:
	for pen in PENS:
		if String(pen["id"]) == selected_pen():
			return Color(String(pen["colour"]))
	return Color("#ffb545")


func choose_pen(id: String) -> bool:
	if not pen_available(id):
		return false
	data["cosmetics"]["selected"] = id
	_sync_cosmetics()
	queue_save()
	changed.emit()
	return true


# --------------------------------------------------------------------------
# achievements
# --------------------------------------------------------------------------

func has_achievement(id: String) -> bool:
	return (data["achievements"] as Dictionary).has(id)


func unlock_achievement(id: String) -> bool:
	if has_achievement(id):
		return false
	(data["achievements"] as Dictionary)[id] = int(Time.get_unix_time_from_system())
	queue_save()
	achievement_unlocked.emit(id)
	if has_node("/root/Arcade"):
		get_node("/root/Arcade").achievement(id)
	return true


func _stat(key: String) -> int:
	var stats: Dictionary = data["stats"]
	match key:
		"stars":
			return total_stars()
		"pens":
			_sync_cosmetics()
			return (data["cosmetics"]["pens"] as Array).size()
		"world_1", "world_2", "world_3", "world_4":
			var index := int(key.split("_")[1])
			return 1 if (stats["worlds"] as Dictionary).has(str(index)) else 0
		_:
			return int(stats.get(key, 0))


func check_achievements() -> Array:
	var unlocked: Array = []
	for entry in ACHIEVEMENTS:
		var id := String(entry["id"])
		if has_achievement(id):
			continue
		if _stat(String(entry["stat"])) >= int(entry["need"]):
			if unlock_achievement(id):
				unlocked.append(id)
	return unlocked


func achievement_count() -> int:
	return (data["achievements"] as Dictionary).size()


func achievement_name(id: String) -> String:
	for entry in ACHIEVEMENTS:
		if String(entry["id"]) == id:
			return String(entry["name"])
	return id


func reset_progress() -> void:
	var settings: Dictionary = data["settings"]
	var profile: Dictionary = data["profile"]
	var created: Variant = data["created"]
	data = _defaults()
	data["settings"] = settings
	data["profile"] = profile
	data["created"] = created
	queue_save()
	changed.emit()
