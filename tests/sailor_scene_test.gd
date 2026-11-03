extends SceneTree

## The prototype must be usable without microphone permission and must keep
## the real shell's Remo/pause/results/replay path. Also run without --headless
## to capture the actual rendered phone, landscape and ultrawide layouts.

const Manifest = preload("res://games/sailor_man/game.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")

## Buffered PCM exercises recording without opening a physical input device.
class BufferedCapture extends Node:
	var discarded := false
	var stopped := false
	var pending := PackedVector2Array()

	func is_ready() -> bool:
		return true

	func discard() -> void:
		discarded = true

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
	var manifest := Manifest.manifest()
	_expect(
		manifest.supports_multiplayer and manifest.local_multiplayer_turns
			and manifest.max_local_players == 2 and not manifest.supports_cpu_opponent,
		"The manifest must offer two-human hot seat, not another generic CPU setup mode."
	)
	_expect(not manifest.uses_shell_round_rules, "A scorer session must not expire on the shell clock.")
	GameCatalog.select(manifest.id)
	var session := get_root().get_node("GameSession")
	session.call("configure_single_player")
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	var old_size := get_root().size
	get_root().size = Vector2i(1280, 720)
	values["ui/scale"] = 1.0
	for option: Dictionary in Options.TUNABLES:
		values[option["key"]] = option["default"]
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		values[binding["key"]] = binding["default"]
	settings.set("_values", values)
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	var packed := load(manifest.gameplay_scene_path) as PackedScene
	if packed == null:
		printerr("Sailor Man gameplay could not load.")
		quit(1)
		return
	var buses := AudioServer.bus_count
	var game := packed.instantiate()
	game.set("voice_profile_path", "user://sailor_practice_scene_unwritten_%d.cfg"
		% OS.get_process_id())
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.call("_open_practice")
	var spike := game.get_node("%ScorerSpike") as Control
	_expect(spike.get("_capture") == null, "Opening the game must not request microphone access.")
	_expect(AudioServer.bus_count == buses, "Opening the spike must not create a capture bus.")
	spike.call("_toggle_recording")
	_expect(
		(spike.get_node("%Status") as Label).text.contains("room check"),
		"Recording without a checked microphone must explain what to do."
	)
	spike.call("load_example", true)
	var shaped: Dictionary = spike.get("_last_result")
	_expect(
		bool(shaped["valid"]) and float(shaped["total"]) > 0.8,
		"The interactive shaped example must exercise the real scorer."
	)
	_expect(
		int(game.get("_scores")[0]) == roundi(float(shaped["total"]) * 100.0),
		"The shell must receive the actual workbench score."
	)
	spike.call("keep_reference")
	spike.call("load_example", true)
	var answer: Dictionary = spike.get("_last_result")
	_expect(
		bool(answer["answering"]) and float(answer["marks"]["eco"]) > 0.99,
		"Keeping a call must let the next answer earn Eco."
	)
	spike.call("clear_reference")
	spike.call("load_example", false)
	var flat: Dictionary = spike.get("_last_result")
	_expect(
		not bool(flat["answering"]) and float(flat["total"]) < float(shaped["total"]) - 0.3,
		"The interactive examples must clearly distinguish shape from a flat hold."
	)
	_test_remo_keyboard(game, spike)
	_test_remo_gamepad(spike)
	await _test_remo_touch(game, spike)
	_test_remo_cancellation(game, spike)
	_test_empty_recording(game, spike)
	_test_recording_ui(spike)
	_test_stalled_recording(game, spike)
	spike.call("clear_reference")
	(spike.get_node("%StartRemo") as Button).pressed.emit()
	_draw_remo_call(spike)
	spike.call("keep_reference")
	(spike.get_node("%StartRemo") as Button).pressed.emit()
	_draw_remo_call(spike)
	await _test_layouts(spike)
	var pause_capture := BufferedCapture.new()
	pause_capture.pending = _microphone_pcm()
	spike.add_child(pause_capture)
	spike.set("_capture", pause_capture)
	spike.call("_toggle_recording")
	spike.call("_process", 0.1)
	var calls_before_pause := int(game.get("_calls"))
	var reference_before_pause: Array = (spike.get("_reference") as Array).duplicate(true)
	game.call("open_pause_menu")
	_expect(
		pause_capture.stopped and not bool(spike.get("_recording"))
		and (spike.get("_track") as Array).is_empty()
		and (spike.get("_reference") as Array) == reference_before_pause
		and int(game.get("_calls")) == calls_before_pause,
		"Pause must discard the unfinished call without scoring it or losing the saved reference."
	)
	await process_frame
	var pause := game.get("_pause_menu") as Node
	_expect(pause != null and paused, "The spike must open the real shell pause overlay.")
	_expect(spike.get("_capture") == null, "Pause must not leave the microphone running.")
	if pause != null:
		pause.call("resume")
	(spike.get_node("%FinishSession") as Button).pressed.emit()
	await process_frame
	_expect(
		(game.get_node("%RoundOver") as Control).visible and not spike.visible,
		"Finishing the session must hand off to shell results, not cover them."
	)
	game.call("_on_play_again_pressed")
	await process_frame
	_expect(
		spike.visible and (spike.get("_track") as Array).is_empty()
		and (spike.get("_reference") as Array).is_empty()
		and not bool(spike.get("_remo_active"))
		and not (spike.get("_remo_tone") as AudioStreamPlayer).playing,
		"Replay must reset calls/references and restore the scorer workbench."
	)
	settings.set("_values", original)
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	get_root().size = old_size
	game.free()
	await process_frame
	await create_timer(0.1).timeout
	_expect(AudioServer.bus_count == buses, "Leaving the spike must release its audio resources.")
	if _failures.is_empty():
		print("Sailor scene tests passed (%s)." % DisplayServer.get_name())
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_remo_keyboard(game: Node, spike: Control) -> void:
	var calls := int(game.get("_calls"))
	(spike.get_node("%StartRemo") as Button).pressed.emit()
	_expect(
		bool(spike.get("_remo_active")) and spike.get("_capture") == null
		and (spike.get_node("%KeepReference") as Button).disabled,
		"The visible Remo action must open a hardware-free window, not a microphone."
	)
	_draw_remo_call(spike)
	var call: Dictionary = spike.get("_last_result")
	_expect(
		bool(call.get("valid", false)) and float(call.get("total", 0.0)) > 0.85
		and int(game.get("_calls")) == calls + 1
		and int(game.get("_scores")[0]) == roundi(float(call["total"]) * 100.0),
		"Actual keyboard events must score a shaped Remo call through the shell."
	)
	spike.call("keep_reference")
	(spike.get_node("%StartRemo") as Button).pressed.emit()
	_draw_remo_call(spike)
	var answer: Dictionary = spike.get("_last_result")
	_expect(
		bool(answer.get("answering", false)) and float(answer["marks"]["eco"]) > 0.99,
		"The same keyboard answer must earn Eco from a retained Remo call."
	)
	_expect(
		not (spike.get("_remo_tone") as AudioStreamPlayer).playing
		and not bool(spike.get("_remo_active")),
		"A finished Remo call must stop its synthetic preview and close the window."
	)
	spike.call("clear_reference")


