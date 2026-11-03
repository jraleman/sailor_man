extends SceneTree

## Exercise the actual opening, Router and written guide without voice capture.
## Native runs also check complete models and readable, scrollable enlarged copy.

const Manifest = preload("res://games/sailor_man/game.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const INTRO := "res://games/sailor_man/intro.tscn"
const TITLE := "res://scenes/menus/main_menu.tscn"
const GUIDE := "res://scenes/menus/instructions.tscn"
const FRAMEWORK_INTRO := "res://scenes/boot/intro.tscn"
const SIZES: Array[Vector2i] = [
	Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720), Vector2i(2560, 1080),
]

var _failures := PackedStringArray()
var _routes := PackedStringArray()
var _settings: Node
var _router: Node
var _capture_directory := ""
var _layout_cases := 0
var _maximum_draws := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = get_root().get_node("Settings")
	_router = get_root().get_node("Router")
	var original: Dictionary = _settings.get("_values").duplicate(true)
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	var old_theme := get_root().theme
	var old_mouse := get_root().get_mouse_position()
	_settings.set("_values", original.duplicate(true))
	get_root().min_size = Vector2i.ZERO
	await _resize(Vector2i(1280, 720), 1.0)
	_setting(Settings.REDUCED_MOTION_KEY, true)
	_router.connect("scene_changed", _on_scene_changed)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-onboarding-capture-dir="):
			_capture_directory = argument.trim_prefix("--sailor-onboarding-capture-dir=")
	if not _capture_directory.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
			"Requested onboarding captures need a writable directory.")
	var saved := _save_snapshot()
	var buses := AudioServer.bus_count
	GameCatalog.clear_restriction()
	_expect(GameCatalog.intro_scene_path(FRAMEWORK_INTRO) == FRAMEWORK_INTRO,
		"A collection must retain the framework opening.")
	GameCatalog.restrict_to(Options.GAME_ID)
	_expect(Manifest.manifest().intro_scene_path == INTRO
		and GameCatalog.intro_scene_path(FRAMEWORK_INTRO) == INTRO,
		"Only a standalone Sailor catalog must select the practice opening.")
	var probe := _open_intro()
	if probe == null:
		quit(1)
		return
	await _settle()
	await _test_cards_and_input(probe)
	await _test_static_and_visibility(probe)
	if DisplayServer.get_name() != "headless":
		await _test_opening_layouts(probe)
	probe.queue_free()
	await _settle()
	GameCatalog.clear_restriction()
	GameCatalog.select(Options.GAME_ID)
	for human in [false, true]:
		await _test_guide(human)
	GameCatalog.restrict_to(Options.GAME_ID)
	await _resize(Vector2i(1280, 720), 1.0)
	await _test_navigation()
	_expect(AudioServer.bus_count == buses,
		"Opening, guide and title navigation must never create a microphone bus.")
	_expect(_save_snapshot() == saved,
		"Onboarding must not change settings, profiles, wallets or progress.")
	if DisplayServer.get_name() != "headless":
		_expect(_layout_cases == 40, "Native checks must complete all 40 opening/guide layouts.")
	if current_scene != null:
		current_scene.queue_free()
		await _settle()
	GameCatalog.clear_restriction()
	_settings.set("_values", original)
	get_root().theme = old_theme
	get_root().min_size = old_minimum
	get_root().size = old_size
	_settings.call("_update_content_scale")
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(old_mouse)
	await create_timer(0.15, true, false, true).timeout
	if _failures.is_empty():
		print("Sailor onboarding tests passed (%s, %d layouts, maximum %d draws)." % [
			DisplayServer.get_name(), _layout_cases, _maximum_draws,
		])
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _open_intro() -> Control:
	var packed := load(INTRO) as PackedScene
	if packed == null:
		_expect(false, "The declared practice opening must load.")
		return null
	var intro := packed.instantiate() as Control
	if intro == null or not intro.has_method("_on_next_pressed"):
		_expect(false, "The opening must load its actual navigation script.")
		if intro != null:
			intro.free()
		return null
	get_root().add_child(intro)
	return intro


