extends SceneTree

## Real setup rows must show the current player's original launch, not a
## recorded captain, a voice source or a second cosmetic/gameplay selector.

const Manifest = preload("res://games/sailor_man/game.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const Boat = preload("res://games/sailor_man/world/boat_rig.gd")
const Identity = preload("res://scripts/player_identity.gd")
const Outfit = preload("res://games/sailor_man/world/launch_outfit.gd")

var _failures := PackedStringArray()
var _capture_directory := ""
var _render_cases := 0
var _maximum_draws := 0


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
	var old_mouse := get_root().get_mouse_position()
	get_root().min_size = Vector2i.ZERO
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	GameCatalog.select(Options.GAME_ID)
	var saved := _save_snapshot()
	var buses := AudioServer.bus_count
	var declarations := Options.CHARACTERS.duplicate(true)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-setup-capture-dir="):
			_capture_directory = argument.trim_prefix("--sailor-setup-capture-dir=")
	if not _capture_directory.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
			"Requested setup captures need a writable directory.")
	var manifest := Manifest.manifest()
	_expect(manifest.characters == Options.CHARACTERS and manifest.characters.size() == 1,
		"Setup must declare only the current prototype, not unfinished production captains.")
	var packed := load(manifest.character_preview_scene_path) as PackedScene
	if packed == null:
		printerr("The declared Sailor setup preview could not load.")
		quit(1)
		return
	var probe := packed.instantiate() as Control
	if probe == null or not probe.has_method("configure"):
		printerr("The setup preview must load its configure(Dictionary) script.")
		if probe != null:
			probe.free()
		quit(1)
		return
	probe.free()
	await _test_configuration(packed)
	for standalone in [false, true]:
		if standalone:
			GameCatalog.restrict_to(Options.GAME_ID)
		else:
			GameCatalog.clear_restriction()
			GameCatalog.select(Options.GAME_ID)
		for human in [false, true]:
			var screen := await _open_setup(human)
			await _test_shared_setup(screen, human)
			screen.queue_free()
			await _settle()
	GameCatalog.clear_restriction()
	GameCatalog.select(Options.GAME_ID)
	if DisplayServer.get_name() != "headless":
		await _test_layouts()
		_expect(_render_cases == 25,
			"Native checks must complete every solo/P1/P2 layout and compact Details case.")
	_expect(AudioServer.bus_count == buses, "Setup must never allocate a microphone capture bus.")
	_expect(_save_snapshot() == saved,
		"Preview configuration/focus must not write options, calibration or progress.")
	_expect(Options.CHARACTERS == declarations,
		"Per-seat preview fields must not mutate the canonical character declaration.")
	settings.set("_values", original)
	get_root().min_size = old_minimum
	get_root().size = old_size
	settings.call("_update_content_scale")
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(old_mouse)
	await create_timer(0.15, true, false, true).timeout
	if _failures.is_empty():
		print("Sailor setup preview tests passed (%s, %d layouts, maximum %d draws)." % [
			DisplayServer.get_name(), _render_cases, _maximum_draws,
		])
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_configuration(packed: PackedScene) -> void:
	var preview := packed.instantiate() as Control
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(640, 376)
	preview.call("configure", {
		"id": Options.CHARACTER_ID, "player_index": 1, "player_color": Color.MAGENTA,
		"scene": "res://games/sailor_man/gameplay.tscn", "profile": {"chest_hz": INF},
	})
	get_root().add_child(preview)
	await _settle()
	_assert_model(preview, 1)
	var first: Node3D = preview.get("boat")
	preview.call("configure", {"id": Options.CHARACTER_ID, "player_index": 1})
	_expect(preview.get("boat") == first,
		"Repeated shared-menu refreshes must not rebuild an unchanged player rig.")
	preview.call("configure", {"id": Options.CHARACTER_ID, "player_index": 0})
	await _settle()
	_assert_model(preview, 0)
	_expect(not is_instance_valid(first),
		"A seat change must release the old red model, not accumulate hidden rigs.")
	print("Expected setup-preview rejection diagnostics follow.")
	preview.call("configure", {"id": "unavailable_prototype", "player_index": 0})
	await _settle()
	_assert_rejected(preview)
	preview.call("configure", {"id": Options.CHARACTER_ID, "player_index": 2})
	await _settle()
	_assert_rejected(preview)
	preview.call("configure", {"id": Options.CHARACTER_ID, "player_index": "1"})
	await _settle()
	_assert_rejected(preview)
	preview.call("configure", {"id": Options.CHARACTER_ID, "player_index": 1})
	await _settle()
	_assert_model(preview, 1)
	preview.queue_free()
	await _settle()