func _draw_remo_call(spike: Control) -> void:
	_send_key(KEY_SPACE)
	spike.call("_process", 1.2)
	_expect(
		(spike.get("_remo_tone") as AudioStreamPlayer).playing,
		"Voiced Remo frames must drive the labelled synthetic preview."
	)
	for _index in 3:
		_send_key(KEY_J)
		spike.call("_process", 0.04)
		_send_key(KEY_J, false)
		spike.call("_process", 1.2)
	_send_key(KEY_K)
	spike.call("_process", 0.12)
	_send_key(KEY_K, false)
	_send_key(KEY_SPACE, false)


func _test_remo_gamepad(spike: Control) -> void:
	(spike.get_node("%StartRemo") as Button).pressed.emit()
	_send_pad(JOY_BUTTON_A)
	spike.call("_process", 0.5)
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER)
	spike.call("_process", 0.04)
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	spike.call("_process", 0.3)
	var preview := spike.get("_remo_tone") as AudioStreamPlayer
	_expect(
		preview.playing and absf(preview.pitch_scale - pow(2.0, 700.0 / 1200.0)) < 0.001,
		"Actual pad input must change the preview and contour by the same register jump."
	)
	_send_pad(JOY_BUTTON_B)
	spike.call("_process", 0.12)
	_send_pad(JOY_BUTTON_B, false)
	_send_pad(JOY_BUTTON_A, false)
	var result: Dictionary = spike.get("_last_result")
	_expect(
		bool(result.get("valid", false)) and (result["evidence"]["breaks"] as Array).size() == 1
		and float(result["marks"]["remate"]) == 1.0,
		"The real gamepad route must produce a judged break and finish without opening a mic."
	)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	get_root().push_input(trigger, true)
	spike.call("_process", 0.2)
	_send_pad(JOY_BUTTON_B)
	spike.call("_process", 0.12)
	_send_pad(JOY_BUTTON_B, false)
	trigger.axis_value = 0.9
	get_root().push_input(trigger, true)
	_expect(
		not bool(spike.get("_remo_active")),
		"A still-held trigger's analog jitter must not start another Remo call."
	)
	trigger.axis_value = 0.0
	get_root().push_input(trigger, true)
	trigger.axis_value = 0.9
	get_root().push_input(trigger, true)
	_expect(
		bool(spike.get("_remo_active")),
		"Releasing and pressing the trigger again must start a fresh focused turn."
	)
	spike.call("stop_capture")
	trigger.axis_value = 0.0
	get_root().push_input(trigger, true)


