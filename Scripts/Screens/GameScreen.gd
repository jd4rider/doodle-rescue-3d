extends Control
## Gameplay screen: the HUD, the drawing engine, the physics runtime and the
## result card. Every win comes from LevelRuntime's physics, never from here.

var level: Dictionary = {}
var mode := "bee"
var runtime: LevelRuntime
var draw_engine: DrawEngine
var draw_budget := 10.0
var phase := "draw"
var resets := 0
var hints := 0
var paused := false
var result_open := false

var _pen_bar: ProgressBar
var _pen_label: Label
var _pen_target: Label
var _state_label: Label
var _time_label: Label
var _action: Button
var _undo_button: Button
var _reset_button: Button
var _hint_button: Button
var _title_label: Label
var _objective_label: Label
var _draw_hint: PanelContainer
var _draw_hint_label: Label
var _hint_overlay: PanelContainer
var _pause_layer: Control
var _result_layer: Control
var _result_title: Label
var _result_reason: Label
var _result_stats: Label
var _result_extra: Label
var _result_next: Button
var _result_retry: Button
var _star_row: StarRow
var _first_draw := true


func configure(payload: Dictionary) -> void:
	level = payload.get("level", {})
	mode = String(payload.get("mode", "campaign"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_budget = float(level.get("budget", 10.0))
	_build_hud()
	_build_pause()
	_build_result()
	call_deferred("_build_world")
	Audio.play_music("focus")


func _build_world() -> void:
	if runtime != null and is_instance_valid(runtime):
		runtime = null
	Router.main.clear_runtime()
	if draw_engine != null and is_instance_valid(draw_engine):
		draw_engine.queue_free()
		draw_engine = null
	runtime = LevelRuntime.new()
	runtime.name = "LevelRuntime"
	Router.main.attach_runtime(runtime)
	runtime.build(level, Router.main.camera)
	runtime.won.connect(_on_won)
	runtime.lost.connect(_on_lost)
	runtime.started.connect(_on_started)
	runtime.feedback.connect(_on_feedback)
	draw_engine = DrawEngine.new()
	draw_engine.name = "DrawEngine"
	add_child(draw_engine)
	draw_engine.setup(Router.main.world, Router.main.camera, runtime.draw_bounds,
		draw_budget, Save.pen_colour())
	if runtime.mode == "bee":
		draw_engine.set_snap_targets(runtime.door_snap_points())
		if _draw_hint_label != null:
			_draw_hint_label.text = "✏  Drag across the round doorway"
	draw_engine.stroke_started.connect(_on_draw_started)
	draw_engine.stroke_finished.connect(_on_stroke_finished)
	draw_engine.budget_exhausted.connect(_on_budget_exhausted)
	phase = "draw"
	resets = 0
	_update_hud()
	_draw_hint.visible = true
	_draw_hint.modulate.a = 1.0


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------

func _build_hud() -> void:
	var world_index := int(level.get("world", 0))
	var world: Dictionary = Levels.get_world(world_index)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(shell)

	# top row
	var top := Ui.row(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(top)
	top.add_child(Ui.icon_button("<", func() -> void:
		Audio.ui_back()
		Router.go("levels", {"world": world_index}), 44))
	var title_box := Ui.column(0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(title_box)
	_title_label = Ui.label("LEVEL %d · %s" % [int(level.get("id", 1)), String(world.get("name", "")).to_upper()],
		11, Color("#3f566d"))
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6))
	title_box.add_child(_title_label)
	var level_title := Ui.label(String(level.get("title", "Level")), 19, Ui.INK)
	level_title.add_theme_constant_override("outline_size", 5)
	level_title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.55))
	title_box.add_child(level_title)
	_time_label = Ui.label("0:00", 13, Ui.MUTED)
	title_box.add_child(_time_label)
	top.add_child(Ui.icon_button("II", func() -> void: _pause(), 44))

	# objective card
	var objective := Ui.panel(Color("#fffdf6"), 16, Color("#e8dcc4"), 12, 6)
	objective.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(objective)
	var objective_row := Ui.row(10)
	objective.add_child(objective_row)
	objective_row.add_child(Ui.pill(Levels.mode_name(String(level.get("mode", "bee"))), 10,
		Color(String(world.get("accent", "#7ed07a")))))
	var objective_text := Ui.column(1)
	objective_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_row.add_child(objective_text)
	_objective_label = Ui.label(String(level.get("objective", "")), 12, Ui.INK,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	objective_text.add_child(_objective_label)
	_hint_button = Ui.ghost("Hint", func() -> void: _hint(), 32, 11, Color("#a8792a"))
	_hint_button.custom_minimum_size.x = 66
	_hint_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	objective_row.add_child(_hint_button)

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(flex)

	# floating "drag to draw" hint
	_draw_hint = Ui.panel(Color("#2f2a24"), 16, Color("#2f2a24"), 14, 8)
	_draw_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_draw_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_hint_label = Ui.label("✏  Drag on the scene to draw", 13, Ui.CREAM)
	_draw_hint.add_child(_draw_hint_label)
	shell.add_child(_draw_hint)

	_hint_overlay = Ui.panel(Color("#fff3cf"), 14, Color("#f1d99a"), 12, 4)
	_hint_overlay.visible = false
	_hint_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(_hint_overlay)
	var hint_text := Ui.label("", 12, Color("#6b5220"), HORIZONTAL_ALIGNMENT_CENTER, true)
	hint_text.name = "HintText"
	_hint_overlay.add_child(hint_text)

	# bottom control shelf
	var shelf := Ui.panel(Color("#fffdf6"), 22, Color("#e8dcc4"), 14, 10)
	shelf.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(shelf)
	var controls := Ui.column(7)
	shelf.add_child(controls)
	var pen_row := Ui.row(6)
	controls.add_child(pen_row)
	pen_row.add_child(Ui.caption("Pen"))
	_pen_label = Ui.label("", 12, Ui.INK)
	_pen_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pen_row.add_child(_pen_label)
	_pen_target = Ui.label("", 10, Ui.MUTED)
	pen_row.add_child(_pen_target)

	_pen_bar = ProgressBar.new()
	_pen_bar.custom_minimum_size.y = 9
	_pen_bar.max_value = 100.0
	_pen_bar.value = 100.0
	_pen_bar.show_percentage = false
	_pen_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#eee4d3")
	background.corner_radius_top_left = 99
	background.corner_radius_top_right = 99
	background.corner_radius_bottom_left = 99
	background.corner_radius_bottom_right = 99
	var fill := StyleBoxFlat.new()
	fill.bg_color = Save.pen_colour()
	fill.corner_radius_top_left = 99
	fill.corner_radius_top_right = 99
	fill.corner_radius_bottom_left = 99
	fill.corner_radius_bottom_right = 99
	_pen_bar.add_theme_stylebox_override("background", background)
	_pen_bar.add_theme_stylebox_override("fill", fill)
	controls.add_child(_pen_bar)

	_state_label = Ui.label("", 11, Ui.MUTED)
	controls.add_child(_state_label)

	var actions := Ui.row(8)
	controls.add_child(actions)
	_undo_button = Ui.ghost("Undo", func() -> void: _undo(), 46, 13)
	actions.add_child(_undo_button)
	_reset_button = Ui.ghost("Reset", func() -> void: _reset(), 46, 13)
	actions.add_child(_reset_button)
	_action = Ui.button("Play  ▶", 18, 52, Ui.ORANGE, func() -> void: _play())
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL * 0
	_action.custom_minimum_size.x = 150
	actions.add_child(_action)


func _update_hud() -> void:
	if runtime == null:
		return
	var remaining := runtime.remaining()
	_pen_bar.value = clampf(remaining / maxf(0.01, draw_budget) * 100.0, 0.0, 100.0)
	_pen_label.text = "%.1f m left" % remaining
	_pen_target.text = "3★ under %.1f m" % (draw_budget * 0.66)
	_undo_button.disabled = runtime.strokes.is_empty() or phase != "draw"
	_reset_button.disabled = phase == "won"
	_action.disabled = phase != "draw"
	_hint_button.disabled = phase != "draw"
	match phase:
		"draw":
			_action.text = "Play  ▶"
			if runtime.mode == "bee":
				var door := runtime.door_status()
				if door == "wedged":
					_state_label.text = "Doorway wedged — the doodle will hold."
					_state_label.add_theme_color_override("font_color", Ui.GREEN_DARK)
				elif door == "loose":
					_state_label.text = "Loose doodle — catch the wooden rim on both sides."
					_state_label.add_theme_color_override("font_color", Ui.RED)
				else:
					_state_label.text = "Fill the round doorway — touch the rim on both sides."
					_state_label.add_theme_color_override("font_color", Ui.MUTED)
			else:
				_state_label.text = "Drag to draw · release to build" if _first_draw else \
					"Add another stroke, or press Play."
				_state_label.add_theme_color_override("font_color", Ui.MUTED)
			_time_label.text = "Draw free · simulation starts on Play"
		"sim":
			_action.text = "Biscuit is moving…"
			_state_label.text = "Physics running — hold tight."
			_state_label.add_theme_color_override("font_color", Ui.GREEN_DARK)
		"won":
			_action.text = "Level complete"
		"lost":
			_action.text = "Try again"
	_update_timer()


func _update_timer() -> void:
	if runtime == null or _time_label == null:
		return
	if phase == "sim":
		var left := maxf(0.0, runtime.duration - runtime.elapsed)
		_time_label.text = "%.1fs" % left
		_pen_bar.value = clampf(left / maxf(0.01, runtime.duration) * 100.0, 0.0, 100.0)
		if runtime.mode == "contraption":
			_state_label.text = "Guide the ball to the green pad."
		elif runtime.mode == "bridge":
			_state_label.text = "Biscuit is crossing. Weight bends the deck."
		elif runtime.mode == "dodge":
			_state_label.text = "Keep Biscuit clear of the toys."
		else:
			_state_label.text = "Bees incoming — %d on the wing." % (runtime.swarm.bees.size() if runtime.swarm != null else 0)
	elif phase == "won":
		_time_label.text = "Safe!"
	elif phase == "lost":
		_time_label.text = "Oh no…"


func _process(delta: float) -> void:
	if runtime == null:
		return
	if phase == "sim":
		_update_timer()
	elif phase == "draw":
		_update_hud_light()


func _update_hud_light() -> void:
	if runtime == null or _pen_label == null:
		return
	_pen_label.text = "%.1f m left" % runtime.remaining()
	_pen_bar.value = clampf(runtime.remaining() / maxf(0.01, draw_budget) * 100.0, 0.0, 100.0)


# --------------------------------------------------------------------------
# input and drawing
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if paused or result_open or phase != "draw" or draw_engine == null:
		return
	if draw_engine.handle_event(event):
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if (event as InputEventKey).keycode == KEY_ESCAPE:
		_pause()
	elif (event as InputEventKey).keycode == KEY_SPACE and phase == "draw":
		_play()
	elif (event as InputEventKey).keycode == KEY_Z and phase == "draw":
		_undo()


func _on_draw_started() -> void:
	_first_draw = false
	if _draw_hint != null:
		create_tween().tween_property(_draw_hint, "modulate:a", 0.0, 0.25)


func _on_stroke_finished(points: PackedVector2Array, _length: float) -> void:
	if runtime == null:
		return
	runtime.add_stroke(points)
	draw_engine.set_spent(runtime.used)
	_first_draw = false
	Audio.place()
	_update_hud()


func _on_budget_exhausted() -> void:
	Router.toast("The pencil is empty — press Play or undo a stroke.")
	Audio.ui_back()


func _undo() -> void:
	if phase != "draw" or runtime == null:
		return
	if runtime.remove_last_stroke():
		draw_engine.set_spent(runtime.used)
		Audio.ui_back()
		_update_hud()


func _reset() -> void:
	if phase == "won":
		return
	Audio.ui_back()
	Save.register_reset()
	resets += 1
	_reload()


func _reload() -> void:
	phase = "draw"
	result_open = false
	paused = false
	if _result_layer != null:
		_result_layer.visible = false
	if _pause_layer != null:
		_pause_layer.visible = false
	_build_world()


func _play() -> void:
	if runtime == null or phase != "draw":
		return
	Audio.ui_click()
	runtime.start_simulation()
	if runtime.phase == "draw":
		Router.toast("Draw a line first — even a small one.")
		return
	phase = "sim"
	if _draw_hint != null:
		_draw_hint.visible = false
	_update_hud()
	Arcade.track("level_start", {"level": int(level.get("id", 0)), "mode": mode})


func _on_started() -> void:
	phase = "sim"
	_update_hud()


func _hint() -> void:
	if phase != "draw":
		return
	hints += 1
	Save.register_hint()
	Audio.hint()
	var text := String(level.get("hint", "Draw a line between the danger and Biscuit."))
	var label := _hint_overlay.get_node_or_null("HintText") as Label
	if label != null:
		label.text = text
	_hint_overlay.visible = true
	_hint_overlay.modulate.a = 0.0
	create_tween().tween_property(_hint_overlay, "modulate:a", 1.0, 0.2)
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(_hint_overlay):
			_hint_overlay.visible = false)
	Arcade.track("hint", {"level": int(level.get("id", 0))})


