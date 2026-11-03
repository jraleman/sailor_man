extends SceneTree

## Actual purchase/equip controls, batched rigs and frozen views guard the
## prototype shop. Native runs also compare every advertised cosmetic's pixels.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Manifest = preload("res://games/sailor_man/game.gd")
const Outfit = preload("res://games/sailor_man/world/launch_outfit.gd")
const Boat = preload("res://games/sailor_man/world/boat_rig.gd")
const Identity = preload("res://scripts/player_identity.gd")
const P1_OUTFIT := {
	"hat": "hat_deck_cap", "pennant": "pennant_stripes",
	"paint": "paint_cream_band", "bow": "bow_fish",
}
const P2_OUTFIT := {
	"hat": "hat_sun_hat", "pennant": "pennant_bunting",
	"paint": "paint_deep_hull", "bow": "bow_star",
}

var _failures := PackedStringArray()
var _store: Node
var _settings: Node
var _original_state: Dictionary = {}
var _saved_store := PackedByteArray()
var _had_store := false
var _model_checks := 0
var _preview_checks := 0
var _layout_checks := 0
var _maximum_draws := 0
var _capture_directory := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_store = get_root().get_node("Store")
	_settings = get_root().get_node("Settings")
	for key: String in ["_points", "_owned", "_equipped"]:
		_original_state[key] = (_store.get(key) as Dictionary).duplicate(true)
	_had_store = FileAccess.file_exists(Store.SAVE_PATH)
	if _had_store:
		_saved_store = FileAccess.get_file_as_bytes(Store.SAVE_PATH)
	var saved := _non_store_files()
	var original: Dictionary = _settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values["ui/scale"] = 1.0
	values[Settings.REDUCED_MOTION_KEY] = true
	values[Options.INPUT_SOURCE_KEY] = Options.InputSource.REMO
	_settings.set("_values", values)
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	var old_mouse := get_root().get_mouse_position()
	get_root().min_size = Vector2i.ZERO
	get_root().size = Vector2i(1280, 720)
	_settings.call("_update_content_scale")
	GameCatalog.select(Options.GAME_ID)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-store-capture-dir="):
			_capture_directory = argument.trim_prefix("--sailor-store-capture-dir=")
	if not _capture_directory.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
			"Requested store captures need a writable directory.")
	var other: Dictionary = _store.call("export_save", "chicken_pit")
	var buses := AudioServer.bus_count
	_expect(_store.call("erase_save", Options.GAME_ID) == OK,
		"The isolated shop must be able to reset only its own fixture.")
	_test_models()
	await _test_purchases()
	_test_reload()
	await _test_previews()
	await _test_views()
	if DisplayServer.get_name() != "headless":
		await _test_layouts()
		_expect(_layout_checks == 8, "Every native store size/UI case must complete.")
	_expect(_model_checks == 24 and _preview_checks == (
		12 if DisplayServer.get_name() == "headless" else 24),
		"Every declared cosmetic must exercise both rigs and every shelf aspect.")
	_expect(_store.call("export_save", "chicken_pit") == other,
		"Buying/equipping Sailor cosmetics must leave another game's wallet and outfit alone.")
	_expect(_non_store_files() == saved,
		"Shop presentation must not write options, voice profiles or achievements.")
	await create_timer(0.15, true, false, true).timeout
	_expect(AudioServer.bus_count == buses, "The shop must not allocate microphone buses.")
	for key: String in _original_state:
		_store.set(key, _original_state[key])
	if _had_store:
		var file := FileAccess.open(Store.SAVE_PATH, FileAccess.WRITE)
		_expect(file != null, "The original store file must be restorable.")
		if file != null:
			file.store_buffer(_saved_store)
			file.close()
	else:
		_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_PATH)) == OK,
			"The fixture's store file must be removed when none existed before.")
	_settings.set("_values", original)
	get_root().min_size = old_minimum
	get_root().size = old_size
	_settings.call("_update_content_scale")
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(old_mouse)
	if _failures.is_empty():
		print("Sailor store tests passed (%s, %d rigs, %d previews, %d layouts, %d draws)." % [
			DisplayServer.get_name(), _model_checks, _preview_checks, _layout_checks,
			_maximum_draws,
		])
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_models() -> void:
	for seat in 2:
		var boat := Boat.new(seat, "P%d" % (seat + 1))
		var plain := boat.body.mesh
		var mouth := boat.mouth
		for item: Dictionary in Options.STORE_ITEMS:
			var selected := {str(item["kind"]): str(item["id"])}
			_expect(boat.set_outfit(selected), "Every advertised item must build on either seat.")
			var arrays := boat.body.mesh.surface_get_arrays(0)
			var original := plain.surface_get_arrays(0)
			var same: bool = arrays[Mesh.ARRAY_VERTEX] == original[Mesh.ARRAY_VERTEX] \
				and arrays[Mesh.ARRAY_COLOR] == original[Mesh.ARRAY_COLOR]
			_expect(same == bool(item.get("default", false)),
				"Defaults must remain the original model; every purchased item must change it.")
			_expect(boat.body.mesh.get_surface_count() == 1 and boat.mouth == mouth
				and boat.mouth.position == Vector3(0.21 if seat == 0 else -0.21, 1.13, -0.79)
				and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).has(Identity.color(seat))
				and boat.plaque.text == "P%d" % (seat + 1),
				"Cosmetics must keep one surface, the real voice anchor and blue/red/tag identity.")
			boat.set_outfit({})
			_model_checks += 1
		print("Expected launch-outfit rejection diagnostics follow.")
		var previous := boat.body.mesh
		_expect(not boat.set_outfit({"hat": "bow_fish"}) and boat.body.mesh == previous,
			"A mismatched kind must fail without replacing the last valid surface.")
		_expect(not boat.set_outfit({"profile": {"chest_hz": 180.0}}),
			"A rig must reject voice/profile fields, not retain them as cosmetics.")
		boat.free()


