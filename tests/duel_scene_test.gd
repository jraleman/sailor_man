extends SceneTree

## Real input, source admission and shell results exercise complete duels without
## opening hardware. Native runs also guard the actual GL arena and touch layouts.

const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")

## A checked PCM queue substitutes only for the hardware, not the voice pipeline.
class BufferedCapture extends Node:
	var discarded := false
	var stopped := false
	var pending := PackedVector2Array()

	func is_ready() -> bool:
		return true

	func discard() -> void:
		discarded = true
		pending = PackedVector2Array()

	func poll() -> PackedVector2Array:
		var result := pending
		pending = PackedVector2Array()
		return result

	func stop() -> void:
		stopped = true
		pending = PackedVector2Array()

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameCatalog.select(Options.GAME_ID)
	get_root().get_node("GameSession").call("configure_single_player")
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
	var packed := load("res://games/sailor_man/gameplay.tscn") as PackedScene
	if packed == null:
		printerr("Sailor Man duel could not load.")
		quit(1)
		return
	var buses := AudioServer.bus_count
	var game := packed.instantiate()
	game.set("voice_profile_path", "user://sailor_duel_scene_unwritten_%d.cfg"
		% OS.get_process_id())
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	var spike := game.get_node("%ScorerSpike") as Control
	var hud := game.get_node("%DuelHud") as Control
	_expect(spike.get("_capture") == null and AudioServer.bus_count == buses,
		"Entering a duel must not request microphone access or create a capture bus.")
	_test_canal_state(game, hud)
	_test_remo_win(game, spike, hud)
	await process_frame
	_test_pause_and_guard(game, spike)
	await process_frame
	_test_microphone_loss(game, spike)
	_test_missing_audio(game, spike)
	_test_buffered_silence(game, spike)
	await process_frame
	_test_practice_return(game, spike, hud)
	await _test_layouts(game, spike, hud)
	game.queue_free()
	await process_frame
	await process_frame
	# Mixer cleanup is asynchronous; fast headless frames do not drain playback.
	await create_timer(0.1, true, false, true).timeout
	_expect(AudioServer.bus_count == buses, "Leaving the duel must release every owned bus.")
	settings.set("_values", original)
	settings.call("save")
	get_root().min_size = old_minimum
	get_root().size = old_size
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	if _failures.is_empty():
		print("Sailor duel scene tests passed (%s)." % DisplayServer.get_name())
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_remo_win(game: Node, spike: Control, hud: Control) -> void:
	var duel: Duel = game.get("_duel")
	_first_answer(game)
	var view: Control = hud.get("lock")
	var ribbon: Node3D = view.get("ribbon")
	var rival: Dictionary = game.get("_rival")
	_expect(ribbon.get("_profile") == rival["profile"],
		"Rival presentation must retain its authored source profile, not a human fallback.")
	var count := duel.records.size()
	game.call("_on_repeat")
	_tick(game, 3.73)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.repeat_used
		and duel.records.size() == count,
		"Repeat must play the reference without another scored rival turn.")
	_open_player(game)
	_draw_call(game)
	_expect(duel.wins[0] == 1 and duel.phase == Duel.Phase.REVIEW,
		"A real, reachable Remo answer must beat the synthetic rival.")
	_expect(not bool(spike.get("_duel_turn_open"))
		and not (spike.get("_remo_tone") as AudioStreamPlayer).playing,
		"A scored player turn must close admission and stop its preview.")
	game.call("_on_duel_action")
	_expect(duel.tanda == 2 and duel.call_track.is_empty(),
		"The second tanda must start with an independent player call.")
	_open_player(game)
	_draw_call(game)
	game.call("_on_duel_action")
	_tick(game, 3.73)
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.wins[0] == 2
		and duel.records.size() == 4 and hud.visible,
		"Two won tandas must show the final verdict without a spurious third tanda.")
	var stats: Dictionary = game.call("_player_stats", 0)
	_expect(int(stats["tandas_won"]) == 2 and float(stats["best_turn"]) > 0.8
		and int(stats["quiebres"]) >= 6 and float(stats["longest_breath"]) > 4.5
		and str(stats["source"]) == "Remo",
		"Duel results must derive tandas, marks, breaks, breath and source from real turns.")
	game.call("_on_duel_action")
	_expect((game.get_node("%RoundOver") as Control).visible and not hud.visible
		and (game.get_node("%ResultLabel") as Label).text.contains("P1 WINS"),
		"Winning the duel must hand off to the real shell results.")
	var report: Control = game.call("player_stats_panel", 0)
	_expect(report.has_node("Layout/ExtraStats")
		and not (report.get_node("Layout/Stats") as Control).visible,
		"Game-specific evidence must not be mislabeled as generic hits and streaks.")
	_expect(float(game.call("_round_length_seconds")) > 10.0,
		"Duel statistics must include the elapsed performances and repeat.")
	game.call("_on_play_again_pressed")
	var plot := hud.get("_rival_ribbon") as Control
	_expect(duel.phase == Duel.Phase.READY and duel.records.is_empty()
		and duel.call_track.is_empty() and hud.visible and spike.get("_capture") == null
		and (plot.get("_frames") as Array).is_empty()
		and (plot.get("_reference") as Array).is_empty(),
		"Shell replay must reset the entire duel without reopening hardware.")
	_expect(is_zero_approx(float(game.call("_round_length_seconds"))),
		"Replay must reset elapsed duel time, not carry it into the next result.")
	var canal: Control = hud.get("lock")
	var world_ribbon: Node3D = canal.get("ribbon")
	var points: PackedVector3Array = world_ribbon.get("points")
	_expect(points.is_empty() and canal.get("_focus") == Vector3.ZERO,
		"Replay must also clear the world contour and park its previous singer framing.")


