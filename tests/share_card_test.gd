extends SceneTree

## Actual Remo rounds feed the shared renderer, not invented scored tracks.
## Windowed checks guard frozen portraits, readable cards and preview-only storage.

const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const CARD = preload("res://ui/components/share_card.tscn")

var _failures := PackedStringArray()
var _captures: Array[Dictionary] = []
var _capture_directory := ""
var _test_save := false
var _maximum_draws := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Sailor share card tests require a real graphics window, not --headless.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-share-capture-dir="):
			_capture_directory = argument.trim_prefix("--sailor-share-capture-dir=")
		elif argument == "--sailor-test-save":
			_test_save = true
	if not _capture_directory.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
			"The share capture directory must be writable.")
	GameCatalog.select(Options.GAME_ID)
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	for option: Dictionary in Options.TUNABLES:
		values[option["key"]] = option["default"]
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		values[binding["key"]] = binding["default"]
	values["ui/scale"] = 1.0
	settings.set("_values", values)
	var old_size := get_root().size
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	var session := get_root().get_node("GameSession")
	session.call("configure_single_player")
	session.call("set_level", Arenas.GATUN)
	var scene := load("res://games/sailor_man/gameplay.tscn") as PackedScene
	var game := scene.instantiate()
	game.set("voice_profile_path", "user://sailor_share_unwritten_%d.cfg" % OS.get_process_id())
	get_root().add_child(game)
	await _settle()
	game.set_process(false)
	game.call("_set_reduced_motion_enabled", true)
	game.call("_set_intense_effects_enabled", false)
	var samples: Array[Dictionary] = []
	for entry: Dictionary in [
		{"name": "skiff-win", "arena": Arenas.GATUN, "mode": "solo", "winner": 0},
		{"name": "skiff-silent-loss", "arena": Arenas.LAKE, "mode": "silent", "winner": 1},
		{"name": "human-p1", "arena": Arenas.PEDRO_MIGUEL, "mode": "human", "winner": 0},
		{"name": "human-p2-pacific", "arena": Arenas.PACIFIC, "mode": "human", "winner": 1},
		{"name": "human-decider", "arena": Arenas.CULEBRA, "mode": "decider", "winner": 0},
		{"name": "echo-win", "arena": Arenas.CULEBRA, "mode": "echo", "winner": 0},
		{"name": "incomplete", "arena": Arenas.GATUN, "mode": "empty", "winner": -1},
		{"name": "scorer", "arena": Arenas.GATUN, "mode": "scorer", "winner": -1},
	]:
		var human := str(entry["mode"]) in ["human", "decider"]
		session.call("configure_multiplayer", 0) if human else \
			session.call("configure_single_player")
		session.call("set_level", entry["arena"])
		game.call("_return_to_duel")
		_play_round(game, str(entry["mode"]), int(entry["winner"]))
		var data: Dictionary = game.call("_share_payload")
		samples.append({"name": entry["name"], "data": data})
		if entry["name"] == "human-p2-pacific":
			await _test_inline_preview(game, data)
		var turns: Array = data["sailor_art"]
		_expect(turns.size() == (2 if human else 1),
			"Only actual humans may own share portraits, including losses and self-echo.")
	game.queue_free()
	await _settle()
	GameCatalog.select("desk_can_saw")
	var maxima: Dictionary = samples[3]["data"].duplicate(true)
	maxima["score"] = "150 - 150"
	maxima["accuracy"] = "100.0 / 100.0"
	maxima["combo"] = "9.00 / 9.00"
	for turn: Dictionary in maxima["sailor_art"]:
		turn["paddles"] = PackedInt32Array([10, 10, 10, 10, 10])
	samples.append({"name": "view-maxima", "data": maxima})
	for sample: Dictionary in samples:
		await _test_card(sample["data"], str(sample["name"]))
	await _test_reconfigure(samples[2]["data"], samples[0]["data"])
	var manager := get_root().get_node("ShareManager")
	var invalid: Dictionary = samples[0]["data"].duplicate(true)
	invalid["stats_url"] = "invalid-target"
	var refused: Dictionary = await manager.call("preview_score_image", invalid)
	_expect(not bool(refused["ok"]) and not str(refused["message"]).is_empty(),
		"An invalid target must fail explicitly rather than silently switching to the homepage.")
	if not _capture_directory.is_empty():
		var report := FileAccess.open(
			_capture_directory.path_join("share-captures.json"), FileAccess.WRITE)
		_expect(report != null, "The sanitized share capture report must be writable.")
		if report != null:
			report.store_string(JSON.stringify(_captures, "\t"))
			report.close()
	GameCatalog.select(Options.GAME_ID)
	settings.set("_values", original)
	settings.call("save")
	get_root().size = old_size
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	await create_timer(0.1, true, false, true).timeout
	if _failures.is_empty():
		print("Sailor share card tests passed (%s, %d cards, maximum %d portrait draws)." % [
			DisplayServer.get_name(), samples.size(), _maximum_draws])
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _play_round(game: Node, mode: String, winner: int) -> void:
	var spike := game.get_node("%ScorerSpike")
	var duel: Duel = game.get("_duel")
	if mode == "scorer":
		game.call("_open_practice")
		spike.call("load_example", true)
		game.call("_end_round")
		return
	if mode == "empty":
		game.call("_end_round")
		return
	if mode == "echo":
		game.call("_on_echo_requested")
	var steps := 0
	while duel.phase != Duel.Phase.COMPLETE and steps < 32:
		steps += 1
		match duel.phase:
			Duel.Phase.READY, Duel.Phase.REVIEW:
				game.call("_on_duel_action")
			Duel.Phase.ECHO_WAIT:
				game.call("_update_round", Duel.ECHO_DELAY, 0.0)
			Duel.Phase.RIVAL:
				var frames: Array = game.get("_rival")["frames"]
				game.call("_update_round", float(frames.size()) * 0.01 + 0.01, 0.0)
			Duel.Phase.PLAYER_READY:
				game.call("_on_source_requested", false)
				game.call("_on_duel_action")
				game.call("_update_round", Duel.TAIL_SECONDS, 0.0)
				if duel.preparing_seed:
					_draw_turn(game, false)
				elif mode == "silent":
					game.call("_update_round", 0.2, 0.0)
					spike.call("finish_duel_turn")
				else:
					var strong := duel.singer == winner if duel.hot_seat else winner == 0
					if mode == "decider":
						strong = duel.singer == (1 if duel.tanda == 2 else 0)
					_draw_turn(game, strong)
			_:
				_expect(false, "A share fixture must stay on the actual guarded input path.")
				break
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.winner == winner,
		"Actual input must produce the requested share outcome for %s." % mode)
	if mode == "decider":
		_expect(duel.tandas.size() == 3 and duel.wins[0] == 2 and duel.wins[1] == 1,
			"The decider portrait must come from a real six-turn 2-1 human match.")
	game.call("_on_duel_action")