func _test_purchases() -> void:
	var screen := await _open_store()
	var cap := _card(screen, "hat_deck_cap")
	_expect((cap.get("_buy_button") as Button).disabled
		and not bool(_store.call("purchase", Options.GAME_ID, "hat_deck_cap")),
		"An empty wallet must not buy or equip a paid cap.")
	_store.call("add_points", Options.GAME_ID, 60)
	await _settle()
	cap = _card(screen, "hat_deck_cap")
	(cap.get("_buy_button") as Button).pressed.emit()
	await _settle()
	_expect(int(_store.call("points", Options.GAME_ID)) == 52
		and _store.call("equipped_id", Options.GAME_ID, "p1_hat") == "hat_deck_cap"
		and _store.call("equipped_id", Options.GAME_ID, "p2_hat") == "hat_none",
		"The real Buy action must spend once and dress the first free human slot.")
	var sun := _card(screen, "hat_sun_hat")
	(sun.get("_buy_button") as Button).pressed.emit()
	await _settle()
	_expect(int(_store.call("points", Options.GAME_ID)) == 40
		and _store.call("equipped_id", Options.GAME_ID, "p1_hat") == "hat_deck_cap"
		and _store.call("equipped_id", Options.GAME_ID, "p2_hat") == "hat_sun_hat",
		"A second purchased hat must prefer P2 without undressing P1.")
	cap = _card(screen, "hat_deck_cap")
	(cap.get_node("Layout/Actions/Slot_p2_hat") as Button).pressed.emit()
	await _settle()
	_expect(_store.call("equipped_id", Options.GAME_ID, "p2_hat") == "hat_deck_cap"
		and int(_store.call("points", Options.GAME_ID)) == 40
		and not bool(_store.call("purchase", Options.GAME_ID, "hat_deck_cap")),
		"One purchased item may dress either/both seats without another charge.")
	_store.call("add_points", Options.GAME_ID, 100)
	for item: Dictionary in Options.STORE_ITEMS:
		if not bool(_store.call("is_owned", Options.GAME_ID, item["id"])):
			_expect(bool(_store.call("purchase", Options.GAME_ID, item["id"])),
				"A funded prototype must be buyable, with no unimplemented campaign gate.")
	var balance := int(_store.call("points", Options.GAME_ID))
	_expect(not bool(_store.call("equip", Options.GAME_ID, "bow_fish", "p2_hat"))
		and not bool(_store.call("equip", Options.GAME_ID, "hat_deck_cap", "cpu_hat"))
		and int(_store.call("points", Options.GAME_ID)) == balance,
		"Wrong-kind/CPU slots must be refused without spending.")
	_equip(0, P1_OUTFIT)
	_equip(1, P2_OUTFIT)
	await _settle()
	for item: Dictionary in Options.STORE_ITEMS:
		var card := _card(screen, str(item["id"]))
		_expect((card.get("_slot_buttons") as Array).size() == 2,
			"Every owned item must expose its actual P1 and P2 destination buttons.")
	screen.queue_free()
	await _settle()


