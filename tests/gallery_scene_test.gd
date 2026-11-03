extends SceneTree

## Free exhibits must reuse the match's real meshes without opening a voice
## source or writing progress. Native runs also prove framing and live input.

const Manifest = preload("res://games/sailor_man/game.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const Canal = preload("res://games/sailor_man/world/canal_view.gd")
const Outfit = preload("res://games/sailor_man/world/launch_outfit.gd")

var _failures := PackedStringArray()
var _capture_directory := ""
var _maximum_draws := 0
var _render_cases := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values["ui/scale"] = 1.0
	values[Settings.REDUCED_MOTION_KEY] = true
	settings.set("_values", values)
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	get_root().min_size = Vector2i.ZERO
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	GameCatalog.select(Options.GAME_ID)
	var saved := _save_snapshot()
	var buses := AudioServer.bus_count
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-gallery-capture-dir="):
			_capture_directory = argument.trim_prefix("--sailor-gallery-capture-dir=")
	if not _capture_directory.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
			"Gallery captures need a writable, explicitly requested directory.")
	var packed := load(Manifest.manifest().gallery_stage_scene_path) as PackedScene
	_expect(packed != null, "The declared Sailor gallery stage must load.")
	if packed == null:
		quit(1)
		return
	await _test_configuration(packed)
	var screen := (load("res://scenes/menus/gallery.tscn") as PackedScene).instantiate()
	screen.set("game_context_id", Options.GAME_ID)
	get_root().add_child(screen)
	await _settle()
	await _test_models(screen)
	if DisplayServer.get_name() != "headless":
		await _test_rendered_layouts(screen)
	await _test_controls(screen)
	await _test_visibility(screen)
	var stage: Control = screen.get("_stage")
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		_expect(stage.find_children("*", type, true, false).is_empty(),
			"Exhibits must not create audio players or microphone capture.")
	_expect(AudioServer.bus_count == buses, "Opening and browsing must not create capture buses.")
	_expect(_save_snapshot() == saved, "The gallery must not write settings, profiles or progress.")
	screen.queue_free()
	await _settle()
	settings.set("_values", original)
	get_root().min_size = old_minimum
	get_root().size = old_size
	settings.call("_update_content_scale")
	settings.call("save")
	if _failures.is_empty():
		print("Sailor gallery tests passed (%s, %d renders, maximum %d draw calls)." % [
			DisplayServer.get_name(), _render_cases, _maximum_draws,
		])
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_configuration(packed: PackedScene) -> void:
	var stage := packed.instantiate() as Control
	stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(600, 400)
	stage.call("configure", {"id": "launch", "framing_yaw": INF,
		"scene": "res://games/sailor_man/gameplay.tscn"})
	stage.call("set_view", 0.4, -0.2, 1.3)
	get_root().add_child(stage)
	await _settle()
	_expect(stage.get("_exhibit") == Options.GALLERY_EXHIBITS[0],
		"Configuration must use canonical declarations, not injected paths or framing.")
	_expect(not (stage.get("_error") as Label).visible
		and not (stage.get("_points") as Array).is_empty(),
		"Configuration and view input before ready must build the real exhibit.")
	stage.queue_free()
	await _settle()
	print("Expected gallery rejection diagnostics follow.")
	var bad := packed.instantiate() as Control
	bad.call("configure", {"id": "unavailable_exhibit"})
	get_root().add_child(bad)
	await _settle()
	_assert_rejected(bad)
	bad.call("configure", {"id": "launch"})
	await _settle()
	_expect(not (bad.get("_error") as Label).visible,
		"A valid selection must recover from an earlier rejected configuration.")
	bad.call("configure", {"id": "unavailable_exhibit"})
	await _settle()
	_assert_rejected(bad)
	_expect((bad.get("_models") as Node).get_child_count() == 0,
		"An unavailable exhibit must not retain the previous launch.")
	bad.queue_free()
	await _settle()