func _draw_turn(game: Node, strong: bool) -> void:
	_key(KEY_SPACE)
	game.call("_update_round", 1.2 if strong else 0.5, 0.0)
	if strong:
		for _break in 3:
			_key(KEY_J)
			game.call("_update_round", 0.04, 0.0)
			_key(KEY_J, false)
			game.call("_update_round", 1.2, 0.0)
	_key(KEY_K)
	game.call("_update_round", 0.12, 0.0)
	_key(KEY_K, false)
	_key(KEY_SPACE, false)


func _test_inline_preview(game: Node, data: Dictionary) -> void:
	var before := _share_files()
	game.call("_on_see_score_pressed")
	await _settle()
	var texture: Texture2D = game.get("_share_card_preview").texture
	_expect(texture != null and _share_files() == before,
		"The shell's scorecard must preview the actual artwork without writing a PNG.")
	if texture == null:
		return
	var image := texture.get_image()
	_expect(image.get_size() == Vector2i(1200, 630),
		"The inline image must be the full-size shared card, not a different UI summary.")
	if not _test_save:
		return
	await game.call("_on_share_pressed")
	var path := str(game.get("_saved_image_path"))
	_expect(not path.is_empty() and FileAccess.file_exists(path),
		"Explicit Save Image must persist the PNG through the existing shell action.")
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var saved := Image.load_from_file(path)
	_expect(saved != null and saved.get_data() == image.get_data(),
		"Explicit Save and preview must render identical frozen two-human artwork.")
	_expect(_share_files().size() == before.size() + 1
		and (game.get("_open_image_button") as Button).visible,
		"Save must produce only one PNG and retain the existing Open Image action.")
	var manager := get_root().get_node("ShareManager")
	var result: Dictionary = await manager.call("preview_score_image", data)
	_expect(bool(result["ok"]) and not bool(result["stored"])
		and result["texture"].get_image().get_data() == saved.get_data(),
		"Direct preview, shell preview and saved PNG must agree about the same round.")
	_expect(DirAccess.remove_absolute(path) == OK,
		"The isolated Save test must remove only the specific PNG it created.")