func _test_reload() -> void:
	var expected: Dictionary = _store.call("export_save", Options.GAME_ID)
	(_store.get("_points") as Dictionary)[Options.GAME_ID] = 0
	(_store.get("_owned") as Dictionary)[Options.GAME_ID] = {}
	(_store.get("_equipped") as Dictionary)[Options.GAME_ID] = {}
	_store.call("_load_state")
	_expect(_store.call("export_save", Options.GAME_ID) == expected
		and Outfit.equipped(_store, 0) == P1_OUTFIT and Outfit.equipped(_store, 1) == P2_OUTFIT,
		"A fresh load must recover the wallet, ownership and all eight independent slots.")


func _test_previews() -> void:
	var packed := load(Manifest.manifest().store_preview_scene_path) as PackedScene
	if packed == null:
		_expect(false, "The manifest's store preview must load.")
		return
	var preview := packed.instantiate() as Control
	_expect(preview != null and preview.has_method("configure"),
		"The shelf must load its real preview script, not just a bare Control.")
	if preview == null or not preview.has_method("configure"):
		if preview != null:
			preview.free()
		return
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(284, 176)
	preview.call("configure", {"id": "hat_deck_cap"})
	get_root().add_child(preview)
	await _settle()
	var sizes: Array[Vector2] = [Vector2(284, 176)]
	if DisplayServer.get_name() != "headless":
		sizes.append(Vector2(550, 176))
	for size in sizes:
		preview.size = size
		var baseline: Image
		for item: Dictionary in Options.STORE_ITEMS:
			var original: Node3D = preview.get("boat")
			preview.call("configure", {"id": item["id"], "kind": "injected",
				"player_index": 1, "color": Color.MAGENTA, "profile": {"chest_hz": INF}})
			await _settle()
			_expect(preview.get("boat") == original,
				"Changing a shelf item must reuse its one rig, not accumulate launches.")
			_assert_rig(preview.get("boat"), 0, {str(item["kind"]): str(item["id"])})
			if DisplayServer.get_name() != "headless":
				preview.call("set_preview_running", false)
				await RenderingServer.frame_post_draw
				var image := _assert_render(preview)
				if bool(item.get("default", false)) and baseline == null:
					baseline = image
				if not bool(item.get("default", false)) and image != null and baseline != null:
					_expect(image.get_data() != baseline.get_data(),
						"Every advertised paid item must actually change the rendered pixels.")
				_capture(image, "%s-%d.png" % [item["id"], int(size.x)])
			_preview_checks += 1
	preview.hide()
	preview.call("configure", {"id": "bow_fish"})
	await _settle()
	var viewport: SubViewport = preview.get("viewport")
	_expect(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Hidden shelf artwork must not render even while its item changes.")
	preview.show()
	await _settle()
	print("Expected store-preview rejection diagnostics follow.")
	preview.call("configure", {"id": "unreviewed_or_unknown"})
	await _settle()
	_expect(preview.get("boat") == null and (preview.get("_error") as Label).visible
		and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"An unknown item must clear the previous advert and fail visibly.")
	preview.call("configure", {"id": "bow_star"})
	await _settle()
	_assert_rig(preview.get("boat"), 0, {"bow": "bow_star"})
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		_expect(preview.find_children("*", type, true, false).is_empty(),
			"The shelf cannot create voices, microphone capture or sound effects.")
	preview.queue_free()
	await _settle()


func _test_views() -> void:
	var session := get_root().get_node("GameSession")
	session.call("configure_multiplayer", 0)
	var game := (load("res://games/sailor_man/gameplay.tscn") as PackedScene).instantiate()
	game.set("voice_profile_path", "user://sailor_store_unwritten_%d.cfg" % OS.get_process_id())
	get_root().add_child(game)
	await _settle()
	game.set_process(false)
	var canal: Control = (game.get_node("%DuelHud") as Control).get("lock")
	for seat in 2:
		_assert_rig(canal.get("boats")[seat], seat, P1_OUTFIT if seat == 0 else P2_OUTFIT)
		if DisplayServer.get_name() != "headless":
			_assert_launch_frame(canal.get("viewport"), canal.get("camera"),
				canal.get("boats")[seat])
	var preview := (load(Manifest.manifest().character_preview_scene_path)
		as PackedScene).instantiate() as Control
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.call("configure", {"id": Options.CHARACTER_ID, "player_index": 1})
	preview.size = Vector2(640, 376)
	get_root().add_child(preview)
	await _settle()
	_assert_rig(preview.get("boat"), 1, P2_OUTFIT)
	if DisplayServer.get_name() != "headless":
		_capture(_assert_render(preview), "p2-setup-outfit.png")
	var stage := (load(Manifest.manifest().gallery_stage_scene_path)
		as PackedScene).instantiate() as Control
	stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stage.call("configure", {"id": "hot_seat"})
	stage.size = Vector2(640, 376)
	get_root().add_child(stage)
	await _settle()
	for seat in 2:
		var launch := (stage.get("_models") as Node).get_node("Launch%d" % (seat + 1))
		_assert_rig(launch, seat, P1_OUTFIT if seat == 0 else P2_OUTFIT)
		if DisplayServer.get_name() != "headless":
			_assert_launch_frame(stage.get("viewport"), stage.get("camera"), launch)
	if DisplayServer.get_name() != "headless":
		_capture((stage.get("viewport") as SubViewport).get_texture().get_image(),
			"gallery-outfits.png")
	stage.call("set_view", 0.3, -0.1, 1.0)
	game.call("_finish_round")
	var frozen: Dictionary = game.call("_share_payload")
	_expect(frozen["sailor_outfits"] == [P1_OUTFIT, P2_OUTFIT],
		"Finished share data must freeze both actual human outfits, not store references.")
	var rig: Node3D = preview.get("boat")
	_store.call("equip", Options.GAME_ID, "hat_none", "p1_hat")
	await _settle()
	_expect(preview.get("boat") == rig and _store.call("equipped_id",
		Options.GAME_ID, "p2_hat") == "hat_sun_hat",
		"Changing P1 must not rebuild P2's featured model or alter their equipment.")
	_expect(game.call("_share_payload")["sailor_outfits"] == frozen["sailor_outfits"]
		and is_equal_approx(float(stage.get("_yaw")), 0.3),
		"Later purchases/equips must not rewrite the finished card or reset gallery orbit.")
	var art := (load(Manifest.manifest().share_art_scene_path)
		as PackedScene).instantiate() as Control
	art.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	art.call("configure", frozen)
	art.size = Vector2(400, 560)
	get_root().add_child(art)
	await _settle()
	for seat in 2:
		var portrait: Dictionary = art.get("portraits")[seat]
		_assert_rig(portrait["boat"], seat, P1_OUTFIT if seat == 0 else P2_OUTFIT)
		if DisplayServer.get_name() != "headless":
			_assert_launch_frame(portrait["viewport"], portrait["camera"], portrait["boat"])
			_capture((portrait["viewport"] as SubViewport).get_texture().get_image(),
				"p%d-share-outfit.png" % (seat + 1))
	_expect(art.get("_outfits") == [P1_OUTFIT, P2_OUTFIT],
		"Share art must read the frozen ids even when live equipment differs.")
	print("Expected share-outfit rejection diagnostics follow.")
	art.call("configure", {"sailor_outfits": [{"hat": "unknown_hat"}]})
	await _settle()
	_expect((art.get("portraits") as Array).is_empty(),
		"An invalid share outfit must drop old portraits, not silently draw a default.")
	print("Expected damaged-equipment rejection diagnostics follow.")
	(_store.get("_equipped") as Dictionary)[Options.GAME_ID]["p2_hat"] = "bow_fish"
	_store.emit_signal("equipped_changed", Options.GAME_ID, "p2_hat", "bow_fish")
	await _settle()
	var viewport: SubViewport = preview.get("viewport")
	_expect(preview.get("boat") == null and (preview.get("_error") as Label).visible
		and not (viewport.get_parent() as Control).visible
		and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Damaged saved equipment must hide stale artwork and explain the failure.")
	_expect((stage.get("_error") as Label).visible
		and (stage.get("viewport") as SubViewport).render_target_update_mode
			== SubViewport.UPDATE_DISABLED,
		"A gallery must not quietly substitute a plain outfit for damaged equipment.")
	_store.call("equip", Options.GAME_ID, "hat_sun_hat", "p2_hat")
	await _settle()
	_assert_rig(preview.get("boat"), 1, P2_OUTFIT)
	_expect(not (stage.get("_error") as Label).visible,
		"A valid equipment change must recover previews without switching seats/exhibits.")
	session.call("configure_single_player")
	game.call("_return_to_duel")
	_assert_rig(canal.get("boats")[1], 1, {})
	_expect((canal.get("boats")[1].get("plaque") as Label3D).text == "CPU"
		and (game.call("_share_payload")["sailor_outfits"] as Array).size() == 1,
		"Solo must ignore P2's saved outfit and never create a human portrait for the skiff.")
	for control: Control in [preview, stage, art]:
		control.queue_free()
	game.queue_free()
	await _settle()
	_equip(0, P1_OUTFIT)


func _test_layouts() -> void:
	var screen := await _open_store()
	var scroll := screen.get_node("%Sections").get_parent().get_parent() as ScrollContainer
	for size in [Vector2i(320, 568), Vector2i(568, 320),
		Vector2i(1280, 720), Vector2i(2560, 1080)]:
		for scale: float in [1.0, 1.5]:
			(_settings.get("_values") as Dictionary)["ui/scale"] = scale
			get_root().size = size
			_settings.call("_update_content_scale")
			_settings.emit_signal("changed", "ui/scale", scale)
			Input.warp_mouse(Vector2.ZERO)
			await _settle()
			var window := Rect2(Vector2.ZERO, Vector2(size))
			var transform := get_root().get_final_transform()
			_expect(window.encloses(transform * (
				screen.get_node("%BackButton") as Control).get_global_rect()),
				"Store Back must remain reachable at %s / %.1f UI." % [size, scale])
			for id: String in ["hat_deck_cap", "pennant_stripes",
				"paint_cream_band", "bow_fish"]:
				var card := _card(screen, id)
				var buttons: Array = card.get("_slot_buttons")
				var target := buttons[1] as Button
				scroll.ensure_control_visible(target)
				target.grab_focus()
				await _settle()
				var clip := transform * scroll.get_global_rect()
				var rect := transform * target.get_global_rect()
				# Integer scrolling can leave a fractional physical pixel at the edge.
				_expect(get_root().gui_get_focus_owner() == target
					and window.encloses(rect) and clip.grow(0.5).encloses(rect),
					"P2 %s must stay focused/reachable at %s / %.1f: %s in %s, window %s." % [
						id, size, scale, rect, clip, window])
			_capture(get_root().get_texture().get_image(),
				"shop-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
			_layout_checks += 1
	screen.queue_free()
	await _settle()


func _open_store() -> Node:
	var screen := (load("res://scenes/menus/store.tscn") as PackedScene).instantiate()
	screen.set("game_context_id", Options.GAME_ID)
	get_root().add_child(screen)
	await _settle()
	_expect((screen.get("_cards") as Array).size() == Options.STORE_ITEMS.size(),
		"The shared shelf must expose the whole declared prototype catalogue.")
	return screen


func _card(screen: Node, id: String) -> StoreItemCard:
	for card: StoreItemCard in screen.get("_cards"):
		if card.item_id() == id:
			return card
	_expect(false, "Missing actual store card: " + id)
	return null


func _equip(seat: int, outfit: Dictionary) -> void:
	for kind: String in outfit:
		var slot := "p%d_%s" % [seat + 1, kind]
		if _store.call("equipped_id", Options.GAME_ID, slot) != outfit[kind]:
			_expect(bool(_store.call("equip", Options.GAME_ID, outfit[kind], slot)),
				"A purchased outfit must be wearable in its human slot.")


func _assert_rig(actual: Boat, seat: int, outfit: Dictionary) -> void:
	_expect(actual != null, "A view must retain its actual launch script.")
	if actual == null:
		return
	var expected := Boat.new(seat, "P%d" % (seat + 1))
	expected.set_outfit(outfit)
	var first := actual.body.mesh.surface_get_arrays(0)
	var second := expected.body.mesh.surface_get_arrays(0)
	for field in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
		_expect(first[field] == second[field],
			"Every view must use the exact actual equipped hull/crew/ornament surface.")
	_expect(actual.outfit == Outfit.complete(outfit), "Views need independent canonical ids.")
	expected.free()


func _assert_render(preview: Control) -> Image:
	var viewport: SubViewport = preview.get("viewport")
	var camera: Camera3D = preview.get("camera")
	var boat: Boat = preview.get("boat")
	var image := viewport.get_texture().get_image()
	_expect(image != null and not image.is_invisible(),
		"Native wardrobe checks need actual rendered pixels, not just scene geometry.")
	if image == null:
		return null
	var draws := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_maximum_draws = maxi(_maximum_draws, draws)
	_expect(draws < 10, "A batched cosmetic preview must stay below ten draws.")
	_assert_launch_frame(viewport, camera, boat)
	return image


func _assert_launch_frame(viewport: SubViewport, camera: Camera3D, boat: Boat) -> void:
	var image := viewport.get_texture().get_image()
	_expect(image != null and not image.is_invisible(),
		"Equipped launches must produce actual pixels in match, gallery and share views.")
	var frame := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-2.0)
	var vertices: PackedVector3Array = boat.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		var point := boat.to_global(vertex)
		_expect(not camera.is_position_behind(point)
			and frame.has_point(camera.unproject_position(point)),
			"Actual hats, flags, hull and bow geometry must remain completely framed.")


func _non_store_files() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["user://settings.cfg", "user://achievements.cfg",
		"user://sailor_man_voice.cfg"]:
		result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result


func _capture(image: Image, name: String) -> void:
	if image != null and not _capture_directory.is_empty():
		_expect(image.save_png(_capture_directory.path_join(name)) == OK,
			"Requested original-model captures must save explicitly.")


func _settle() -> void:
	for _frame in 5:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
