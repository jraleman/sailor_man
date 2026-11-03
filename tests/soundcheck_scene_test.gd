extends SceneTree

## Only the hardware is substituted: synthetic PCM traverses the actual wizard,
## detector, normalization, scalar persistence and capture-transfer boundary.

const Calibration = preload("res://games/sailor_man/voice/voice_calibration.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const VoiceRest = preload("res://games/sailor_man/voice/voice_rest.gd")

class BufferedCapture extends Node:
	signal calibrated(noise_floor: float)
	signal capture_failed(reason: String)

	var stopped := false
	var pending := PackedVector2Array()
	var checked := false
	var starts := 0

	func start(_device: String) -> void:
		starts += 1

	func is_ready() -> bool:
		return checked and not stopped

	func room() -> void:
		checked = true
		calibrated.emit(0.002)

	func discard() -> void:
		pending = PackedVector2Array()

	func poll() -> PackedVector2Array:
		var result := pending
		pending = PackedVector2Array()
		return result

	func stop() -> void:
		stopped = true
		pending = PackedVector2Array()

	func _exit_tree() -> void:
		stop()

var _failures := PackedStringArray()
var _profile_path := "user://sailor_soundcheck_scene_%d.cfg" % OS.get_process_id()
var _saved: Dictionary = {}
var _transferred: Node
var _cancelled := 0
var _remo := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameCatalog.select(Options.GAME_ID)
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values["ui/scale"] = 1.0
	for option: Dictionary in Options.TUNABLES:
		values[option["key"]] = option["default"]
	settings.set("_values", values)
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	var buses := AudioServer.bus_count
	var wizard := _open()
	await process_frame
	await process_frame
	wizard.set_process(false)
	_expect(wizard.get("_capture") == null and AudioServer.bus_count == buses,
		"Opening Soundcheck must leave microphone permissions and hardware untouched.")
	await _test_keyboard_navigation(wizard, settings)
	var capture := BufferedCapture.new()
	wizard.call("_begin_capture", capture)
	capture.room()
	wizard.set("_budget", 2)
	_take(wizard, capture, _tone(0.9, 200.0, 0.04))
	_expect(wizard.get("_model").step == Calibration.Step.LOW,
		"Real PCM must establish speaking level before the low reference.")
	_take(wizard, capture, _tone(0.9, 200.0, 0.06))
	var high := _tone(0.4, 200.0, 0.06)
	high.append_array(_tone(0.9, 200.0 * pow(2.0, 900.0 / 1200.0), 0.06))
	_take(wizard, capture, high)
	_take(wizard, capture, _tone(1.0, 200.0, 0.12), true)
	_expect(wizard.get("_model").step == Calibration.Step.COMPLETE,
		"A fresh profile must finish every measurement through the bounded input pipeline.")
	_expect(not FileAccess.file_exists(_profile_path) and _saved.is_empty(),
		"Finishing the unscored Call must not save or publish without the Save action.")
	(wizard.get("_save") as Button).pressed.emit()
	_expect(not _saved.is_empty() and _transferred == capture and not capture.stopped,
		"Save must hand off a checked capture instead of opening the device a second time.")
	var loaded := Calibration.load_profiles(_profile_path)
	_expect(loaded["selected"] == "P1"
		and (loaded["profiles"]["P1"] as Dictionary).size() == _saved.size()
		and absf(float(loaded["profiles"]["P1"]["chest_hz"])
			- float(_saved["chest_hz"])) < 0.00001,
		"The explicitly saved scalar profile must round-trip.")
	_expect(absf(float(_saved["chest_hz"]) - 200.0) < 2.0
		and absf(float(_saved["speak_level"]) - 0.04 / sqrt(2.0)) < 0.002
		and absf(float(_saved["carry_level"]) - 0.12 / sqrt(2.0)) < 0.002,
		"The saved profile must contain measured raw RMS and chest frequency.")
	_expect(bool(_saved["falsetto_calibrated"]),
		"The real detector and filters must preserve a deliberate high-register break.")
	capture.stop()
	capture.queue_free()
	_transferred = null
	wizard.queue_free()
	await process_frame
	var before := FileAccess.get_file_as_bytes(_profile_path)
	wizard = _open()
	await process_frame
	wizard.set_process(false)
	await _test_keyboard_navigation(wizard, settings)
	(wizard.get("_use_saved") as Button).pressed.emit()
	_expect(wizard.get("_capture") == null and _transferred == null
		and AudioServer.bus_count == buses,
		"Using a saved profile must not implicitly activate its microphone.")
	wizard.queue_free()
	await process_frame
	wizard = _open()
	await process_frame
	wizard.set_process(false)
	capture = BufferedCapture.new()
	wizard.call("_begin_capture", capture)
	capture.room()
	_take(wizard, capture, _tone(0.9, 180.0, 0.05))
	_send_escape()
	_expect(capture.stopped and _cancelled == 1
		and FileAccess.get_file_as_bytes(_profile_path) == before,
		"Back/Escape during recalibration must release capture and preserve the saved profile.")
	wizard.queue_free()
	await process_frame
	wizard = _open()
	await process_frame
	wizard.set_process(false)
	capture = BufferedCapture.new()
	wizard.call("_begin_capture", capture)
	capture.capture_failed.emit("Microphone permission denied.")
	_expect(capture.stopped and wizard.get("_capture") == null
		and (wizard.get("_status") as Label).text.contains("denied")
		and FileAccess.get_file_as_bytes(_profile_path) == before,
		"Denied input must remain explicit and cannot overwrite a working calibration.")
	wizard.call("_use_remo")
	_expect(_remo == 1, "The denied-microphone path must have a usable Remo exit.")
	wizard.queue_free()
	await process_frame
	wizard = _open()
	await process_frame
	wizard.set_process(false)
	capture = BufferedCapture.new()
	wizard.call("_begin_capture", capture)
	capture.room()
	wizard.call("_toggle_take")
	wizard.call("_process", 3.1)
	_expect(capture.stopped and wizard.get("_capture") == null
		and FileAccess.get_file_as_bytes(_profile_path) == before,
		"Missing PCM must fail and release input, not accept a zero measurement.")
	wizard.queue_free()
	await process_frame
	wizard = _open()
	await process_frame
	wizard.set_process(false)
	await _test_layouts(wizard, settings)
	wizard.queue_free()
	await process_frame
	await _test_calibrated_duel(settings)
	var future := ConfigFile.new()
	future.set_value("voice", "format", Calibration.FORMAT + 1)
	future.save(_profile_path)
	before = FileAccess.get_file_as_bytes(_profile_path)
	wizard = _open()
	await process_frame
	_expect((wizard.get("_status") as Label).text.contains("Unsupported")
		and wizard.get("_capture") == null,
		"An unreadable profile format must be explained without opening the microphone.")
	wizard.call("_use_remo")
	_expect(FileAccess.get_file_as_bytes(_profile_path) == before,
		"The failed-profile Remo exit must not rewrite a newer calibration file.")
	wizard.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_path))
	settings.set("_values", original)
	settings.call("save")
	get_root().min_size = old_minimum
	get_root().size = old_size
	settings.call("_update_content_scale")
	_expect(AudioServer.bus_count == buses, "Soundcheck cannot leak an owned capture bus.")
	if _failures.is_empty():
		print("Sailor Soundcheck scene tests passed (%s)." % DisplayServer.get_name())
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _open() -> Control:
	var wizard := (load("res://games/sailor_man/ui/soundcheck.tscn") as PackedScene).instantiate()
	wizard.set("profile_path", _profile_path)
	wizard.connect("completed", _completed)
	wizard.connect("cancelled", func() -> void: _cancelled += 1)
	wizard.connect("remo_requested", func() -> void: _remo += 1)
	get_root().add_child(wizard)
	return wizard