func _on_feedback(kind: String, position: Vector3) -> void:
	match kind:
		"impact":
			Audio.thud()
			_spawn_dust(position)
		"hop":
			Audio.wood_hit()
		"empty":
			Router.toast("Draw a line first — even a small one.")
		"loose_doodle":
			Router.toast("Loose doodle — the bees can shove it. Catch the rim on both sides.")
			Audio.ui_back()
		"shoved":
			Audio.thud()
			Router.toast("The bees shoved that doodle in! Wedge the next one across the rim.")


func _spawn_dust(position: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.amount = 8
	puff.lifetime = 0.55
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.emitting = true
	puff.gravity = Vector3(0, 3.5, 0)
	puff.initial_velocity_min = 0.4
	puff.initial_velocity_max = 1.3
	puff.spread = 60.0
	puff.direction = Vector3(0, 0.4, 0)
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.3
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	puff.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.83, 0.77, 0.66, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	puff.material_override = material
	puff.global_position = position
	Router.main.world.add_child(puff)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(puff):
			puff.queue_free())


# --------------------------------------------------------------------------
# pause
# --------------------------------------------------------------------------

func _build_pause() -> void:
	_pause_layer = Control.new()
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.visible = false
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.14, 0.19, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(centre)
	var card := Ui.panel(Color("#fffdf6"), 26, Color("#e8dcc4"), 20, 16)
	card.custom_minimum_size.x = 300
	centre.add_child(card)
	var column := Ui.column(10)
	card.add_child(column)
	column.add_child(Ui.label("Paused", 26, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(Ui.label("Biscuit is holding very still.", 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(Ui.spacer(2))
	column.add_child(Ui.button("Resume", 16, 50, Ui.ORANGE, func() -> void: _pause(false)))
	column.add_child(Ui.ghost("Restart level", func() -> void:
		_pause(false)
		_reset(), 46, 14))
	column.add_child(Ui.ghost("Settings", func() -> void:
		_pause(false)
		Router.main.navigate("settings"), 46, 14))
	column.add_child(Ui.ghost("Back to map", func() -> void:
		_pause(false)
		Router.go("levels", {"world": int(level.get("world", 0))}), 46, 14))


func _pause(value := true) -> void:
	paused = value
	_pause_layer.visible = value
	Audio.ui_back() if value else Audio.ui_click()
	if value and draw_engine != null:
		draw_engine.cancel()


# --------------------------------------------------------------------------
# result
# --------------------------------------------------------------------------

func _build_result() -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.visible = false
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.14, 0.19, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(centre)
	var card := Ui.panel(Color("#fffdf6"), 28, Color("#e8dcc4"), 22, 18)
	card.custom_minimum_size.x = 330
	centre.add_child(card)
	var column := Ui.column(8)
	card.add_child(column)
	_result_title = Ui.label("Biscuit is safe!", 27, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_result_title)
	_star_row = StarRow.new()
	_star_row.size_px = 38.0
	_star_row.gap = 10.0
	column.add_child(_star_row)
	_result_reason = Ui.label("", 12, Ui.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	column.add_child(_result_reason)
	_result_stats = Ui.label("", 13, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	column.add_child(_result_stats)
	_result_extra = Ui.label("", 12, Color("#c98c14"), HORIZONTAL_ALIGNMENT_CENTER, true)
	column.add_child(_result_extra)
	column.add_child(Ui.spacer(2))
	_result_next = Ui.button("Next level", 17, 52, Ui.ORANGE, func() -> void: _next())
	column.add_child(_result_next)
	_result_retry = Ui.ghost("Retry", func() -> void:
		Save.register_reset()
		resets += 1
		_reload(), 46, 14)
	column.add_child(_result_retry)
	column.add_child(Ui.ghost("World map", func() -> void:
		Router.go("levels", {"world": int(level.get("world", 0))}), 46, 14))
	# Quiet support link: results card only, under the actions.
	column.add_child(Ui.ghost("☕ Buy me a coffee", TipJar.open, 34, 11))


func _on_won(stars: int, used: float, seconds: float) -> void:
	phase = "won"
	_update_hud()
	var id := int(level.get("id", 0))
	var result := Save.record_solve(id, stars, seconds, used, draw_budget, String(level.get("mode", "bee")),
		resets, hints)
	var unlocked: Array = result.get("unlocked", [])
	_star_row.set_stars(stars)
	_result_title.text = "Biscuit is safe!"
	_result_title.add_theme_color_override("font_color", Ui.INK)
	_result_reason.text = "A clean rescue. Biscuit did a little spin."
	_result_stats.text = "%.1f m of %.1f m used  ·  %s" % [used, draw_budget, Ui.format_time(int(seconds))]
	_result_extra.text = ""
	_result_next.visible = true
	if not unlocked.is_empty():
		_result_extra.text = "Trophy! %s" % Save.achievement_name(String(unlocked[0]))
	result_open = true
	_result_layer.visible = true
	_result_layer.modulate.a = 0.0
	create_tween().tween_property(_result_layer, "modulate:a", 1.0, 0.25)
	get_tree().create_timer(0.15).timeout.connect(func() -> void: _star_row.animate_in())
	for i in range(stars):
		get_tree().create_timer(0.45 + i * 0.2).timeout.connect(Audio.star.bind(i))
	if not unlocked.is_empty():
		Audio.unlock()
	Arcade.track("level_win", {
		"level": id, "mode": String(level.get("mode", "bee")), "stars": stars,
		"used": used, "seconds": seconds,
	})
	Arcade.refresh_identity()
	_disable_actions()


func _on_lost(reason: String) -> void:
	if result_open:
		return
	phase = "lost"
	_update_hud()
	_disable_actions()
	get_tree().create_timer(0.7).timeout.connect(func() -> void: _show_loss(reason))


func _show_loss(reason: String) -> void:
	if not is_inside_tree() or phase != "lost":
		return
	_star_row.set_stars(0)
	_result_title.text = "Not quite!"
	_result_title.add_theme_color_override("font_color", Ui.RED)
	_result_reason.text = reason
	_result_stats.text = "No stars this time — but Biscuit is fine. Try a different shape."
	_result_extra.text = "Retry is free and always will be."
	_result_next.visible = false
	result_open = true
	_result_layer.visible = true
	_result_layer.modulate.a = 0.0
	create_tween().tween_property(_result_layer, "modulate:a", 1.0, 0.22)
	Arcade.track("level_loss", {"level": int(level.get("id", 0)), "reason": reason})


func _disable_actions() -> void:
	if _action != null:
		_action.disabled = true
	if _undo_button != null:
		_undo_button.disabled = true
	if _reset_button != null:
		_reset_button.disabled = true
	if _hint_button != null:
		_hint_button.disabled = true


func _next() -> void:
	var id := int(level.get("id", 1))
	var next_id := id + 1
	if next_id > Levels.level_count():
		Router.go("worlds")
		return
	Audio.ui_click()
	Router.go("game", {"level": Levels.get_level(next_id), "mode": "campaign"})


func _exit_tree() -> void:
	Audio.bee(0.0)


# --------------------------------------------------------------------------
# web debug hooks
# --------------------------------------------------------------------------

func debug_state() -> Dictionary:
	var state := {
		"screen": "game",
		"level": int(level.get("id", 0)),
		"mode": mode,
		"phase": phase,
		"used": runtime.used if runtime != null else 0.0,
		"budget": draw_budget,
		"resets": resets,
		"hints": hints,
		"result": result_open,
		"solution_screen": [],
	}
	if runtime != null and Router.main != null and Router.main.camera != null:
		var raw: Array = level.get("solution", [])
		var points: Array = []
		for value in raw:
			var pair: Array = value
			var screen: Vector2 = Router.main.camera.unproject_position(
				Vector3(float(pair[0]), float(pair[1]), 0.0))
			points.append([screen.x, screen.y])
		state["solution_screen"] = points
		state.merge(runtime.debug_state(), true)
	return state


func debug_inject() -> void:
	if runtime == null or phase != "draw":
		return
	runtime.apply_solution()
	draw_engine.set_spent(runtime.used)
	_update_hud()