func _test_pause_and_guard(game: Node, spike: Control) -> void:
	game.call("_on_duel_action")
	_tick(game, 0.5)
	var elapsed := float(game.call("_round_length_seconds"))
	game.call("open_pause_menu")
	_expect(paused and is_equal_approx(float(game.call("_round_length_seconds")), elapsed)
		and is_zero_approx(float(game.get("_rival_elapsed"))),
		"Pausing rival playback must restart its take without erasing elapsed duel time.")
	var pause := game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	game.call("_return_to_duel")
	_first_answer(game)
	var duel: Duel = game.get("_duel")
	var reference := duel.call_track.duplicate(true)
	game.call("_on_duel_action")
	_tick(game, 0.24)
	_send_key(KEY_SPACE)
	spike.call("_start_remo")
	_expect(duel.phase == Duel.Phase.GUARD and not bool(spike.get("_remo_active")),
		"Neither raw input nor the practice API may start a turn during the tail guard.")
	_send_key(KEY_SPACE, false)
	_tick(game, 0.01)
	spike.call("_toggle_recording")
	_expect(bool(spike.get("_remo_active")) and duel.phase == Duel.Phase.LISTENING
		and spike.get("_capture") == null,
		"The mic shortcut must not replace an admitted Remo turn.")
	_send_key(KEY_SPACE)
	_tick(game, 0.3)
	var canal: Control = game.get_node("%DuelHud").get("lock")
	var world_ribbon: Node3D = canal.get("ribbon")
	var live_points: PackedVector3Array = world_ribbon.get("points")
	_expect(live_points.size() == (spike.get("_track") as Array).size()
		and canal.get("_track_singer") == Duel.Singer.PLAYER,
		"The live world ribbon must use the admitted player track, not a rival or prediction.")
	var count := duel.records.size()
	game.call("open_pause_menu")
	_expect(paused and duel.phase == Duel.Phase.PLAYER_READY
		and duel.records.size() == count and duel.call_track == reference
		and not bool(spike.get("_remo_active"))
		and not (game.get("_rival_tone") as AudioStreamPlayer).playing,
		"Pause must discard a partial player turn while keeping the same answer and reference.")
	_expect(world_ribbon.get("_frames") == reference
		and canal.get("_track_singer") == Duel.Singer.RIVAL,
		"Cancelling a partial take must restore the scored reference in the world too.")
	pause = game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	_send_key(KEY_SPACE, false)
	_open_player(game)
	_send_key(KEY_SPACE)
	_tick(game, 0.2)
	spike.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == count,
		"Losing focus must never submit a partial Remo turn.")
	_send_key(KEY_SPACE, false)
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	var old_binding := int(values[Options.VOICE_KEY])
	values[Options.VOICE_KEY] = KEY_Z
	settings.emit_signal("changed", Options.VOICE_KEY, KEY_Z)
	_open_player(game)
	_send_key(KEY_SPACE)
	_tick(game, 0.1)
	var track: Array = spike.get("_track")
	_expect(not bool(track[-1]["voiced"]), "Old bindings must not voice a duel turn.")
	_send_key(KEY_SPACE, false)
	_send_key(KEY_Z)
	_tick(game, 0.2)
	track = spike.get("_track")
	_expect(bool(track[-1]["voiced"]), "The current bound key must voice the real duel input.")
	values[Options.VOICE_KEY] = old_binding
	settings.emit_signal("changed", Options.VOICE_KEY, old_binding)
	_send_key(KEY_Z, false)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == count
		and duel.call_track == reference,
		"Rebinding during a turn must retry without scoring or replacing its call.")