func _test_card(data: Dictionary, name: String) -> void:
	var manager := get_root().get_node("ShareManager")
	var prepared: Dictionary = manager.call("_prepare_card_data", data)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 630)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var card := CARD.instantiate() as Control
	viewport.add_child(card)
	card.call("configure", prepared["data"])
	await _settle()
	var bounds := card.get_global_rect().grow(0.5)
	for node in card.find_children("*", "Control", true, false):
		var control := node as Control
		_expect(bounds.encloses(control.get_global_rect()),
			"%s: card content must fit the export (%s, %s; card %s)." % [
				name, card.get_path_to(control), control.get_global_rect(), bounds])
	for node_name in ["Score", "Accuracy", "Hits", "Combo"]:
		var label := card.get_node("%" + node_name) as Label
		_expect(label.get_theme_font_size("font_size") >= 26,
			"%s: primary statistics must remain readable at half size." % name)
	_expect((card.get_node("%GameTitle") as Label).text == "SAILOR MAN"
		and (card.get_node("%InfoTitle") as Label).text == "DISCOVER MORE GAMES"
		and (card.get_node("%Website") as Label).text == "deskcansaw.com",
		"The result's manifest must brand the card even while another game is selected.")
	var art := card.get_node("%ActionArt") as Control
	await _assert_portraits(art, data, name)
	var image := viewport.get_texture().get_image()
	await _settle()
	_expect(image.get_data() == viewport.get_texture().get_image().get_data(),
		"%s: score art must not depend on an animation phase." % name)
	art.hide()
	await _settle()
	for portrait: Dictionary in art.get("portraits"):
		_expect(portrait["viewport"].render_target_update_mode == SubViewport.UPDATE_DISABLED,
			"Hidden score artwork must stop rendering its private 3D viewports.")
	art.show()
	await _settle()
	if not _capture_directory.is_empty():
		_capture(card, viewport.get_texture().get_image(), name, str(data["stats_url"]))
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	await _settle()


