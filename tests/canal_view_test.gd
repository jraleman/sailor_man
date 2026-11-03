extends SceneTree

## Real Compatibility renders guard singer framing, readable source contours and
## the draw budget. This deliberately refuses the dummy headless renderer.

const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const FEATURES := {
	Arenas.GATUN: ["TropicalBanks"],
	Arenas.LAKE: ["LakeIslands", "DistantShips", "HowlerCanopy"],
	Arenas.CULEBRA: ["CutTerraces", "CentennialBridge"],
	Arenas.PEDRO_MIGUEL: ["TropicalBanks", "PedroMiguelTown"],
	Arenas.PACIFIC: [
		"PacificCauseway", "PacificSkyline", "BridgeOfTheAmericas", "FestivalBoatsAndBunting",
	],
}

var _failures := PackedStringArray()
var _maximum_draws := 0
var _capture_directory := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Sailor canal view tests require a real graphics window, not --headless.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-capture-dir="):
			_capture_directory = argument.trim_prefix("--sailor-capture-dir=")
	if not _capture_directory.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
			"Could not create the canal capture directory.")
	GameCatalog.select(Options.GAME_ID)
	var session := get_root().get_node("GameSession")
	session.call("configure_single_player")
	session.call("set_level", Arenas.GATUN)
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values["ui/scale"] = 1.0
	for option: Dictionary in Options.TUNABLES:
		values[option["key"]] = option["default"]
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		values[binding["key"]] = binding["default"]
	settings.set("_values", values)
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	var scene := load("res://games/sailor_man/gameplay.tscn") as PackedScene
	if scene == null:
		printerr("Sailor Man canal gameplay scene could not load.")
		quit(1)
		return
	var game := scene.instantiate()
	game.set("voice_profile_path", "user://sailor_canal_unwritten.cfg")
	get_root().add_child(game)
	await _settle()
	game.set_process(false)
	game.call("_set_reduced_motion_enabled", false)
	game.call("_set_intense_effects_enabled", true)
	var hud := game.get_node("%DuelHud") as Control
	var canal: Control = hud.get("lock")
	var viewport: SubViewport = canal.get("viewport")
	_expect(viewport.find_world_3d() != get_root().find_world_3d(),
		"The canal must own its world rather than share the shell's lighting or camera.")
	for arena: Dictionary in Arenas.ENTRIES:
		session.call("set_level", str(arena["id"]))
		await _test_layouts(game, hud, canal, str(arena["id"]))
	session.call("set_level", Arenas.GATUN)
	game.queue_free()
	await _settle()
	await create_timer(0.1, true, false, true).timeout
	settings.set("_values", original)
	settings.call("save")
	get_root().min_size = old_minimum
	get_root().size = old_size
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	if _failures.is_empty():
		print("Sailor canal view tests passed (%s, maximum %d draw calls)." % [
			DisplayServer.get_name(), _maximum_draws,
		])
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_layouts(game: Node, hud: Control, canal: Control, arena_id: String) -> void:
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	var viewport: SubViewport = canal.get("viewport")
	for size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720),
			Vector2i(2560, 1080)]:
		for scale: float in [1.0, 1.5]:
			game.call("_return_to_duel")
			values["ui/scale"] = scale
			get_root().min_size = Vector2i.ZERO
			get_root().size = size
			settings.call("_update_content_scale")
			settings.emit_signal("changed", "ui/scale", scale)
			await _settle()
			game.call("_on_duel_action")
			game.call("_update_round", 3.73, 0.0)
			game.call("_on_duel_action")
			game.call("_on_duel_action")
			game.call("_update_round", 0.25, 0.0)
			_key(KEY_SPACE)
			game.call("_update_round", 0.6, 0.0)
			_key(KEY_J)
			game.call("_update_round", 0.04, 0.0)
			_key(KEY_J, false)
			game.call("_update_round", 0.6, 0.0)
			await _settle()
			_assert_live_input(game, hud, size, scale)
			_capture_root("canal-%s-input-%dx%d-ui%.1f.png" % [
				arena_id, size.x, size.y, scale,
			])
			_key(KEY_K)
			game.call("_update_round", 0.12, 0.0)
			_key(KEY_K, false)
			_key(KEY_SPACE, false)
			var state: Duel = game.get("_duel")
			_expect(state.phase == Duel.Phase.REVIEW and state.records.size() == 2,
				"The canal fixture must finish real admitted Remo input, not inject a score.")
			for singer in 2:
				var rival: Dictionary = game.get("_rival")
				var spike := game.get_node("%ScorerSpike")
				var track: Array[Dictionary] = rival["frames"] if singer == 1 \
					else spike.get("_track")
				var profile: Dictionary = rival["profile"] if singer == 1 \
					else spike.get("_profile")
				var evidence: Dictionary = state.records[0 if singer == 1 else 1][
					"result"]["evidence"]
				var reference: Array[Dictionary] = []
				hud.call("show_track", track, reference, evidence,
					state.window_seconds, profile, singer)
				for fraction: float in [0.0, 1.0]:
					canal.call("present", fraction, singer)
					canal.call("_process", 1.2)
					await _settle()
					var label := "%s-%dx%d-ui%.1f-%s-water%.0f" % [
						arena_id, size.x, size.y, scale,
						"p1" if singer == 0 else "cpu", fraction,
					]
					_assert_render(canal, label)
					_capture(viewport.get_texture().get_image(), "canal-" + label + ".png")
			if size == Vector2i(1280, 720) and scale == 1.0:
				await _assert_landmarks(game, canal, arena_id)
			await _assert_motion(game, hud)