func _test_microphone_loss(game: Node, spike: Control) -> void:
	game.call("_return_to_duel")
	game.call("_on_source_requested", true)
	_expect(spike.get("_capture") == null,
		"Selecting Microphone must not itself open a physical device.")
	var capture := _checked_capture(spike)
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(paused and capture.stopped and spike.get("_capture") == null,
		"Losing focus during microphone setup must release capture and pause too.")
	var pause := game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	capture = _checked_capture(spike)
	capture.pending = _pcm(0.7)
	_first_answer(game)
	_expect((spike.get("_track") as Array).is_empty() and capture.pending.is_empty(),
		"Rival playback and idle buffers must be discarded, not scored as a player call.")
	_open_player(game)
	spike.call("_start_remo")
	_expect(capture.discarded and not bool(spike.get("_profile")["falsetto_calibrated"]),
		"Mic admission must discard cue audio and restore an unmeasured human profile.")
	_expect(bool(spike.get("_recording")) and not bool(spike.get("_remo_active"))
		and spike.get("_capture") == capture,
		"The Remo API must not replace an admitted microphone turn.")
	capture.pending = _pcm(1.0)
	_tick(game, 1.0)
	(spike.get_node("%RecordCall") as Button).pressed.emit()
	var duel: Duel = game.get("_duel")
	_expect(duel.wins[1] == 1 and duel.records.size() == 2,
		"A real, weak microphone answer must lose on its actual scored evidence.")
	game.call("_on_duel_action")
	_open_player(game)
	capture.pending = _pcm(1.0)
	_tick(game, 1.0)
	(spike.get_node("%RecordCall") as Button).pressed.emit()
	game.call("_on_duel_action")
	_tick(game, 3.73)
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.winner == Duel.Singer.RIVAL,
		"Both microphone turns must complete a real losing duel through the same judges.")
	game.call("_on_duel_action")
	_expect((game.get_node("%ResultLabel") as Label).text.contains("SKIFF WINS")
		and capture.stopped and spike.get("_capture") == null,
		"Defeat must use shell results and release capture, without losing lives.")


func _test_missing_audio(game: Node, spike: Control) -> void:
	game.call("_on_play_again_pressed")
	game.call("_on_source_requested", true)
	_checked_capture(spike)
	_first_answer(game)
	_open_player(game)
	var duel: Duel = game.get("_duel")
	var reference := duel.call_track.duplicate(true)
	_tick(game, 4.0)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1
		and duel.call_track == reference and spike.get("_capture") == null
		and str(game.get("_message")).contains("No microphone audio"),
		"Missing PCM must retry the same answer with an explicit error, never minimum paddles.")


func _test_buffered_silence(game: Node, spike: Control) -> void:
	var capture := _checked_capture(spike)
	_open_player(game)
	capture.pending = _pcm(0.5)
	var silence := PackedVector2Array()
	silence.resize(roundi(AudioServer.get_mix_rate() * 1.4))
	capture.pending.append_array(silence)
	capture.pending.append_array(_pcm(1.0))
	_tick(game, 2.9)
	var duel: Duel = game.get("_duel")
	var track: Array = spike.get("_track")
	_expect(duel.phase == Duel.Phase.REVIEW and not track.is_empty()
		and float(track[-1]["t"]) < 2.0
		and float(duel.records[-1]["result"]["evidence"]["longest_breath"]["seconds"]) < 0.7,
		"Audio buffered after 1.2 seconds of real silence must not enter the scored turn.")