func _assert_portraits(art: Control, data: Dictionary, name: String) -> void:
	var portraits: Array = art.get("portraits")
	var turns: Array = data["sailor_art"]
	_expect(portraits.size() == turns.size(),
		"%s: every human must have their own portrait, not a winner-only replacement." % name)
	for singer in portraits.size():
		var portrait: Dictionary = portraits[singer]
		var viewport: SubViewport = portrait["viewport"]
		var camera: Camera3D = portrait["camera"]
		var boat: Node3D = portrait["boat"]
		var image := viewport.get_texture().get_image()
		var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-2.0)
		_expect(viewport.find_world_3d() != get_root().find_world_3d()
			and (boat.get("plaque") as Label3D).text == "P%d" % (singer + 1),
			"Portrait lighting must be isolated and every boat must carry its actual seat label.")
		var draws := viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		_maximum_draws = maxi(_maximum_draws, draws)
		_expect(draws > 0 and draws < 20, "A parked launch must render within a small draw budget.")
		for mesh: MeshInstance3D in portrait["meshes"]:
			if mesh.mesh == null:
				continue
			for corner in 8:
				var point := mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
				_expect(not camera.is_position_behind(point)
					and bounds.has_point(camera.unproject_position(point)),
					"%s: the complete boat/ribbon must remain inside its portrait." % name)
		for label in art.find_children("*", "Label", true, false):
			_expect((label as Label).get_minimum_size().x <= art.size.x,
				"Even five perfect paddles must fit without clipping a singer's caption.")
		var paint := 0
		for y in range(0, image.get_height(), 2):
			for x in range(0, image.get_width(), 2):
				var pixel := image.get_pixel(x, y)
				paint += int(pixel.b > pixel.r * 1.25 and pixel.b > pixel.g * 1.1) \
					if singer == 0 else \
					int(pixel.r > pixel.b * 1.35 and pixel.r > pixel.g * 1.25)
		_expect(paint >= 12, "%s: each launch must really render its distinct player paint." % name)
		var ribbon: MeshInstance3D = portrait["ribbon"]
		_expect(ribbon.mesh == turns[singer].get("mesh"),
			"The renderer must use the frozen scored mesh without reconstructing a pitch track.")
		if ribbon.mesh != null:
			ribbon.hide()
			await _settle()
			var without := viewport.get_texture().get_image()
			var changed := 0
			var gold := 0
			for y in image.get_height():
				for x in image.get_width():
					var a := image.get_pixel(x, y)
					var b := without.get_pixel(x, y)
					var differs := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.1
					changed += int(differs)
					gold += int(differs and a.r > 0.7 and a.g > 0.45 and a.b < 0.4)
			_expect(changed >= 8,
				"%s: even a short flat best turn must render, not hide behind the boat." % name)
			_expect(gold >= 4,
				"%s: the scored contour must expose its gold face, not only its dark back." % name)
			ribbon.show()
			await _settle()


func _test_reconfigure(human: Dictionary, solo: Dictionary) -> void:
	var manager := get_root().get_node("ShareManager")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 630)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	get_root().add_child(viewport)
	var card := CARD.instantiate() as Control
	viewport.add_child(card)
	var other := solo.duplicate(true)
	other["game_id"] = "desk_can_saw"
	for data: Dictionary in [human, solo, human, other, solo]:
		var prepared: Dictionary = manager.call("_prepare_card_data", data)
		card.call("configure", prepared["data"])
		await _settle()
		var art := card.get_node("%ActionArt") as Control
		if data["game_id"] == Options.GAME_ID:
			_expect(art.get("portraits").size() == data["sailor_art"].size(),
				"A reused card must remove P2's old portrait when returning to solo practice.")
			for singer in data["sailor_art"].size():
				_expect(art.get("portraits")[singer]["ribbon"].mesh
					== data["sailor_art"][singer].get("mesh"),
					"Reconfiguration must replace every old frozen contour with the requested round.")
		else:
			_expect(art is ShareCardArt,
				"A card reused for another game must drop Sailor's boats and artwork.")
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	await _settle()


func _capture(card: Control, image: Image, name: String, url: String) -> void:
	_expect(image.save_png(_capture_directory.path_join(name + ".png")) == OK,
		"The full-size card capture must save.")
	var half := image.duplicate()
	half.resize(600, 315, Image.INTERPOLATE_LANCZOS)
	_expect(half.save_png(_capture_directory.path_join(name + "-half.png")) == OK
		and half.save_jpg(_capture_directory.path_join(name + "-half.jpg"), 0.75) == OK,
		"The half-size PNG/JPEG captures must save for real QR decoding.")
	var qr := (card.get_node("%QRCode") as TextureRect).get_global_rect()
	_captures.append({
		"name": name, "url": url,
		"qr_rect": {"x": qr.position.x, "y": qr.position.y, "w": qr.size.x, "h": qr.size.y},
	})


func _share_files() -> PackedStringArray:
	return DirAccess.get_files_at("user://shares") \
		if DirAccess.dir_exists_absolute("user://shares") else PackedStringArray()


func _key(code: int, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	get_root().push_input(event, true)


func _settle() -> void:
	for _frame in 6:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