func _test_remo_touch(game: Node, spike: Control) -> void:
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values["ui/scale"] = 1.5
	settings.set("_values", values)
	get_root().min_size = Vector2i.ZERO
	get_root().size = Vector2i(320, 568)
	settings.call("_update_content_scale")
	settings.emit_signal("changed", "ui/scale", 1.5)
	for _frame in 6:
		await process_frame
	var ribbon := spike.get_node("%VoiceRibbon") as Control
	var scroll := spike.get_node("%Scroll") as ScrollContainer
	scroll.ensure_control_visible(spike.get_node("%RemoPanel") as Control)
	for _frame in 6:
		await process_frame
	var capture := BufferedCapture.new()
	spike.add_child(capture)
	spike.set("_capture", capture)
	var calls := int(game.get("_calls"))
	var position := ribbon.get_global_transform_with_canvas() * (ribbon.size * Vector2(0.5, 0.6))
	var touch_setup := "visible=%s, enabled=%s, hit=%s, position=%s, rect=%s, scroll=%s" % [
		ribbon.is_visible_in_tree(), ribbon.get("enabled"),
		ribbon.call("_hit", ribbon, position), position, ribbon.get_global_rect(),
		scroll.get_global_rect(),
	]
	_send_touch(4, position)
	spike.call("_process", 0.4)
	_expect(
		bool(spike.get("_remo_active")) and capture.stopped and spike.get("_capture") == null,
		"Touching the ribbon must open Remo and disconnect any ready microphone. " + touch_setup
	)
	var break_button := spike.get_node("%RemoBreak") as Button
	var break_position := break_button.get_global_transform_with_canvas() * (break_button.size * 0.5)
	_send_touch(8, break_position)
	spike.call("_process", 0.04)
	_send_touch(8, break_position, false)
	spike.call("_process", 0.2)
	var source := spike.get("_remo") as RefCounted
	_expect(
		bool(source.call("has_contact", 4)) and bool(source.call("is_voiced"))
		and is_equal_approx(float(source.get("pitch_cents")), 700.0),
		"A second actual touch must operate Break without releasing the ribbon finger. "
		+ "break=%s hit=%s ribbon=%s pitch=%s voiced=%s scroll=%s spike=%s" % [
			break_button.get_global_rect(), ribbon.call("_hit", break_button, break_position),
			ribbon.get_global_rect(), source.get("pitch_cents"), source.call("is_voiced"),
			scroll.get_global_rect(), spike.get_global_rect(),
		]
	)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = position + Vector2(0, ribbon.size.y * 0.3)
	drag.velocity = Vector2(0, ribbon.size.y * 5.0)
	get_root().push_input(drag, true)
	spike.call("_process", 0.12)
	_send_touch(4, drag.position, false)
	var result: Dictionary = spike.get("_last_result")
	_expect(
		not bool(spike.get("_remo_active")) and bool(result.get("valid", false))
		and int(game.get("_calls")) == calls + 1
		and float(result["marks"]["remate"]) == 1.0,
		"A real downward touch flick must finish and score the same shared track."
	)
	_send_touch(10, position)
	spike.call("_process", 0.2)
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = false
	mouse.position = position
	get_root().push_input(mouse, true)
	_expect(
		bool(source.call("has_contact", 10)) and bool(source.call("is_voiced")),
		"An emulated mouse release must not steal a real touch's Voice hold."
	)
	spike.call("stop_capture")
	_send_touch(10, position, false)
	settings.set("_values", original)
	get_root().size = old_size
	get_root().min_size = old_minimum
	settings.call("_update_content_scale")
	settings.emit_signal("changed", "ui/scale", original["ui/scale"])
	for _frame in 6:
		await process_frame