func _assert_rejected(stage: Control) -> void:
	var viewport: SubViewport = stage.get("viewport")
	_expect((stage.get("_error") as Label).visible
		and not (stage.get("_error") as Label).text.is_empty()
		and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Unavailable exhibits must explain the failure and stop private rendering.")


func _test_models(screen: Node) -> void:
	var buttons: Array = screen.get("_buttons")
	var stage: Control = screen.get("_stage")
	_expect(buttons.size() == Options.GALLERY_EXHIBITS.size(),
		"The shared list must offer every current Sailor prototype.")
	var view := Canal.new()
	view.size = Vector2(600, 400)
	get_root().add_child(view)
	view.hide()
	view.set_reduced_motion(true)
	for index in Options.GALLERY_EXHIBITS.size():
		var exhibit: Dictionary = Options.GALLERY_EXHIBITS[index]
		var id := str(exhibit["id"])
		var button := buttons[index] as Button
		_expect(not button.disabled and button.tooltip_text.contains(str(exhibit["description"])),
			id + ": free prototypes need usable buttons and honest descriptive help.")
		var previous: Node3D = stage.get("_models")
		button.pressed.emit()
		await _settle()
		var models: Node3D = stage.get("_models")
		_expect(str((stage.get("_exhibit") as Dictionary)["id"]) == id
			and not (stage.get("_points") as Array).is_empty(),
			id + ": selecting a real list row must build that exhibit's geometry.")
		if index > 0:
			_expect(not is_instance_valid(previous),
				id + ": switching must release the previous exhibit subtree.")
		var viewport: SubViewport = stage.get("viewport")
		_expect(viewport.find_world_3d() != get_root().find_world_3d(),
			id + ": gallery lighting and camera must remain isolated from the shell.")
		if id in ["launch", "skiff", "hot_seat"]:
			view.set_outfits([
				Outfit.equipped(get_root().get_node("Store"), 0),
				Outfit.equipped(get_root().get_node("Store"), 1) if id == "hot_seat" else {},
			])
			for seat in 2:
				var boat: Node3D = models.get_node_or_null("Launch%d" % (seat + 1))
				if boat == null:
					continue
				_expect(_same_mesh(boat.get("body"), view.boats[seat].body),
					id + ": gallery hull, crew and paint must match the actual singer rig.")
				var plaque: Label3D = boat.get("plaque")
				_expect(plaque.text == ("P1" if seat == 0 else
					"P2" if id == "hot_seat" else "CPU"),
					id + ": identity must not depend on paint alone.")
		if id in [Arenas.GATUN, Arenas.LAKE, Arenas.CULEBRA, Arenas.PEDRO_MIGUEL, Arenas.PACIFIC]:
			view.configure(id)
			view.set_outfits([Outfit.equipped(get_root().get_node("Store"), 0), {}])
			_compare_tree_meshes(models.get_node("ArenaScenery"), view.get("_scenery"), id)
			var chamber: Node3D = models.get_node("LockSet")
			_compare_tree_meshes(chamber, view.chamber, id)
			_expect((chamber.get_node("Water") as Node3D).position.y == view.chamber.water.position.y,
				id + ": water must be parked at the real route's initial height.")
			for seat in 2:
				var boat: Node3D = models.get_node("Launch%d" % (seat + 1))
				_expect(_same_mesh(boat.get("body"), view.boats[seat].body)
					and boat.position.is_equal_approx(view.boats[seat].position),
					id + ": the diorama must reuse both original boats and tow-point poses.")
		if id in ["gate", "mula"]:
			view.configure(Arenas.GATUN)
			var source := view.chamber.get_node("ChamberAndMulas") as MeshInstance3D
			var detail := models.get_node("GateLeaves" if id == "gate" else "Mula") as MeshInstance3D
			var offset := Vector3.ZERO
			if id == "mula":
				var anchor: Vector3 = view.chamber.tow_anchors[0]
				offset = anchor + Vector3(signf(anchor.x) * 0.38, -0.05, 0)
			_expect(_contains_vertices(source, detail, offset),
				id + ": every close-up vertex must belong to the actual chamber model.")
		if id == "howler":
			view.configure(Arenas.LAKE)
			var source := (view.get("_scenery") as Node).get_node("HowlerCanopy") as MeshInstance3D
			var detail := models.get_node("CanopyHowler") as MeshInstance3D
			var offset := source.mesh.get_aabb().position - detail.mesh.get_aabb().position
			_expect(_contains_vertices(source, detail, offset),
				"The close-up must be the actual lake canopy howler, not another animal.")
	view.queue_free()
	await _settle()


func _compare_tree_meshes(gallery: Node, source: Node, label: String) -> void:
	var expected := source.find_children("*", "MeshInstance3D", true, false)
	_expect(gallery.find_children("*", "MeshInstance3D", true, false).size() == expected.size(),
		label + ": a diorama must retain every current scenery/chamber mesh.")
	for node: Node in expected:
		var actual := gallery.get_node_or_null(source.get_path_to(node)) as MeshInstance3D
		_expect(_same_mesh(actual, node as MeshInstance3D),
			label + ": the gallery must use the actual match geometry for " + str(node.name))


func _same_mesh(first: MeshInstance3D, second: MeshInstance3D) -> bool:
	if first == null or second == null \
		or first.mesh.get_surface_count() != second.mesh.get_surface_count():
		return false
	for surface in first.mesh.get_surface_count():
		var a := first.mesh.surface_get_arrays(surface)
		var b := second.mesh.surface_get_arrays(surface)
		for field in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
			if a[field] != b[field]:
				return false
	return true


func _contains_vertices(source: MeshInstance3D, detail: MeshInstance3D, offset: Vector3) -> bool:
	var source_vertices: PackedVector3Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var detail_vertices: PackedVector3Array = detail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point in detail_vertices:
		var found := false
		for candidate in source_vertices:
			if candidate.is_equal_approx(point + offset):
				found = true
				break
		if not found:
			return false
	return not detail_vertices.is_empty()


func _test_rendered_layouts(screen: Node) -> void:
	var stage: Control = screen.get("_stage")
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	var buttons: Array = screen.get("_buttons")
	for size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720),
			Vector2i(2560, 1080)]:
		for scale: float in [1.0, 1.5]:
			values["ui/scale"] = scale
			get_root().min_size = Vector2i.ZERO
			get_root().size = size
			settings.call("_update_content_scale")
			settings.emit_signal("changed", "ui/scale", scale)
			await _settle()
			for index in Options.GALLERY_EXHIBITS.size():
				(buttons[index] as Button).pressed.emit()
				screen.call("_reset_view")
				await _settle()
				var label := "%s-%dx%d-ui%.1f" % [
					Options.GALLERY_EXHIBITS[index]["id"], size.x, size.y, scale,
				]
				await _assert_render(stage, label)
				_capture(get_root().get_texture().get_image(), label + ".png")