func _test_cards_and_input(intro: Control) -> void:
	var next := intro.get_node("%NextButton") as Button
	var stage := intro.get_node("%Stage") as Control
	_expect(get_root().gui_get_focus_owner() == next,
		"The opening must start with Next focused, not auto-start a match.")
	_expect((intro.get_node("%Copy") as Label).text.contains("synthetic")
		and (intro.get_node("%Copy") as Label).text.contains("pending"),
		"The opening must identify free practice and unfinished recorded/campaign content.")
	_key(KEY_ENTER, 4)
	await _settle()
	_expect(int(intro.get("_card_index")) == 1
		and str((stage.get("_exhibit") as Dictionary)["id"]) == "launch",
		"Enter, including held-key repeats, must advance only once to the actual launch.")
	_pad(JOY_BUTTON_A)
	await _settle()
	_expect(int(intro.get("_card_index")) == 2 and next.text == "Done"
		and str((stage.get("_exhibit") as Dictionary)["id"]) == "hot_seat",
		"Controller confirm must advance to both real P1/P2 launches and a clear exit.")
	_expect((intro.get_node("%Copy") as Label).text.contains("only Enable microphone")
		and (intro.get_node("%Copy") as Label).text.contains("not a match"),
		"The final card must preserve explicit microphone consent and title routing.")
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		_expect(intro.find_children("*", type, true, false).is_empty(),
			"The opening must contain no narration, voice playback or microphone players.")
	_expect(not stage.accessibility_description.is_empty()
		and not (intro.get_node("%Step") as Label).accessibility_name.is_empty(),
		"Static models and card progress need descriptive accessibility text.")
	intro.call("_show_card", 0)
	await _settle()
	await _touch(intro.get_node("%NextButton") as Control)
	_expect(int(intro.get("_card_index")) == 1,
		"A real touch tap on Next must work without keyboard or microphone.")
	_click(intro.get_node("%NextButton") as Control)
	await _settle()
	_expect(int(intro.get("_card_index")) == 2, "A mouse click must also advance one card.")


func _test_static_and_visibility(intro: Control) -> void:
	var body := intro.get_node("%Body") as Control
	var stage := intro.get_node("%Stage") as Control
	_setting(Settings.REDUCED_MOTION_KEY, false)
	intro.call("_show_card", 1)
	_expect(body.modulate.a < 1.0 and body.scale == Vector2.ONE,
		"Card transitions may fade opacity, never move or scale anchored content.")
	_setting(Settings.REDUCED_MOTION_KEY, true)
	_expect(is_equal_approx(body.modulate.a, 1.0),
		"Enabling reduced motion mid-fade must immediately restore readable copy.")
	await _settle()
	var camera: Camera3D = stage.get("camera")
	var parked := camera.transform
	var models: Node3D = stage.get("_models")
	var model_pose := models.transform
	_setting(Settings.REDUCED_MOTION_KEY, false)
	await create_timer(0.3).timeout
	_expect(camera.transform.is_equal_approx(parked)
		and models.transform.is_equal_approx(model_pose) and int(intro.get("_card_index")) == 1,
		"Models must remain static and cards player-paced with reduced motion either way.")
	_setting(Settings.REDUCED_MOTION_KEY, true)
	var viewport: SubViewport = stage.get("viewport")
	intro.hide()
	await _settle()
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"A hidden opening must stop its private 3D rendering.")
	intro.show()
	await _settle()
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Showing the opening again must restore the current model, not create voice input.")


func _test_opening_layouts(intro: Control) -> void:
	var stage := intro.get_node("%Stage") as Control
	var scroll := intro.get_node("%CopyScroll") as ScrollContainer
	for dimensions in SIZES:
		for scale: float in [1.0, 1.5]:
			await _resize(dimensions, scale)
			intro.call("_show_card", 0)
			for index in 3:
				if index > 0:
					(intro.get_node("%NextButton") as Button).pressed.emit()
				await _settle()
				var label := "opening-%d-%dx%d-ui%.1f" % [
					index + 1, dimensions.x, dimensions.y, scale,
				]
				_assert_control(intro.get_node("%SkipButton"), dimensions, scale, label)
				_assert_control(intro.get_node("%NextButton"), dimensions, scale, label)
				_assert_label(intro.get_node("%Title"), 24.0, scale, label)
				_assert_label(intro.get_node("%Heading"), 22.0, scale, label)
				_assert_label(intro.get_node("%Copy"), 16.0, scale, label)
				_expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(_native_rect(stage))
					and _native_rect(stage).size.x > 40 and _native_rect(stage).size.y > 40
					and not _native_rect(stage).intersects(_native_rect(scroll)),
					label + ": the whole static stage needs its own unobstructed space.")
				await _assert_model(stage, label)
				scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
				await _settle()
				_expect(_native_rect(intro.get_node("%Copy")).end.y
					<= _native_rect(scroll).end.y + 1.0,
					label + ": the final line must be reachable without clipping actions.")
				var bar := scroll.get_v_scroll_bar()
				if bar.max_value > bar.page:
					var bottom := scroll.scroll_vertical
					_pad(JOY_BUTTON_DPAD_UP)
					await _settle()
					_expect(scroll.scroll_vertical < bottom,
						label + ": controller up must scroll actual enlarged copy.")
					var before := scroll.scroll_vertical
					_pad(JOY_BUTTON_DPAD_DOWN)
					await _settle()
					_expect(scroll.scroll_vertical > before,
						label + ": controller down must reach the final copy again.")
				_pad(JOY_BUTTON_DPAD_LEFT)
				await _settle()
				_expect((intro.get_node("%SkipButton") as Button).has_focus(),
					label + ": controller left must focus the actual Skip action.")
				_pad(JOY_BUTTON_DPAD_RIGHT)
				await _settle()
				_expect((intro.get_node("%NextButton") as Button).has_focus(),
					label + ": controller right must restore Next/Done focus.")
				_capture(label)
				_layout_cases += 1