func _test_remo_cancellation(game: Node, spike: Control) -> void:
	spike.call("load_example", true)
	spike.call("keep_reference")
	var reference: Array = (spike.get("_reference") as Array).duplicate(true)
	var calls := int(game.get("_calls"))
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values[Options.VOICE_KEY] = KEY_Z
	settings.set("_values", values)
	settings.emit_signal("changed", Options.VOICE_KEY, KEY_Z)
	(spike.get_node("%StartRemo") as Button).pressed.emit()
	_send_key(KEY_SPACE)
	spike.call("_process", 0.1)
	var track: Array = spike.get("_track")
	_expect(
		not bool(track[-1]["voiced"]),
		"The old key must no longer voice after a live Controls rebinding."
	)
	_send_key(KEY_Z)
	spike.call("_process", 0.2)
	track = spike.get("_track")
	_expect(bool(track[-1]["voiced"]), "The rebound Voice key must reach the real Remo window.")
	spike.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(
		not bool(spike.get("_remo_active")) and not (spike.get("_remo_tone") as AudioStreamPlayer).playing
		and (spike.get("_track") as Array).is_empty() and int(game.get("_calls")) == calls
		and (spike.get("_reference") as Array) == reference,
		"Focus loss must cancel Remo, stop audio and preserve the prior score/reference."
	)
	_send_key(KEY_Z, false)
	settings.set("_values", original)
	settings.emit_signal("changed", Options.VOICE_KEY, original[Options.VOICE_KEY])
	(spike.get_node("%StartRemo") as Button).pressed.emit()
	spike.call("_process", 0.2)
	game.call("open_pause_menu")
	_expect(
		not bool(spike.get("_remo_active")) and int(game.get("_calls")) == calls
		and (spike.get("_reference") as Array) == reference,
		"The real pause overlay must cancel Remo without counting an unfinished call."
	)
	var pause := game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	_expect(not paused, "Resuming the pause overlay must restore actual gameplay input.")
	spike.call("clear_reference")
	spike.call("load_example", true)


func _send_key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	get_root().push_input(event, true)