func _assert_render(stage: Control, label: String) -> void:
	var viewport: SubViewport = stage.get("viewport")
	var camera: Camera3D = stage.get("camera")
	var image := viewport.get_texture().get_image()
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-1.0)
	for point: Vector3 in stage.get("_points"):
		_expect(not camera.is_position_behind(point)
			and bounds.has_point(camera.unproject_position(point)),
			label + ": the whole model and all diorama landmarks must remain framed.")
	var draws := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_maximum_draws = maxi(_maximum_draws, draws)
	_expect(draws > 0 and draws < 60, label + ": original batched models must stay below 60 draws.")
	var models: Node3D = stage.get("_models")
	models.hide()
	await _settle()
	_expect(_changed_pixels(image, viewport.get_texture().get_image()) >= 12,
		label + ": the framed model must actually produce visible pixels.")
	models.show()
	await _settle()
	for seat in 2:
		var boat: Node3D = models.get_node_or_null("Launch%d" % (seat + 1))
		if boat == null:
			continue
		var body: MeshInstance3D = boat.get("body")
		body.hide()
		await _settle()
		_expect(_changed_pixels(image, viewport.get_texture().get_image()) >= 3,
			label + ": each real launch must be visible, not buried behind the diorama.")
		body.show()
		await _settle()
	for node in models.find_children("*", "Label3D", true, false):
		var plaque := node as Label3D
		_expect(bounds.has_point(camera.unproject_position(plaque.global_position)),
			label + ": a singer plaque must remain in the image.")
	_render_cases += 1