func _assert_model(stage: Control, label: String) -> void:
	var viewport: SubViewport = stage.get("viewport")
	var camera: Camera3D = stage.get("camera")
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-1.0)
	var points: Array = stage.get("_points")
	_expect(not points.is_empty() and viewport.gui_disable_input
		and viewport.find_world_3d() != get_root().find_world_3d(),
		label + ": opening models must use the actual isolated, noninteractive stage.")
	for point: Vector3 in points:
		_expect(not camera.is_position_behind(point)
			and bounds.has_point(camera.unproject_position(point)),
			label + ": every model and landmark must remain fully framed.")
	var draws := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_maximum_draws = maxi(_maximum_draws, draws)
	_expect(draws > 0 and draws < 60, label + ": the original models must render below 60 draws.")
	var image := viewport.get_texture().get_image()
	var models: Node3D = stage.get("_models")
	models.hide()
	await _settle()
	_expect(_changed_pixels(image, viewport.get_texture().get_image()) >= 12,
		label + ": the complete framed model must produce actual visible pixels.")
	models.show()
	await _settle()


func _test_guide(human: bool) -> void:
	var session := get_root().get_node("GameSession")
	if human:
		var controllers: Dictionary = session.get_script().get_script_constant_map()[
			"PlayerTwoController"]
		session.call("configure_multiplayer", int(controllers["HUMAN"]))
	else:
		session.call("configure_single_player")
	var screen := (load(GUIDE) as PackedScene).instantiate() as Control
	get_root().add_child(screen)
	await _settle()
	var toggle := screen.get_node("%GuideButton") as Button
	toggle.button_pressed = true
	await _settle()
	var guide := screen.get_node("%Guide") as ScrollContainer
	var rules := screen.get_node("%Rules") as Label
	_expect(guide.is_visible_in_tree() and not (screen.get_node("%VideoCard") as Control).visible,
		"The actual Guide action must expose the written rules instead of playing footage.")
	for term: String in [
		"Aliento:", "five seconds", "Quiebre:", "Break", "Altura:", "source/profile",
		"unmeasured", "Remate:", "Grito", "Eco:", "Calls omit Eco", "Quiet Mode",
		"game simplification", "Hot seat", "no chamber deadline", "600 ms",
	]:
		_expect(rules.text.contains(term), "The shared written guide must explain " + term)
	_expect((screen.get_node("%OpponentCard") as Control).visible == human,
		"The guide must retain the real solo/hot-seat control-card contract.")
	var values: Dictionary = _settings.get("_values")
	var old_binding := int(values[Options.VOICE_KEY])
	_setting(Options.VOICE_KEY, KEY_Z)
	await _settle()
	for name: String in ["PlayerOneControls", "OpponentControls"] if human else ["PlayerOneControls"]:
		_expect((screen.get_node("%" + name) as Label).text.contains("Voice: Z"),
			"Both hot-seat singers must see the current shared Remo binding, never stale keys.")
	_setting(Options.VOICE_KEY, old_binding)
	if DisplayServer.get_name() != "headless":
		for dimensions in SIZES:
			for scale: float in [1.0, 1.5]:
				await _resize(dimensions, scale)
				var label := "guide-%s-%dx%d-ui%.1f" % [
					"human" if human else "solo", dimensions.x, dimensions.y, scale,
				]
				_assert_control(screen.get_node("%StartButton"), dimensions, scale, label)
				_assert_control(screen.get_node("%BackButton"), dimensions, scale, label)
				_assert_control(toggle, dimensions, scale, label)
				_assert_label(rules, 14.0, scale, label)
				var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
				_expect(bounds.encloses(_native_rect(guide))
					and _native_rect(guide).size.y >= 32.0 * scale,
					label + ": the written guide needs a usable in-window scroll viewport.")
				guide.scroll_vertical = int(guide.get_v_scroll_bar().max_value)
				await _settle()
				_expect(_native_rect(rules).end.y <= _native_rect(guide).end.y + 1.0,
					label + ": all five explanations and the final comfort note must be reachable.")
				_capture(label)
				_layout_cases += 1
	screen.queue_free()
	await _settle()