func _assert_live_input(game: Node, hud: Control, size: Vector2i, scale: float) -> void:
	var canal: Control = hud.get("lock")
	var viewport: SubViewport = canal.get("viewport")
	var ribbon: Node3D = canal.get("ribbon")
	var spike := game.get_node("%ScorerSpike") as Control
	_expect(ribbon.get("_frames") == spike.get("_track")
		and canal.get("_track_singer") == Duel.Singer.PLAYER,
		"Live player geometry must use exactly the admitted source track.")
	var window := Rect2(Vector2.ZERO, Vector2(size))
	for control in [spike.get_node("%VoiceRibbon"), spike.get_node("%RemoBreak"),
			hud.get_node("%PauseDuel")]:
		var rect := get_root().get_final_transform() * (control as Control).get_global_rect()
		_expect(window.encloses(rect),
			"Canal presentation must not displace live input at %s / %.1f UI." % [size, scale])
	var wide := float(size.x) / scale >= 900.0 and float(size.y) / scale >= 500.0
	_expect(canal.is_visible_in_tree() == wide,
		"Narrow listening must prioritize the input lane, while wide layouts keep the singers.")
	_expect(viewport.render_target_update_mode == (
		SubViewport.UPDATE_ALWAYS if wide else SubViewport.UPDATE_DISABLED),
		"A deliberately hidden canal must not continue rendering in the background.")


func _assert_render(canal: Control, label: String) -> void:
	var viewport: SubViewport = canal.get("viewport")
	var camera: Camera3D = canal.get("camera")
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-2.0)
	var image := viewport.get_texture().get_image()
	var draws := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_maximum_draws = maxi(_maximum_draws, draws)
	_expect(draws > 0 and draws < 60, label + ": nonempty rendering must stay below 60 draws.")
	for point: Vector3 in canal.get("_landmark_points"):
		_expect(bounds.has_point(camera.unproject_position(point)),
			label + ": the location's complete primary landmark must remain framed.")
	for index in 2:
		var boats: Array = canal.get("boats")
		var boat: Node3D = boats[index]
		var mesh: MeshInstance3D = boat.get("body")
		var hull := Rect2()
		for corner in 8:
			var point := mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
			var projected := camera.unproject_position(point)
			_expect(not camera.is_position_behind(point) and bounds.has_point(projected),
				label + ": the complete launch, including its pennant, must remain framed.")
			hull = Rect2(projected, Vector2.ZERO) if corner == 0 else hull.expand(projected)
		var plaque: Label3D = boat.get("plaque")
		_expect(plaque.text == ("P1" if index == 0 else "CPU")
			and bounds.has_point(camera.unproject_position(plaque.global_position)),
			label + ": a seat must have an in-frame identity label, not colour alone.")
		_expect(_paint_pixels(image, hull, index) >= 12,
			label + ": each launch must actually render its distinct paint, not only an AABB.")
	var ribbon: Node3D = canal.get("ribbon")
	var points: PackedVector3Array = ribbon.get("points")
	var frames: Array = ribbon.get("_frames")
	var visible_contour := 0
	for index in points.size():
		var point := ribbon.to_global(points[index])
		var projected := camera.unproject_position(point)
		_expect(bounds.has_point(projected),
			label + ": a source-relative high contour must stay in the shot.")
		if index % 15 == 0 and bool(frames[index]["voiced"]) \
				and float(frames[index]["cents"]) >= 500.0:
			visible_contour += int(_gold_near(image, projected))
	_expect(visible_contour >= 2,
		label + ": the actual lit scene must expose the contour, not bury it behind a launch.")


