extends Node
## Application shell: the sky, the sun, the screen router, a decorative title
## diorama and a thin web debug bridge used by the automated browser smoke test.

const SCREEN_PATHS := {
	"title": "res://Scripts/Screens/TitleScreen.gd",
	"worlds": "res://Scripts/Screens/WorldScreen.gd",
	"levels": "res://Scripts/Screens/LevelScreen.gd",
	"game": "res://Scripts/Screens/GameScreen.gd",
	"settings": "res://Scripts/Screens/SettingsScreen.gd",
	"pens": "res://Scripts/Screens/PenScreen.gd",
	"trophies": "res://Scripts/Screens/TrophyScreen.gd",
}

var world: Node3D
var camera: Camera3D
var screen_root: Control
var runtime: Node3D
var showcase: Node3D
var current_screen: Control
var current_name := ""
var history: Array = []
var toast_label: Label
var toast_panel: PanelContainer
var toast_timer: Timer
var _debug_clock := 0.0
var _debug_available := false
var _showcase_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Router.main = self
	_build_world()
	_build_ui()
	_debug_available = OS.has_feature("web")
	show_screen("title")
	Audio.play_music("meadow")
	apply_quality(String(Save.get_setting("quality", "high")))


func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4fa8e8")
	sky_material.sky_horizon_color = Color("#c8ecff")
	sky_material.sky_curve = 0.16
	sky_material.ground_bottom_color = Color("#7fb98b")
	sky_material.ground_horizon_color = Color("#dff2d8")
	sky_material.sun_angle_max = 26.0
	sky_material.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.06
	environment.fog_enabled = true
	environment.fog_light_color = Color("#d8efff")
	environment.fog_density = 0.0055
	environment.fog_sky_affect = 0.25
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.glow_bloom = 0.08
	environment.ssao_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff2d6")
	key.light_energy = 1.05
	key.rotation_degrees = Vector3(-52, -34, 0)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 48.0
	key.directional_shadow_blend_splits = true
	key.shadow_bias = 0.04
	world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#bcdcff")
	fill.light_energy = 0.34
	fill.rotation_degrees = Vector3(-18, 142, 0)
	world.add_child(fill)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 50.0
	camera.position = Vector3(0, 6.4, 18.5)
	camera.current = true
	# look_at needs the node inside the tree, or the first frame has no aim.
	world.add_child(camera)
	camera.look_at(Vector3(0, 3.4, 0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	screen_root = Control.new()
	screen_root.name = "Screens"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen_root)

	toast_panel = Ui.panel(Color("#2f2a24"), 18, Color("#2f2a24"), 14, 8)
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_left = -170
	toast_panel.offset_right = 170
	toast_panel.offset_top = -190
	toast_panel.offset_bottom = -128
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast_panel)
	toast_label = Ui.label("", 14, Ui.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 3.2
	toast_timer.timeout.connect(func() -> void: toast_panel.visible = false)
	layer.add_child(toast_timer)


func show_toast(text: String) -> void:
	if toast_panel == null:
		return
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	create_tween().tween_property(toast_panel, "modulate:a", 1.0, 0.18)
	toast_timer.start()


func show_screen(name: String, payload := {}) -> void:
	var path: String = SCREEN_PATHS.get(name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("unknown screen %s" % name)
		return
	clear_runtime()
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null
	var script: GDScript = load(path)
	var screen := script.new() as Control
	if screen == null:
		return
	if screen.has_method("configure"):
		screen.call("configure", payload)
	screen_root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_screen = screen
	current_name = name
	if name == "title":
		show_showcase(true)
	else:
		show_showcase(false)
	Audio.play_music("meadow" if name != "game" else "focus")


func navigate(name: String, payload := {}) -> void:
	history.append({"screen": current_name, "payload": {}})
	if history.size() > 24:
		history.pop_front()
	show_screen(name, payload)


func go_back() -> void:
	if history.is_empty():
		show_screen("title")
		return
	var entry: Dictionary = history.pop_back()
	show_screen(String(entry["screen"]), entry.get("payload", {}))


func show_showcase(value: bool) -> void:
	if value:
		if showcase != null and is_instance_valid(showcase):
			return
		camera.fov = 50.0
		camera.position = Vector3(0, 6.4, 18.5)
		camera.look_at(Vector3(0, 3.4, 0))
		showcase = Node3D.new()
		showcase.name = "Showcase"
		world.add_child(showcase)
		var decor: GDScript = load("res://Scripts/World/Decor.gd")
		decor.build_showcase(showcase)
		_showcase_time = 0.0
	elif showcase != null and is_instance_valid(showcase):
		showcase.queue_free()
		showcase = null


func apply_quality(level: String) -> void:
	var world_env := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		world_env.environment.glow_enabled = level != "low"
		world_env.environment.fog_enabled = level != "low"
	var viewport := get_viewport()
	if viewport != null:
		viewport.msaa_3d = Viewport.MSAA_DISABLED if level == "low" else Viewport.MSAA_2X
	for child in world.get_children():
		if child is DirectionalLight3D and child.shadow_enabled:
			(child as DirectionalLight3D).shadow_enabled = level != "low"


func attach_runtime(node: Node3D) -> void:
	clear_runtime()
	runtime = node
	world.add_child(node)


func clear_runtime() -> void:
	if runtime != null and is_instance_valid(runtime):
		runtime.queue_free()
	runtime = null
	Audio.bee(0.0)


func _process(delta: float) -> void:
	if showcase != null and is_instance_valid(showcase):
		_showcase_time += delta
		if not bool(Save.get_setting("reduced_motion", false)):
			camera.position = Vector3(sin(_showcase_time * 0.16) * 1.1, 6.1 + sin(_showcase_time * 0.3) * 0.16, 18.5)
			camera.look_at(Vector3(0, 3.35, 0))
	if not _debug_available:
		return
	_debug_clock += delta
	if _debug_clock < 0.2:
		return
	_debug_clock = 0.0
	_publish_state()
	_poll_command()


func _unhandled_input(event: InputEvent) -> void:
	# The first real gesture is what lets browsers start audio.
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		Audio.kick()


# --------------------------------------------------------------------------
# web debug bridge
# --------------------------------------------------------------------------

func _publish_state() -> void:
	var state := {
		"screen": current_name,
		"level": 0,
		"phase": "",
		"fps": Engine.get_frames_per_second(),
		"stars": Save.total_stars(),
		"canvas": {
			"w": int(get_viewport().get_visible_rect().size.x),
			"h": int(get_viewport().get_visible_rect().size.y),
		},
	}
	if current_screen != null and current_screen.has_method("debug_state"):
		state.merge(current_screen.call("debug_state"), true)
	var text := JSON.stringify(state)
	JavaScriptBridge.eval(
		"window.__doodleState = JSON.parse(atob('%s'))" % Marshalls.utf8_to_base64(text), true)


func _poll_command() -> void:
	var raw: Variant = JavaScriptBridge.eval("window.__doodleCommand || ''", true)
	if raw == null:
		return
	var command := String(raw)
	if command.is_empty():
		return
	JavaScriptBridge.eval("window.__doodleCommand = ''", true)
	_run_command(command)


func _run_command(command: String) -> void:
	var parts := command.split(":")
	match parts[0]:
		"screen":
			if parts.size() > 1:
				show_screen(parts[1])
		"start":
			if parts.size() > 2 and parts[1] == "campaign":
				show_screen("game", {"level": Levels.get_level(int(parts[2])), "mode": "campaign"})
		"inject":
			if current_screen != null and current_screen.has_method("debug_inject"):
				current_screen.call("debug_inject")
		"play":
			if current_screen != null and current_screen.has_method("_play"):
				current_screen.call("_play")
		"reset":
			if current_screen != null and current_screen.has_method("_reset"):
				current_screen.call("_reset")
		"next":
			if current_screen != null and current_screen.has_method("_next"):
				current_screen.call("_next")
		"back":
			go_back()