func _test_navigation() -> void:
	for method: String in [
		"done", "mouse_skip", "touch_skip", "escape", "pad_cancel", "pad_skip", "incoming",
	]:
		_routes.clear()
		_router.call("goto", INTRO, method == "incoming")
		var deadline := Time.get_ticks_msec() + 5000
		while (current_scene == null or current_scene.scene_file_path != INTRO) \
			and Time.get_ticks_msec() < deadline:
			await process_frame
		var intro := current_scene
		if intro == null or not intro.has_method("_on_skip_pressed"):
			_expect(false, method + ": Router must open the real scripted intro.")
			return
		if method == "incoming":
			_expect(bool(_router.call("is_transitioning")),
				"The incoming-transition case must finish while Router is still busy.")
			intro.call("_on_skip_pressed")
		else:
			await _wait_for_router()
			await _settle()
			match method:
				"done":
					for card in 3:
						(intro.get_node("%NextButton") as Button).grab_focus()
						_key(KEY_ENTER)
						await process_frame
				"mouse_skip":
					_click(intro.get_node("%SkipButton"))
				"touch_skip":
					await _touch(intro.get_node("%SkipButton"))
				"escape":
					_key(KEY_ESCAPE)
				"pad_cancel":
					_pad(JOY_BUTTON_B)
				"pad_skip":
					_pad(JOY_BUTTON_DPAD_LEFT)
					_pad(JOY_BUTTON_A)
		var finish_deadline := Time.get_ticks_msec() + 1000
		while is_instance_valid(intro) and not bool(intro.get("_finished")) \
			and Time.get_ticks_msec() < finish_deadline:
			await process_frame
		if is_instance_valid(intro):
			_expect(bool(intro.get("_finished")),
				method + ": actual input must request the exit before duplicate-skip checks.")
			for repeat in 4:
				intro.call("_on_skip_pressed")
			_expect((intro.get_node("%NextButton") as Button).disabled
				and (intro.get_node("%SkipButton") as Button).disabled,
				method + ": finishing must guard both actions against repeated input.")
		await _wait_for_router()
		_expect(_routes == PackedStringArray([INTRO, TITLE])
			and current_scene != null and current_scene.scene_file_path == TITLE,
			method + ": Next/Skip/cancel must route exactly once to the normal title.")


func _wait_for_router() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while bool(_router.call("is_transitioning")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not bool(_router.call("is_transitioning")), "The real Router must finish its fades.")


func _on_scene_changed(path: String) -> void:
	_routes.append(path)


func _resize(dimensions: Vector2i, scale: float) -> void:
	get_root().size = dimensions
	_setting("ui/scale", scale)
	_settings.call("_update_content_scale")
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2.ZERO)
	await _settle()


func _setting(key: String, value: Variant) -> void:
	var values: Dictionary = _settings.get("_values")
	values[key] = value
	_settings.emit_signal("changed", key, value)


func _assert_control(control: Control, dimensions: Vector2i, scale: float, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
	var rect := _native_rect(control)
	_expect(control.is_visible_in_tree() and bounds.encloses(rect)
		and rect.size.y >= 43.0 * scale,
		label + ": " + str(control.name) + " must remain a whole visible 44px touch target.")


func _assert_label(label: Label, minimum: float, scale: float, context: String) -> void:
	var transform := get_root().get_final_transform() * label.get_global_transform_with_canvas()
	_expect(float(label.get_theme_font_size("font_size")) * transform.get_scale().y
		>= minimum * scale - 0.5,
		context + ": " + str(label.name) + " must stay physically legible at the chosen UI scale.")


func _native_rect(control: Control) -> Rect2:
	return get_root().get_final_transform() * control.get_global_transform_with_canvas() \
		* Rect2(Vector2.ZERO, control.size)


func _key(code: Key, repeats := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for repeat in repeats:
		event = event.duplicate()
		event.echo = true
		Input.parse_input_event(event)
	event = event.duplicate()
	event.echo = false
	event.pressed = false
	Input.parse_input_event(event)


func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	event.pressure = 1.0
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	event.pressure = 0.0
	Input.parse_input_event(event)


func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _native_rect(control).get_center()
	event.global_position = event.position
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)


func _touch(control: Control) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = _native_rect(control).get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _changed_pixels(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var result := 0
	var step := maxi(1, first.get_width() / 220)
	for y in range(0, first.get_height(), step):
		for x in range(0, first.get_width(), step):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				result += 1
	return result


func _save_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for file in DirAccess.get_files_at("user://"):
		if file.ends_with(".cfg"):
			result[file] = FileAccess.get_file_as_bytes("user://" + file)
	return result


func _capture(name: String) -> void:
	if not _capture_directory.is_empty():
		_expect(get_root().get_texture().get_image().save_png(
			_capture_directory.path_join(name + ".png")) == OK,
			"Could not save requested onboarding capture " + name)


func _settle() -> void:
	for frame in 6:
		await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