func _assert_rejected(preview: Control) -> void:
	var viewport: SubViewport = preview.get("viewport")
	var error: Label = preview.get("_error")
	_expect(preview.get("boat") == null and error.visible and not error.text.is_empty()
		and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"An invalid prototype/seat must show an error, drop old geometry and stop rendering.")


func _assert_model(preview: Control, seat: int) -> void:
	var actual: Node3D = preview.get("boat")
	_expect(actual != null, "A configured player must own a real original launch.")
	if actual == null:
		return
	var expected := Boat.new(seat, "P%d" % (seat + 1))
	_expect(expected.set_outfit(Outfit.equipped(get_root().get_node("Store"), seat)),
		"The reference model must use the featured human's saved outfit.")
	var body: MeshInstance3D = actual.get("body")
	for surface in expected.body.mesh.get_surface_count():
		var first := body.mesh.surface_get_arrays(surface)
		var second := expected.body.mesh.surface_get_arrays(surface)
		for field in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
			_expect(first[field] == second[field],
				"The preview's hull, pennant, crew and paint must be the actual player rig.")
	expected.free()
	var plaque: Label3D = actual.get("plaque")
	_expect(plaque.text == "P%d" % (seat + 1)
		and preview.accessibility_description.contains(plaque.text),
		"The model and accessibility text must name P1/P2, never CPU or colour alone.")
	var viewport: SubViewport = preview.get("viewport")
	_expect(viewport.find_world_3d() != get_root().find_world_3d()
		and viewport.transparent_bg and viewport.gui_disable_input,
		"Setup must keep transparent, isolated Compatibility lighting and no input capture.")
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		_expect(preview.find_children("*", type, true, false).is_empty(),
			"The preview must not create voice, microphone or other audio players.")


func _open_setup(human: bool) -> Node:
	get_root().get_node("GameSession").call("configure_single_player")
	var screen := (load("res://scenes/menus/mode_select.tscn") as PackedScene).instantiate()
	get_root().add_child(screen)
	await _settle()
	var button := screen.get_node(
		"%MultiplayerButton" if human else "%SinglePlayerButton") as Button
	button.pressed.emit()
	await _settle()
	return screen