func _test_practice_return(game: Node, spike: Control, hud: Control) -> void:
	game.call("_return_to_duel")
	game.call("_on_source_requested", true)
	game.call("_open_practice")
	_expect(not hud.visible and not bool(spike.get("_duel_mode")),
		"Practice must retain the full original workbench.")
	var start := spike.get_node("%StartRemo") as Button
	var quiebre := spike.get_node("%RemoBreak") as Button
	var remate := spike.get_node("%RemoFinish") as Button
	_expect(start.is_visible_in_tree() and not start.disabled
		and quiebre.is_visible_in_tree() and remate.is_visible_in_tree(),
		"Practice after microphone setup must restore visible, usable Remo controls.")
	spike.call("load_example", true)
	_expect(int(game.get("_calls")) == 1, "Practice fixtures must still exercise the scorer.")
	start.pressed.emit()
	_send_key(KEY_SPACE)
	spike.call("_process", 0.5)
	quiebre.pressed.emit()
	spike.call("_process", 0.04)
	spike.call("_process", 0.2)
	remate.pressed.emit()
	spike.call("_process", 0.12)
	_send_key(KEY_SPACE, false)
	_expect(int(game.get("_calls")) == 2 and bool(spike.get("_last_result")["valid"])
		and (spike.get("_last_result")["evidence"]["breaks"] as Array).size() == 1,
		"Restored Practice buttons must still make a scored Remo call.")
	(spike.get_node("%BackToDuel") as Button).pressed.emit()
	var duel: Duel = game.get("_duel")
	_expect(hud.visible and bool(spike.get("_duel_mode")) and duel.records.is_empty()
		and duel.phase == Duel.Phase.READY,
		"Returning from Practice must reset admission and all duel-local results.")
	game.call("_on_source_requested", false)


func _test_canal_state(game: Node, hud: Control) -> void:
	var canal: Control = hud.get("lock")
	var camera: Camera3D = canal.get("camera")
	var chamber: Node3D = canal.get("chamber")
	var water: MeshInstance3D = chamber.get("water")
	var boats: Array = canal.get("boats")
	var reduced := bool(game.get("_reduced_motion_enabled"))
	var intense := bool(game.get("_intense_effects_enabled"))
	game.call("_set_reduced_motion_enabled", false)
	canal.call("present", 0.0, Duel.Singer.RIVAL)
	canal.call("_process", 0.7)
	var moving := camera.transform
	game.call("_set_reduced_motion_enabled", true)
	var parked := camera.transform
	var camera_size := camera.size
	_expect(not moving.is_equal_approx(parked) and not canal.is_processing(),
		"Enabling reduced motion mid-ease must immediately park the two-shot and its clock.")
	var low := water.position.y
	canal.call("present", 1.0, Duel.Singer.PLAYER)
	_expect(water.position.y > low and camera.transform.is_equal_approx(parked)
		and is_equal_approx(camera.size, camera_size),
		"Essential chamber water must rise without moving a reduced-motion camera.")
	for index in boats.size():
		var boat := boats[index] as Node3D
		_expect(boat.rotation.is_zero_approx()
			and is_equal_approx(boat.position.y - water.position.y, 0.26),
			"Reduced-motion launches must stay level and afloat at the new chamber height.")
		# The dummy renderer does not retain MultiMesh instance transforms.
		if DisplayServer.get_name() == "headless":
			continue
		var lines := chamber.get_node("TowLines") as MultiMeshInstance3D
		for end in 2:
			var segment := index * 4 + end * 2
			var a := lines.multimesh.get_instance_transform(segment)
			var b := lines.multimesh.get_instance_transform(segment + 1)
			var anchors: Array = chamber.get("tow_anchors")
			var endpoint := boat.transform * Vector3(
				-1.0 if index == 0 else 1.0, 0.32, -0.85 if end == 0 else 0.85)
			_expect((a * (Vector3.DOWN * 0.5)).is_equal_approx(anchors[index * 2 + end])
				and (b * (Vector3.UP * 0.5)).is_equal_approx(endpoint),
				"Rotated tow lines must retain both actual endpoints as a launch rises.")
	var ribbon: Node3D = canal.get("ribbon")
	var track: Array[Dictionary] = []
	for index in 70:
		track.append(Frame.make(float(index) * Frame.STEP_SECONDS,
			200.0 if index < 50 else 900.0, index < 20 or index >= 50, 0.2))
	var original := track.duplicate(true)
	ribbon.call("show_track", track, {}, 6.0, Frame.profile(), Vector3.ZERO, Vector3(6, 0, 0))
	var mesh := ribbon.get_child(0) as MeshInstance3D
	var quiet: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bridges_gap := false
	for index in range(0, quiet.size(), 3):
		var left := minf(quiet[index].x, minf(quiet[index + 1].x, quiet[index + 2].x))
		var right := maxf(quiet[index].x, maxf(quiet[index + 1].x, quiet[index + 2].x))
		bridges_gap = bridges_gap or (left < 0.35 and right > 0.35)
	_expect(not bridges_gap and not quiet.is_empty(),
		"The world contour must contain real geometry without joining silent gaps.")
	var louder := track.duplicate(true)
	for frame: Dictionary in louder:
		frame["level"] = 1.0
	ribbon.call("show_track", louder, {}, 6.0, Frame.profile(), Vector3.ZERO, Vector3(6, 0, 0))
	_expect(quiet == mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] and track == original,
		"Extra amplitude must not widen or improve the contour, or mutate the source track.")
	var lower := track.duplicate(true)
	for frame: Dictionary in lower:
		frame["cents"] = float(frame["cents"]) * 0.5
	var profile := Frame.profile()
	profile["falsetto_low"] = 350.0
	profile["falsetto_high"] = 650.0
	ribbon.call("show_track", lower, {"breaks": [{"t": 0.5, "to": 450.0}]},
		6.0, profile, Vector3.ZERO, Vector3(6, 0, 0))
	var decorated: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	game.call("_set_intense_effects_enabled", false)
	var plain: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_expect(quiet == plain and decorated.size() > plain.size(),
		"Profile-relative pitch must match across singers; effects-off removes marks, not contour.")
	canal.call("reset")
	game.call("_set_reduced_motion_enabled", reduced)
	game.call("_set_intense_effects_enabled", intense)