func _test_controls(screen: Node) -> void:
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	values["ui/scale"] = 1.0
	get_root().min_size = Vector2i.ZERO
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	settings.emit_signal("changed", "ui/scale", 1.0)
	((screen.get("_buttons") as Array)[0] as Button).pressed.emit()
	screen.call("_reset_view")
	await _settle()
	var stage: Control = screen.get("_stage")
	var camera: Camera3D = stage.get("camera")
	var original := camera.transform
	var original_size := camera.size
	var viewer := screen.get_node("%Viewer") as Control
	var at := get_root().get_final_transform() * viewer.get_global_rect().get_center()
	_mouse(MOUSE_BUTTON_LEFT, true, at)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = at + Vector2(40, -18)
	motion.global_position = motion.position
	motion.relative = Vector2(40, -18)
	get_root().push_input(motion, true)
	_mouse(MOUSE_BUTTON_LEFT, false, motion.position)
	_expect(not camera.transform.is_equal_approx(original),
		"A real mouse drag must rotate the model camera through the shared viewer.")
	var before_zoom := camera.size
	_mouse(MOUSE_BUTTON_WHEEL_UP, true, at)
	_expect(camera.size < before_zoom, "Native wheel input must magnify the actual model.")
	_mouse(MOUSE_BUTTON_LEFT, true, at, true)
	_mouse(MOUSE_BUTTON_LEFT, false, at)
	_expect(camera.transform.is_equal_approx(original) and is_equal_approx(camera.size, original_size),
		"Double-click reset must restore the actual authored framing, not just UI counters.")
	viewer.grab_focus()
	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_RIGHT_X
	pad.axis_value = 0.8
	get_root().push_input(pad, true)
	await _settle()
	pad.axis_value = 0.0
	get_root().push_input(pad, true)
	_expect(not camera.transform.is_equal_approx(original),
		"A focused gamepad stick must move the actual camera, even with reduced motion on.")
	screen.call("_reset_view")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = at
	touch.pressed = true
	get_root().push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = at + Vector2(-35, 14)
	drag.relative = Vector2(-35, 14)
	get_root().push_input(drag, true)
	touch.position = drag.position
	touch.pressed = false
	get_root().push_input(touch, true)
	_expect(not camera.transform.is_equal_approx(original),
		"A touch drag must orbit the actual model rather than stop at its private viewport.")
	screen.call("_reset_view")
	values[Settings.REDUCED_MOTION_KEY] = false
	settings.emit_signal("changed", Settings.REDUCED_MOTION_KEY, false)
	var spin_before := camera.transform
	await _settle()
	_expect(not camera.transform.is_equal_approx(spin_before),
		"The shared viewer must advance auto-spin without a second game-owned spin loop.")
	values[Settings.REDUCED_MOTION_KEY] = true
	settings.emit_signal("changed", Settings.REDUCED_MOTION_KEY, true)
	var parked := camera.transform
	await _settle()
	_expect(camera.transform.is_equal_approx(parked),
		"Reduced motion must park the actual camera immediately while retaining manual orbit.")


func _test_visibility(screen: Node) -> void:
	var stage: Control = screen.get("_stage")
	var viewport: SubViewport = stage.get("viewport")
	screen.hide()
	await _settle()
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"A hidden gallery must stop rendering its private 3D world.")
	screen.show()
	await _settle()
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"Returning to the gallery must resume the current original exhibit.")


func _mouse(button: MouseButton, pressed: bool, at: Vector2, double_click := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.double_click = double_click
	event.factor = 1.0
	get_root().push_input(event, true)


func _changed_pixels(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var count := 0
	var step := maxi(1, first.get_width() / 260)
	for y in range(0, first.get_height(), step):
		for x in range(0, first.get_width(), step):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				count += 1
	return count


func _save_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for file in DirAccess.get_files_at("user://"):
		if file.ends_with(".cfg"):
			result[file] = FileAccess.get_file_as_bytes("user://" + file)
	return result


func _capture(image: Image, name: String) -> void:
	if not _capture_directory.is_empty():
		_expect(image.save_png(_capture_directory.path_join(name)) == OK,
			"Could not save requested gallery capture " + name)


func _settle() -> void:
	for frame in 6:
		await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