func _completed(profile: Dictionary, capture: Node) -> void:
	_saved = profile
	_transferred = capture
	if capture != null and capture.get_parent() != get_root():
		capture.reparent(get_root())


func _take(
	wizard: Control, capture: BufferedCapture, pcm: PackedVector2Array, queued_stop := false
) -> void:
	if not bool(wizard.get("_recording")):
		wizard.call("_toggle_take")
	capture.pending = pcm
	if not queued_stop:
		wizard.call("_process", 0.1)
	wizard.call("_toggle_take")
	var slices := 0
	while bool(wizard.get("_recording")) and slices < 1000:
		wizard.call("_process", 0.01)
		slices += 1
	_expect(slices < 1000, "A bounded take must finish without waiting for more input samples.")


func _tone(seconds: float, frequency: float, peak: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var rate := AudioServer.get_mix_rate()
	for index in roundi(seconds * rate):
		var value := peak * sin(TAU * frequency * float(index) / rate)
		result.append(Vector2(value, value))
	return result


func _send_escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_root().push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_root().push_input(event, true)


func _test_calibrated_duel(settings: Node) -> void:
	GameCatalog.select(Options.GAME_ID)
	get_root().get_node("GameSession").call("configure_single_player")
	var values: Dictionary = settings.get("_values")
	values["ui/scale"] = 1.0
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	var game := (load("res://games/sailor_man/gameplay.tscn") as PackedScene).instantiate()
	if not game.has_method("_open_soundcheck"):
		_expect(false, "The calibrated gameplay scene must compile before integration checks.")
		game.free()
		return
	game.set("voice_profile_path", _profile_path)
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	var spike := game.get_node("%ScorerSpike") as Control
	var hud := game.get_node("%DuelHud") as Control
	var duel: Duel = game.get("_duel")
	var rest: VoiceRest = game.get("_voice_rest")
	_expect(bool(game.get("_use_microphone")) and spike.get("_capture") == null,
		"Auto must prefer an available saved profile without opening hardware.")
	game.call("_on_duel_action")
	game.call("_update_round", 3.73, 0.0)
	game.call("_on_duel_action")
	var reference := duel.call_track.duplicate(true)
	var clock := duel.chamber_left
	(hud.get("_soundcheck") as Button).pressed.emit()
	var wizard := game.get("_soundcheck") as Control
	await process_frame
	game.call("_update_round", 90.0, 0.0)
	_expect(wizard != null and wizard.get("_capture") == null
		and duel.phase == Duel.Phase.PLAYER_READY and duel.chamber_left == clock
		and duel.call_track == reference,
		"Opening Soundcheck must suspend the chamber and preserve the pending answer.")
	wizard.call("_cancel")
	_expect(game.get("_soundcheck") == null and hud.visible
		and spike.process_mode != Node.PROCESS_MODE_DISABLED and duel.call_track == reference,
		"Back must restore the same usable duel, not reset its call.")
	game.call("_on_source_requested", false)
	game.call("_open_soundcheck")
	wizard = game.get("_soundcheck") as Control
	await process_frame
	wizard.set_process(false)
	var capture := BufferedCapture.new()
	wizard.call("_begin_capture", capture)
	capture.room()
	wizard.set("_budget", 2)
	_take(wizard, capture, _tone(0.9, 200.0, 0.04))
	_take(wizard, capture, _tone(0.9, 200.0, 0.06))
	wizard.call("_skip_high")
	_take(wizard, capture, _tone(0.9, 200.0, 0.12), true)
	(wizard.get("_save") as Button).pressed.emit()
	_expect(game.get("_soundcheck") == null and spike.get("_capture") == capture
		and bool(spike.call("microphone_ready")) and capture.starts == 1
		and int(settings.call("tunable_choice", Options.INPUT_SOURCE_KEY))
			== Options.InputSource.MICROPHONE,
		"Save from Remo must select mic and transfer its checked capture without a new room check.")
	spike.set("_analysis_budget", 2)
	_open_turn(game)
	var normal: Dictionary = spike.get("_profile")
	var normal_carry := float(normal["carry_level"])
	_expect(absf(float(normal["chest_hz"]) - 200.0) < 2.0
		and not bool(normal["falsetto_calibrated"]),
		"An explicit high-step skip must remain unmeasured when the real microphone turn opens.")
	capture.pending = _tone(0.9, 200.0, 0.04)
	game.call("_update_round", 6.1, 0.0)
	_expect(bool(spike.get("_finishing")) and duel.records.size() == 1,
		"A web-budget deadline must drain captured analysis, not score its first tiny slice.")
	_drain_turn(game, spike)
	var normal_peak := _peak_level(spike.get("_track"))
	_expect(duel.records.size() == 2 and (spike.get("_track") as Array).size() > 80
		and rest._turns.size() == 1,
		"Budgeted late analysis must retain the full take and count one completed sung turn.")
	game.call("_on_duel_action")
	settings.call("set_value", Options.QUIET_MODE_KEY, true)
	capture = _checked_capture(spike)
	_open_turn(game)
	var quiet: Dictionary = spike.get("_profile")
	_expect(float(quiet["carry_level"]) < normal_carry * 0.5
		and is_equal_approx(float(quiet["carry_level"]),
			float(spike.get("_human_profile")["speak_level"])),
		"Quiet Mode must apply the measured speaking RMS, not just bypass a scoring flag.")
	capture.pending = _tone(0.9, 200.0, 0.04)
	spike.call("_finish_recording")
	_drain_turn(game, spike)
	_expect(_peak_level(spike.get("_track")) > normal_peak * 2.5
		and not bool(spike.get("_last_result")["power_gated"]) and rest._turns.size() == 2
		and is_equal_approx(float(Calibration.load_profiles(_profile_path)
			["profiles"]["P1"]["carry_level"]), normal_carry),
		"Speaking-level normalization must reach actual PCM frames without changing the saved carry.")
	game.call("_open_practice")
	spike.call("load_example", true)
	_expect(rest._turns.size() == 2,
		"Synthetic examples cannot count as sung turns for a rest reminder.")
	game.call("_return_to_duel")
	game.call("_on_duel_action")
	game.call("_update_round", 3.73, 0.0)
	game.call("_on_duel_action")
	reference = duel.call_track.duplicate(true)
	capture = _checked_capture(spike)
	_open_turn(game)
	capture.pending = _tone(2.0, 200.0, 0.04)
	game.call("_update_round", 6.1, 0.0)
	settings.call("set_value", Options.INPUT_SOURCE_KEY, Options.InputSource.REMO)
	_expect(capture.stopped and not bool(spike.get("_recording"))
		and not bool(spike.get("_source").has_pending_analysis())
		and duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1
		and duel.call_track == reference and rest._turns.size() == 2,
		"Changing source during queued analysis must discard the partial turn, not its reference.")
	settings.call("set_value", Options.INPUT_SOURCE_KEY, Options.InputSource.AUTO)
	capture = _checked_capture(spike)
	spike.call("_on_capture_failed", "The input device was disconnected.")
	_expect(capture.stopped and not bool(game.get("_use_microphone"))
		and int(settings.call("tunable_choice", Options.INPUT_SOURCE_KEY))
			== Options.InputSource.AUTO and str(game.get("_message")).contains("disconnected"),
		"Auto must fall back to usable Remo on device failure without rewriting the preference.")
	var missing_device: Dictionary = game.get("_voice_profile").duplicate()
	missing_device["device"] = "Unavailable synthetic test device"
	Calibration.save_profile("Other room", missing_device, _profile_path)
	game.call("_load_voice_profile")
	_expect(not bool(game.get("_use_microphone")) and spike.get("_capture") == null,
		"Auto must not silently use a different physical device with another device's calibration.")
	Calibration.select_profile("P1", _profile_path)
	game.call("_load_voice_profile")
	game.call("_return_to_duel")
	var now := float(Time.get_ticks_msec()) / 1000.0
	for _index in VoiceRest.TURNS:
		rest.record_turn(now, true)
	game.call("_sync_hud")
	_expect((hud.get("_rest_offer") as Control).visible and bool(game.get("_use_microphone")),
		"Rest must be an optional between-duel card, never an automatic source switch.")
	settings.call("set_value", Options.REST_REMINDERS_KEY, false)
	_expect(not (hud.get("_rest_offer") as Control).visible,
		"The saved reminder setting must hide the optional card immediately.")
	settings.call("set_value", Options.REST_REMINDERS_KEY, true)
	(hud.find_child("RestNotNow", true, false) as Button).pressed.emit()
	_expect(not rest.is_due(now) and bool(game.get("_use_microphone")),
		"Not now must dismiss without forcing Remo or a timed wait.")
	for _index in VoiceRest.TURNS:
		rest.record_turn(now, true)
	game.call("_sync_hud")
	(hud.find_child("RestUseRemo", true, false) as Button).pressed.emit()
	_expect(not bool(game.get("_use_microphone"))
		and int(settings.call("tunable_choice", Options.INPUT_SOURCE_KEY)) == Options.InputSource.REMO,
		"The optional rest offer must select Remo only when explicitly accepted.")
	game.queue_free()
	await process_frame
	await create_timer(0.1, true, false, true).timeout


func _checked_capture(spike: Control) -> BufferedCapture:
	var capture := BufferedCapture.new()
	capture.checked = true
	spike.add_child(capture)
	spike.set("_capture", capture)
	return capture


func _open_turn(game: Node) -> void:
	game.call("_on_duel_action")
	game.call("_update_round", 0.25, 0.0)


func _drain_turn(game: Node, spike: Control) -> void:
	var slices := 0
	while bool(spike.get("_recording")) and slices < 1000:
		game.call("_update_round", 0.01, 0.0)
		slices += 1
	_expect(slices < 1000, "A captured microphone turn must finish its bounded queue.")


func _peak_level(frames: Array) -> float:
	var peak := 0.0
	for frame: Dictionary in frames:
		if bool(frame["voiced"]):
			peak = maxf(peak, float(frame["level"]))
	return peak


func _test_layouts(wizard: Control, settings: Node) -> void:
	var device := wizard.get("_device") as OptionButton
	device.add_item("A deliberately long microphone-device label that must stay inside the card")
	device.select(device.item_count - 1)
	(wizard.get("_name") as LineEdit).text = "A deliberately long named voice profile"
	for stage in ["room", "high", "call", "complete"]:
		if stage == "high":
			var capture := BufferedCapture.new()
			wizard.call("_begin_capture", capture)
			capture.room()
			_take(wizard, capture, _tone(0.9, 200.0, 0.04))
			_take(wizard, capture, _tone(0.9, 200.0, 0.06))
		elif stage == "call":
			var capture := wizard.get("_capture") as BufferedCapture
			wizard.call("_skip_high")
			wizard.call("_toggle_take")
			capture.pending = _tone(0.2, 200.0, 0.12)
			wizard.call("_process", 0.2)
		elif stage == "complete":
			var capture := wizard.get("_capture") as BufferedCapture
			_take(wizard, capture, _tone(0.9, 200.0, 0.12))
		for scale in [1.0, 1.5]:
			var values: Dictionary = settings.get("_values")
			values["ui/scale"] = scale
			for size in [Vector2i(320, 568), Vector2i(568, 320),
				Vector2i(1280, 720), Vector2i(2560, 1080)]:
				get_root().size = size
				settings.call("_update_content_scale")
				wizard.call("_fit")
				await process_frame
				await process_frame
				var transform := get_root().get_final_transform()
				var bounds := Rect2(Vector2.ZERO, Vector2(size))
				_expect((wizard.get("_title") as Label).get_line_count() == 1,
					"Soundcheck must not wrap a trailing title letter at %s / %.1f UI."
					% [size, scale])
				if stage == "call":
					var scroll := wizard.get("_scroll") as ScrollContainer
					var ribbon := wizard.get("_ribbon") as Control
					_expect(scroll.get_global_rect().grow(1.0).encloses(ribbon.get_global_rect()),
						"The Call ribbon %s must fit the scroll viewport %s at %s / %.1f UI."
						% [ribbon.get_global_rect(), scroll.get_global_rect(), size, scale])
				for name in ["BackSoundcheck", "EnableCalibrationMic", "CalibrationRemo",
					"RecordCalibration", "SkipHighVoice", "SaveVoiceProfile"]:
					var button := wizard.find_child(name, true, false) as Button
					if not button.visible:
						continue
					var rect := transform * button.get_global_rect()
					_expect(bounds.encloses(rect) and rect.size.y >= 43.0 * scale,
						"%s (%s) must be reachable and at least 44 px at %s / %.1f UI."
						% [name, stage, size, scale])
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					for argument in OS.get_cmdline_user_args():
						if argument.begins_with("--sailor-capture-dir="):
							var directory := argument.trim_prefix("--sailor-capture-dir=")
							DirAccess.make_dir_recursive_absolute(directory)
							get_root().get_texture().get_image().save_png(
								directory.path_join("soundcheck-%s-%dx%d-ui%.1f.png"
									% [stage, size.x, size.y, scale]))
	get_root().size = Vector2i(320, 568)
	settings.call("_update_content_scale")
	await process_frame
	await process_frame
	var scroll := wizard.get("_scroll") as ScrollContainer
	scroll.scroll_vertical = ceili(scroll.get_v_scroll_bar().max_value)
	var before := FileAccess.get_file_as_bytes(_profile_path)
	wizard.set("profile_path", "user://sailor_soundcheck_missing_%d/voice.cfg" % OS.get_process_id())
	(wizard.get("_save") as Button).pressed.emit()
	await process_frame
	await process_frame
	var status := wizard.get("_status") as Label
	_expect(status.text.contains("Could not save")
		and scroll.get_global_rect().grow(1.0).encloses(status.get_global_rect())
		and FileAccess.get_file_as_bytes(_profile_path) == before,
		"A failed Save must reveal its error from the Call ribbon without changing the saved file.")
	wizard.set("profile_path", _profile_path)


func _test_keyboard_navigation(wizard: Control, settings: Node) -> void:
	for frame in 6:
		await process_frame
	var back := wizard.find_child("BackSoundcheck", true, false) as Button
	var scroll := wizard.get("_scroll") as ScrollContainer
	var names := wizard.get("_names") as OptionButton
	var device := wizard.get("_device") as OptionButton
	var name := wizard.get("_name") as LineEdit
	var original_name := name.text
	var original_device := device.selected
	var saved := FileAccess.get_file_as_bytes(_profile_path) \
		if FileAccess.file_exists(_profile_path) else PackedByteArray()
	var buses := AudioServer.bus_count
	_expect(back.has_focus(),
		"Soundcheck must open on its safe Back action, never silently focus microphone consent.")
	_expect(names.accessibility_name.to_lower().contains("profile")
		and device.accessibility_name.to_lower().contains("device")
		and name.accessibility_name.to_lower().contains("profile"),
		"Voice-profile, device and name fields must identify their purpose while focused.")
	for scale: float in [1.0, 1.5]:
		for dimensions in [
			Vector2i(320, 568), Vector2i(568, 320),
			Vector2i(1280, 720), Vector2i(2560, 1080),
		]:
			var values: Dictionary = settings.get("_values")
			values["ui/scale"] = scale
			get_root().size = dimensions
			settings.call("_update_content_scale")
			wizard.call("_fit")
			scroll.scroll_vertical = 0
			back.grab_focus()
			for frame in 6:
				await process_frame
			var visited := PackedStringArray()
			for step in 24:
				var focused := get_root().gui_get_focus_owner()
				if focused == null or not wizard.is_ancestor_of(focused):
					_expect(false, "Soundcheck Tab navigation must remain inside the modal.")
					break
				visited.append(str(focused.name))
				if scroll.is_ancestor_of(focused):
					_expect(_native_rect(scroll).grow(1.0).encloses(_native_rect(focused)),
						"%s must follow keyboard focus into the actual scroller at %s / %.1f UI."
						% [focused.name, dimensions, scale])
				var event := InputEventKey.new()
				event.keycode = KEY_TAB
				event.physical_keycode = KEY_TAB
				event.pressed = true
				Input.parse_input_event(event)
				event = event.duplicate()
				event.pressed = false
				Input.parse_input_event(event)
				for frame in 6:
					await process_frame
				if get_root().gui_get_focus_owner() == back:
					break
			for control: Control in [
				name, device, names, wizard.get("_use_saved"), wizard.get("_enable"),
				wizard.find_child("CalibrationRemo", true, false),
			]:
				if control is BaseButton and control.disabled:
					continue
				_expect(str(control.name) in visited,
					"Keyboard-only Soundcheck must reach " + str(control.name) + ".")
	_expect(wizard.get("_capture") == null and AudioServer.bus_count == buses
		and name.text == original_name and device.selected == original_device
		and (FileAccess.get_file_as_bytes(_profile_path)
			if FileAccess.file_exists(_profile_path) else PackedByteArray()) == saved,
		"Soundcheck keyboard browsing must not open capture or alter any calibration.")
	get_root().size = Vector2i(1280, 720)
	var values: Dictionary = settings.get("_values")
	values["ui/scale"] = 1.0
	settings.call("_update_content_scale")
	wizard.call("_fit")
	for frame in 6:
		await process_frame


func _native_rect(control: Control) -> Rect2:
	return get_root().get_final_transform() * control.get_global_transform_with_canvas() \
		* Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