func _test_layouts(game: Node, spike: Control, hud: Control) -> void:
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	for size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720),
			Vector2i(2560, 1080)]:
		for scale: float in [1.0, 1.5]:
			game.call("_return_to_duel")
			values["ui/scale"] = scale
			get_root().min_size = Vector2i.ZERO
			get_root().size = size
			settings.call("_update_content_scale")
			settings.emit_signal("changed", "ui/scale", scale)
			for _frame in 6:
				await process_frame
			if DisplayServer.get_name() != "headless":
				await process_frame
				_assert_arena(hud, true)
				_capture("duel-ready-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
			_first_answer(game)
			_open_player(game)
			for _frame in 6:
				await process_frame
			var ribbon := spike.get_node("%VoiceRibbon") as Control
			var button := spike.get_node("%RemoBreak") as Button
			var transform := get_root().get_final_transform()
			var window := Rect2(Vector2.ZERO, Vector2(size))
			for control in [ribbon, button, hud.get_node("%PauseDuel")]:
				var rect := transform * (control as Control).get_global_rect()
				_expect(window.encloses(rect),
					"Active input must fit %s at UI %.1f: %s %s" % [
						size, scale, (control as Control).name, rect,
					])
			if DisplayServer.get_name() != "headless":
				await process_frame
				_assert_arena(hud, false)
				await process_frame
				_capture("duel-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
			if size == Vector2i(320, 568) and scale == 1.5:
				_test_duel_touch(game, spike, ribbon, button)
			elif size == Vector2i(1280, 720) and scale == 1.0:
				_test_duel_gamepad(game)
			game.call("_on_turn_cancelled", "Layout check complete.")
			_tick(game, 0.0)


func _assert_arena(hud: Control, check_budget: bool) -> void:
	var lock: Control = hud.get("lock")
	var camera: Camera3D = lock.get("camera")
	var viewport: SubViewport = lock.get("viewport")
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	_expect(viewport.find_world_3d() != get_root().find_world_3d(),
		"The lock must never borrow the framework's 3D world.")
	for boat: Node3D in lock.get("boats"):
		for child in boat.get_children():
			if not child is MeshInstance3D:
				continue
			var mesh := child as MeshInstance3D
			for corner in 8:
				var world := mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
				_expect(bounds.has_point(camera.unproject_position(world)),
					"Both complete boat meshes must remain within the real compatibility camera.")
	if check_budget:
		var draws := viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		_expect(draws > 0 and draws < 60,
			"The rendered lock must stay below 60 draw calls, not pass as an empty viewport.")


func _test_duel_touch(game: Node, spike: Control, ribbon: Control, button: Button) -> void:
	var position := ribbon.get_global_transform_with_canvas() * (ribbon.size * Vector2(0.5, 0.6))
	_send_touch(4, position)
	_tick(game, 0.5)
	var break_position := button.get_global_transform_with_canvas() * (button.size * 0.5)
	_send_touch(8, break_position)
	_tick(game, 0.04)
	_send_touch(8, break_position, false)
	_tick(game, 0.2)
	var source := spike.get("_remo") as RefCounted
	_expect(bool(source.call("has_contact", 4)) and bool(source.call("is_voiced"))
		and is_equal_approx(float(source.get("pitch_cents")), 700.0),
		"The compact duel must retain independent ribbon and Break fingers at 150% UI.")
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = position + Vector2(0, ribbon.size.y * 0.3)
	drag.velocity = Vector2(0, ribbon.size.y * 5.0)
	get_root().push_input(drag, true)
	_tick(game, 0.12)
	_send_touch(4, drag.position, false)
	var duel: Duel = game.get("_duel")
	_expect(duel.phase == Duel.Phase.REVIEW and duel.records.size() == 2,
		"A real touch Remate must score and close the admitted duel turn.")


func _test_duel_gamepad(game: Node) -> void:
	_send_pad(JOY_BUTTON_A)
	_tick(game, 0.5)
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER)
	_tick(game, 0.04)
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	_tick(game, 0.2)
	_send_pad(JOY_BUTTON_B)
	_tick(game, 0.12)
	_send_pad(JOY_BUTTON_B, false)
	_send_pad(JOY_BUTTON_A, false)
	var duel: Duel = game.get("_duel")
	_expect(duel.phase == Duel.Phase.REVIEW and duel.records.size() == 2
		and (duel.records[-1]["result"]["evidence"]["breaks"] as Array).size() == 1,
		"Actual pad Voice/Break/Finish must pass through duel admission and the real scorer.")


func _first_answer(game: Node) -> void:
	game.call("_on_duel_action")
	_tick(game, 3.73)
	game.call("_on_duel_action")


func _open_player(game: Node) -> void:
	game.call("_on_duel_action")
	_tick(game, 0.25)
	var duel: Duel = game.get("_duel")
	_expect(duel.phase == Duel.Phase.LISTENING, "Ready and the full guard must open a turn.")
	_expect(not (game.get("_cue") as AudioStreamPlayer).playing,
		"Cue playback must be stopped before opening the scored listening window.")


func _draw_call(game: Node) -> void:
	_send_key(KEY_SPACE)
	_tick(game, 1.2)
	for _index in 3:
		_send_key(KEY_J)
		_tick(game, 0.04)
		_send_key(KEY_J, false)
		_tick(game, 1.2)
	_send_key(KEY_K)
	_tick(game, 0.12)
	_send_key(KEY_K, false)
	_send_key(KEY_SPACE, false)


func _tick(game: Node, delta: float) -> void:
	game.call("_update_round", delta, 0.0)


func _checked_capture(spike: Control) -> BufferedCapture:
	var capture := BufferedCapture.new()
	spike.add_child(capture)
	spike.set("_capture", capture)
	return capture


func _pcm(seconds: float) -> PackedVector2Array:
	var pcm := PackedVector2Array()
	var rate := AudioServer.get_mix_rate()
	for index in roundi(seconds * rate):
		var value := 0.12 * sin(TAU * 160.0 * float(index) / float(rate))
		pcm.append(Vector2(value, value))
	return pcm


func _send_key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	get_root().push_input(event, true)


func _send_pad(button: JoyButton, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	get_root().push_input(event, true)


func _send_touch(index: int, position: Vector2, pressed := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	get_root().push_input(event, true)


func _capture(filename: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-capture-dir="):
			var directory := argument.trim_prefix("--sailor-capture-dir=")
			DirAccess.make_dir_recursive_absolute(directory)
			var error := get_root().get_texture().get_image().save_png(
				directory.path_join(filename))
			_expect(error == OK, "Could not save duel layout capture.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