func _test_shared_setup(screen: Node, human: bool) -> void:
	var cards: Array = screen.get("_player_setup_cards")
	var stage := screen.get_node("%SetupStage") as SetupStage
	var session := get_root().get_node("GameSession")
	var count := 2 if human else 1
	for seat in count:
		var picker := cards[seat]["picker"] as OptionButton
		_expect(picker.item_count == 1 and not picker.is_item_disabled(0)
			and str((session.call("character_for_player", seat) as Dictionary)["id"])
				== Options.CHARACTER_ID,
			"Real solo/hot-seat setup must retain one free prototype per human.")
		picker.grab_focus()
		await _settle()
		var preview := cards[seat]["preview"] as Control
		_assert_model(preview, seat)
		_expect(stage.featured_preview() == preview and preview.is_visible_in_tree()
			and stage.get("_ring_color") == Identity.color(seat),
			"Focusing an actual player row must show that player's launch and identity ring.")
		if human:
			_expect((stage.get_node("Caption") as Label).text.contains(
				Identity.name_for(seat).to_upper()),
				"The hot-seat plinth must also name the featured singer in words.")
		for other in count:
			var other_preview := cards[other]["preview"] as Control
			var viewport: SubViewport = other_preview.get("viewport")
			_expect(viewport.render_target_update_mode == (
				SubViewport.UPDATE_ALWAYS if other == seat else SubViewport.UPDATE_DISABLED),
				"Only the featured player's private viewport may render.")
	var choice := screen.get("_level_choice") as OptionButton
	var preview := stage.featured_preview()
	var original: Node3D = preview.get("boat")
	for index in Arenas.ENTRIES.size():
		choice.select(index)
		choice.item_selected.emit(index)
		_expect(str((session.call("selected_level") as Dictionary)["id"])
			== str(Arenas.ENTRIES[index]["id"]) and preview.get("boat") == original,
			"All five free arenas must still select normally without rebuilding the launch.")
	screen.hide()
	await _settle()
	for card: Dictionary in cards:
		var viewport: SubViewport = (card["preview"] as Control).get("viewport")
		_expect(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"Leaving setup must stop every preview, including its nonfeatured seat.")


func _test_layouts() -> void:
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	for human in [false, true]:
		var screen := await _open_setup(human)
		var cards: Array = screen.get("_player_setup_cards")
		for size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720),
				Vector2i(2560, 1080)]:
			for scale: float in [1.0, 1.5]:
				values["ui/scale"] = scale
				get_root().min_size = Vector2i.ZERO
				get_root().size = size
				Input.warp_mouse(Vector2.ZERO)
				settings.call("_update_content_scale")
				settings.emit_signal("changed", "ui/scale", scale)
				await _settle()
				var label := "%s-%dx%d-ui%.1f" % [
					"human" if human else "solo", size.x, size.y, scale,
				]
				var level := screen.get("_level_choice") as OptionButton
				level.grab_focus()
				await _settle()
				_assert_setup_controls(screen, level, label + "-arena")
				for seat in (2 if human else 1):
					var picker := cards[seat]["picker"] as OptionButton
					picker.grab_focus()
					await _settle()
					var preview := cards[seat]["preview"] as Control
					var seat_label := label + "-p%d" % (seat + 1)
					_assert_setup_controls(screen, picker, seat_label)
					await _assert_render(preview, seat, seat_label)
					_capture(get_root().get_texture().get_image(), seat_label + ".png")
					_render_cases += 1
					if human and seat == 1 and size == Vector2i(320, 568) and scale == 1.5:
						var details := screen.get_node("%DetailsButton") as Button
						details.button_pressed = true
						await _settle()
						picker.grab_focus()
						await _settle()
						_assert_setup_controls(screen, picker, seat_label + "-details")
						await _assert_render(preview, seat, seat_label + "-details")
						_capture(get_root().get_texture().get_image(),
							seat_label + "-details.png")
						_render_cases += 1
						details.button_pressed = false
						await _settle()
		screen.queue_free()
		await _settle()


func _assert_setup_controls(screen: Node, control: Control, label: String) -> void:
	_expect(get_root().gui_get_focus_owner() == control,
		label + ": the actual arena/player picker must retain keyboard focus.")
	var transform := get_root().get_final_transform()
	var window := Rect2(Vector2.ZERO, Vector2(get_root().size)).grow(1.0)
	var start := screen.get_node("%ConfirmButton") as Button
	_expect(window.encloses(transform * start.get_global_rect()),
		label + ": the actual Start button must remain wholly inside the window.")
	var scroll := screen.get_node("%SetupScroll") as ScrollContainer
	var clip := (transform * scroll.get_global_rect()).intersection(window)
	var row := transform * control.get_global_rect()
	_expect(clip.has_point(row.get_center())
		and clip.intersection(row).size.y >= minf(row.size.y, 32.0),
		label + ": focused picker %s must be usable in scroller %s." % [row, clip])