func _send_pad(button: JoyButton, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	event.device = 0
	get_root().push_input(event, true)


func _send_touch(index: int, position: Vector2, pressed := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	get_root().push_input(event, true)


func _test_empty_recording(game: Node, spike: Control) -> void:
	var calls := int(game.get("_calls"))
	var score := int(game.get("_scores")[0])
	var capture := BufferedCapture.new()
	spike.add_child(capture)
	spike.set("_capture", capture)
	spike.call("_toggle_recording")
	spike.call("_finish_recording")
	var result: Dictionary = spike.get("_last_result")
	_expect(
		not bool(result.get("valid", true))
		and (spike.get_node("%Status") as Label).text.contains("No analyzable audio"),
		"Stopping before any PCM can be analyzed must explain the failure, not score silence."
	)
	_expect(
		int(game.get("_calls")) == calls and int(game.get("_scores")[0]) == score,
		"An empty recording must not add a call or replace the last real score."
	)
	capture.pending.resize(int(AudioServer.get_mix_rate() * 0.2))
	spike.call("_toggle_recording")
	spike.call("_finish_recording")
	result = spike.get("_last_result")
	_expect(
		bool(result.get("valid", false)) and is_zero_approx(float(result["total"]))
		and int(game.get("_calls")) == calls + 1,
		"Stop must drain queued PCM; actual silence is a valid zero-score call, unlike missing audio."
	)
	spike.call("stop_capture")


func _test_recording_ui(spike: Control) -> void:
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var temporary := original.duplicate(true)
	temporary[Options.LONG_WINDOWS_KEY] = true
	temporary[Options.QUIET_MODE_KEY] = true
	temporary[Options.MIC_SENSITIVITY_KEY] = 0.5
	settings.set("_values", temporary)
	settings.emit_signal("changed", Options.LONG_WINDOWS_KEY, true)
	var capture := BufferedCapture.new()
	var pcm := _microphone_pcm()
	capture.pending = pcm
	spike.add_child(capture)
	spike.set("_capture", capture)
	spike.call("_toggle_recording")
	_expect(
		bool(spike.get("_recording")) and capture.discarded,
		"Record must discard pre-cue audio and open the real microphone pipeline."
	)
	_expect(
		not bool((spike.get("_profile") as Dictionary)["falsetto_calibrated"]),
		"Switching from Remo must not treat a human's unmeasured band as authored/calibrated."
	)
	_expect(
		is_equal_approx(float(spike.get("_window")), 9.0),
		"Long windows must reach the interactive recording path."
	)
	spike.call("_process", 2.0)
	spike.call("_process", 2.0)
	capture.pending = pcm
	spike.call("_process", 2.0)
	spike.call("_process", 3.1)
	var result: Dictionary = spike.get("_last_result")
	_expect(
		not bool(spike.get("_recording")) and bool(result.get("valid", false))
		and float(result["evidence"]["voiced_seconds"]) > 0.8,
		"The recording deadline must score actual buffered PCM and close the window."
	)
	_expect(
		not bool(result["power_gated"]),
		"Quiet Mode must bypass the power gate in the interactive microphone path."
	)
	var invalid_reference: Array[Dictionary] = [
		{"t": 0.0, "cents": 0.0, "voiced": false, "level": -1.0},
	]
	spike.set("_reference", invalid_reference)
	capture.pending = pcm
	spike.call("_toggle_recording")
	spike.call("_process", 1.2)
	spike.call("_finish_recording")
	_expect(
		not bool((spike.get("_last_result") as Dictionary)["valid"])
		and (spike.get_node("%Status") as Label).text.contains("negative"),
		"A rejected track must retain its scoring error, not claim no voice was heard."
	)
	(spike.get_node("%ShapedExample") as Button).pressed.emit()
	_expect(
		not bool((spike.get("_last_result") as Dictionary)["valid"])
		and (spike.get_node("%Status") as Label).text.contains("negative")
		and (spike.get_node("%KeepReference") as Button).disabled,
		"A rejected example must retain its error and cannot become a reference."
	)
	spike.call("clear_reference")
	spike.call("_on_capture_failed", "Microphone permission denied (test).")
	_expect(
		spike.get("_capture") == null
		and (spike.get_node("%Status") as Label).text.contains("permission denied"),
		"A capture failure must release input and display its actual reason."
	)
	(spike.get_node("%ShapedExample") as Button).pressed.emit()
	_expect(
		bool((spike.get("_last_result") as Dictionary)["valid"]),
		"A failed microphone must not block the hardware-free examples."
	)
	settings.set("_values", original)
	settings.emit_signal("changed", Options.LONG_WINDOWS_KEY, original[Options.LONG_WINDOWS_KEY])


func _test_stalled_recording(game: Node, spike: Control) -> void:
	spike.call("keep_reference")
	var reference: Array = (spike.get("_reference") as Array).duplicate(true)
	var calls := int(game.get("_calls"))
	var score := int(game.get("_scores")[0])
	var capture := BufferedCapture.new()
	capture.pending = _microphone_pcm()
	spike.add_child(capture)
	spike.set("_capture", capture)
	spike.call("_toggle_recording")
	spike.call("_process", 1.2)
	_expect(
		not (spike.get("_track") as Array).is_empty(),
		"The stalled-input regression must begin with actual analyzed PCM."
	)
	spike.call("_process", 2.0)
	_expect(
		bool(spike.get("_recording")),
		"A short gap between buffers must not disconnect a listening microphone."
	)
	spike.call("_process", 2.1)
	_expect(
		spike.get("_capture") == null and capture.stopped
		and not bool(spike.get("_recording"))
		and (spike.get_node("%Status") as Label).text.contains("No microphone audio"),
		"A four-second PCM stall must disconnect capture and display its failure."
	)
	_expect(
		int(game.get("_calls")) == calls and int(game.get("_scores")[0]) == score,
		"A stalled recording must not submit a partial performance as a score."
	)
	spike.call("stop_capture")
	_expect(
		(spike.get("_track") as Array).is_empty()
		and (spike.get_node("%KeepReference") as Button).disabled,
		"An interrupted call must not leave an unfinished track available as a reference."
	)
	spike.call("keep_reference")
	_expect(
		(spike.get("_reference") as Array) == reference,
		"Attempting to keep an interrupted call must preserve the earlier valid reference."
	)
	spike.call("clear_reference")
	spike.call("load_example", true)


func _microphone_pcm() -> PackedVector2Array:
	var result := PackedVector2Array()
	var rate := AudioServer.get_mix_rate()
	for index in int(rate * 1.2):
		var sample := sin(TAU * 160.0 * float(index) / rate) * 0.05 if index < rate else 0.0
		result.append(Vector2(sample, sample))
	return result


func _test_layouts(spike: Control) -> void:
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	get_root().min_size = Vector2i.ZERO
	for dimensions in [
		Vector2i(320, 568), Vector2i(568, 320),
		Vector2i(1280, 720), Vector2i(2560, 1080),
	]:
		get_root().size = dimensions
		for preference in [1.0, 1.5]:
			var values := original.duplicate(true)
			values["ui/scale"] = preference
			settings.set("_values", values)
			settings.call("_update_content_scale")
			settings.emit_signal("changed", "ui/scale", preference)
			for _frame in 6:
				await process_frame
			await _check_layout(spike, dimensions, preference)
	settings.set("_values", original)
	settings.call("_update_content_scale")
	settings.emit_signal("changed", "ui/scale", original["ui/scale"])
	get_root().size = old_size
	get_root().min_size = old_minimum
	await process_frame


func _check_layout(spike: Control, dimensions: Vector2i, preference: float) -> void:
	var scroll := spike.get_node("%Scroll") as ScrollContainer
	var bounds := Rect2(Vector2.ZERO, Vector2(dimensions)).grow(2.0)
	_expect(
		bounds.encloses(_native_rect(scroll)),
		"The actual scroll viewport must fit the physical window at %s." % dimensions
	)
	_expect(
		scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1.0,
		"The scorer must fit %s without horizontal clipping." % dimensions
	)
	for name in [
		"EnableMicrophone", "RecordCall", "ShapedExample", "FlatExample",
		"KeepReference", "ClearReference", "StartRemo", "RemoBreak", "RemoFinish",
	]:
		var button := spike.get_node("%" + name) as Button
		_expect(
			button.size.x <= scroll.size.x
			and _native_rect(button).size.y >= 43.0 * preference,
			"%s must remain a reachable touch target at %s (UI %.1f)."
			% [name, dimensions, preference]
		)
		scroll.ensure_control_visible(button)
		for _frame in 6:
			await process_frame
		_expect(
			bounds.encloses(_native_rect(button)),
			"%s must scroll wholly into the physical screen at %s." % [name, dimensions]
		)
	var text := spike.get_node("%Marks") as Label
	var transform := get_root().get_final_transform() * text.get_global_transform_with_canvas()
	_expect(
		float(text.get_theme_font_size("font_size")) * transform.get_scale().y >= 16.0 * preference,
		"Marks must remain physically legible at %s (UI %.1f)." % [dimensions, preference]
	)
	scroll.ensure_control_visible(spike.get_node("%VoiceRibbon") as Control)
	for _frame in 6:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_root().get_texture().get_image()
		_expect(not image.is_empty(), "The spike must produce a real rendered frame.")
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--sailor-capture-dir="):
				var folder := argument.trim_prefix("--sailor-capture-dir=")
				var error := DirAccess.make_dir_recursive_absolute(folder)
				_expect(error == OK, "Could not create the requested capture folder.")
				error = image.save_png(folder.path_join(
					"sailor-%dx%d%s.png" % [
						dimensions.x, dimensions.y, "-large-ui" if preference > 1.0 else "",
					]
				))
				_expect(error == OK, "Could not save the requested layout capture.")


func _native_rect(control: Control) -> Rect2:
	return get_root().get_final_transform() * control.get_global_transform_with_canvas() \
		* Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