func _assert_landmarks(game: Node, canal: Control, arena_id: String) -> void:
	game.call("_set_reduced_motion_enabled", true)
	await _settle()
	var viewport: SubViewport = canal.get("viewport")
	var scenery: Node3D = canal.get("_scenery")
	for name: String in FEATURES[arena_id]:
		var mesh := scenery.get_node_or_null(name) as MeshInstance3D
		_expect(mesh != null, arena_id + ": missing authored feature " + name)
		if mesh == null:
			continue
		var before := viewport.get_texture().get_image()
		mesh.hide()
		await _settle()
		var after := viewport.get_texture().get_image()
		var changed := 0
		for y in range(0, before.get_height(), 2):
			for x in range(0, before.get_width(), 2):
				var a := before.get_pixel(x, y)
				var b := after.get_pixel(x, y)
				changed += int(absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08)
		_expect(changed >= (4 if name == "HowlerCanopy" else 30),
			"%s: %s must affect real pixels, not hide inside another mesh." % [arena_id, name])
		mesh.show()
		await _settle()
	game.call("_set_reduced_motion_enabled", false)


func _assert_motion(game: Node, hud: Control) -> void:
	var canal: Control = hud.get("lock")
	var camera: Camera3D = canal.get("camera")
	game.call("_set_reduced_motion_enabled", true)
	var pose := camera.transform
	var boats: Array = canal.get("boats")
	var boat_pose: Transform3D = boats[0].transform
	var time := float(canal.get("_elapsed"))
	await _settle()
	_expect(camera.transform.is_equal_approx(pose)
		and boats[0].transform.is_equal_approx(boat_pose)
		and is_equal_approx(float(canal.get("_elapsed")), time),
		"Reduced motion must park the real camera, launch bobbing and decorative clock.")
	var ribbon: Node3D = canal.get("ribbon")
	var contour: PackedVector3Array = ribbon.get("points")
	game.call("_set_intense_effects_enabled", false)
	_expect(not contour.is_empty() and ribbon.get("points") == contour,
		"Disabling intense effects must retain the essential pitch contour.")
	game.call("_set_reduced_motion_enabled", false)
	hud.hide()
	var viewport: SubViewport = canal.get("viewport")
	time = float(canal.get("_elapsed"))
	await _settle()
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
		and is_equal_approx(float(canal.get("_elapsed")), time),
		"Hidden menus/practice must stop the actual canal rendering and decorative clock.")
	hud.show()
	await _settle()
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Returning from an overlay must resume the visible canal.")
	time = float(canal.get("_elapsed"))
	boat_pose = boats[0].transform
	paused = true
	await _settle()
	_expect(is_equal_approx(float(canal.get("_elapsed")), time)
		and boats[0].transform.is_equal_approx(boat_pose),
		"The shell's real pause must also stop the isolated canal's decorative motion.")
	paused = false
	game.call("_set_intense_effects_enabled", true)


func _paint_pixels(image: Image, area: Rect2, seat: int) -> int:
	var count := 0
	for y in range(maxi(0, floori(area.position.y)), mini(image.get_height(), ceili(area.end.y)), 2):
		for x in range(maxi(0, floori(area.position.x)), mini(image.get_width(), ceili(area.end.x)), 2):
			var color := image.get_pixel(x, y)
			var paint := color.b > color.r * 1.4 and color.b > color.g * 1.08 if seat == 0 \
				else color.r > color.g * 1.4 and color.r > color.b * 1.2
			count += int(paint)
	return count


func _gold_near(image: Image, point: Vector2) -> bool:
	var at := Vector2i(point)
	for y in range(maxi(0, at.y - 3), mini(image.get_height(), at.y + 4)):
		for x in range(maxi(0, at.x - 3), mini(image.get_width(), at.x + 4)):
			var color := image.get_pixel(x, y)
			if color.r > 0.7 and color.r > color.g * 1.03 and color.g > color.b * 1.3:
				return true
	return false


func _key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	get_root().push_input(event, true)


func _settle() -> void:
	for _frame in 6:
		await process_frame


func _capture_root(filename: String) -> void:
	_capture(get_root().get_texture().get_image(), filename)


func _capture(image: Image, filename: String) -> void:
	if not _capture_directory.is_empty():
		_expect(image.save_png(_capture_directory.path_join(filename)) == OK,
			"Could not save " + filename)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