func _assert_render(preview: Control, seat: int, label: String) -> void:
	var viewport: SubViewport = preview.get("viewport")
	var camera: Camera3D = preview.get("camera")
	var boat: Node3D = preview.get("boat")
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-1.0)
	_expect(preview.is_visible_in_tree() and preview.size.x > 8.0 and preview.size.y > 8.0,
		label + ": the real setup must leave usable space for its launch preview.")
	var physical: Rect2 = get_root().get_final_transform() * preview.get_global_rect()
	_expect(Rect2(Vector2.ZERO, Vector2(get_root().size)).grow(1.0).encloses(physical),
		label + ": the plinth must keep the actual preview inside the visible window.")
	var outside := 0
	for point: Vector3 in preview.get("_points"):
		outside += int(camera.is_position_behind(point)
			or not bounds.has_point(camera.unproject_position(point)))
	_expect(outside == 0,
		label + ": complete bow/mast/crew framing lost %d vertices." % outside)
	var draws := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_maximum_draws = maxi(_maximum_draws, draws)
	_expect(draws > 0 and draws < 10, label + ": the original batched launch needs <10 draws.")
	var image := viewport.get_texture().get_image()
	var painted := 0
	var transparent := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			transparent += int(color.a < 0.01)
			if color.a > 0.5 and (color.b > 0.45 and color.b > color.r * 1.2
					if seat == 0 else color.r > 0.55 and color.r > color.b * 1.3):
				painted += 1
	_expect(painted > 3 and transparent > image.get_width(),
		label + ": actual player-colour pixels and transparent surround must render.")
	var mouth: Marker3D = boat.get("mouth")
	_expect(_skin_near(image, camera.unproject_position(mouth.global_position + Vector3.UP * 0.05)),
		label + ": the current crew's face must actually be visible from this seat's lens.")
	var parked := camera.transform
	await _settle()
	_expect(image.get_data() == viewport.get_texture().get_image().get_data()
		and camera.transform.is_equal_approx(parked),
		label + ": setup art must remain static, not bob, spin or depend on a performance.")
	var plaque: Label3D = boat.get("plaque")
	plaque.hide()
	await _settle()
	_expect(_changed_pixels(image, viewport.get_texture().get_image()) > 0,
		label + ": the P1/P2 plaque must actually draw, not only exist as metadata.")
	plaque.show()
	var body: MeshInstance3D = boat.get("body")
	body.hide()
	await _settle()
	_expect(_changed_pixels(image, viewport.get_texture().get_image()) > 5,
		label + ": the actual launch must produce visible pixels on the shared plinth.")
	body.show()
	await _settle()
	_capture(viewport.get_texture().get_image(), label + "-model.png")


func _skin_near(image: Image, at: Vector2) -> bool:
	var radius := maxi(2, roundi(float(image.get_height()) * 0.02))
	for y in range(maxi(0, int(at.y) - radius), mini(image.get_height(), int(at.y) + radius + 1)):
		for x in range(maxi(0, int(at.x) - radius), mini(image.get_width(), int(at.x) + radius + 1)):
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and color.r > 0.25 \
				and color.r > color.g * 1.1 and color.r > color.b * 1.15:
				return true
	return false


func _changed_pixels(first: Image, second: Image) -> int:
	if first.get_size() != second.get_size():
		return 0
	var changed := 0
	for y in range(0, first.get_height(), 2):
		for x in range(0, first.get_width(), 2):
			changed += int(first.get_pixel(x, y) != second.get_pixel(x, y))
	return changed


func _save_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for file in DirAccess.get_files_at("user://"):
		if file.ends_with(".cfg"):
			result[file] = FileAccess.get_file_as_bytes("user://" + file)
	return result


func _capture(image: Image, name: String) -> void:
	if not _capture_directory.is_empty():
		_expect(image.save_png(_capture_directory.path_join(name)) == OK,
			"Could not save requested setup inspection " + name)


func _settle() -> void:
	for frame in 8:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
