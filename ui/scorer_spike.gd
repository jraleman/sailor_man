extends Control

## Source-neutral voice workbench, shared by the shell and the dev-only scene.
## Microphone access stays opt-in; Remo never needs it. Tracks stay in memory.

signal score_ready(result: Dictionary)
signal pause_requested
signal finish_requested
signal duel_requested
signal duel_frames_ready(frames: Array[Dictionary])
signal duel_turn_cancelled(reason: String)

@export var standalone_tool := false

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const Capture = preload("res://games/sailor_man/voice/mic_capture.gd")
const Source = preload("res://games/sailor_man/voice/mic_voice_source.gd")
const RemoSource = preload("res://games/sailor_man/voice/touch_voice_source.gd")
const RemoTone = preload("res://games/sailor_man/audio/remo_tone.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const NORMAL_WINDOW := 6.0
const LONG_WINDOW := 9.0
const MARK_NAMES := {
	"aliento": "Aliento / Breath", "quiebre": "Quiebre / Break",
	"altura": "Altura / Range", "remate": "Remate / Finish", "eco": "Eco / Echo",
}

@onready var _status: Label = %Status
@onready var _device: OptionButton = %InputDevice
@onready var _enable: Button = %EnableMicrophone
@onready var _record: Button = %RecordCall
@onready var _reference_button: Button = %KeepReference
@onready var _clear_reference: Button = %ClearReference
@onready var _chest: SpinBox = %ChestHz
@onready var _carry: SpinBox = %CarryLevel
@onready var _ribbon: Control = %VoiceRibbon
@onready var _marks: Label = %Marks
@onready var _options_label: Label = %OptionsLabel

var _capture: Node
var _source := Source.new()
var _remo := RemoSource.new()
var _remo_tone: RemoTone
var _remo_active := false
var _remo_bindings: Dictionary[StringName, int] = {}
var _remo_triggers: Dictionary[int, bool] = {}
var _track: Array[Dictionary] = []
var _reference: Array[Dictionary] = []
var _profile := Frame.profile()
var _last_result: Dictionary = {}
var _noise_floor := 0.004
var _recording := false
var _elapsed := 0.0
var _no_audio_seconds := 0.0
var _window := NORMAL_WINDOW
var _quiet := false
var _sensitivity := 1.0
var _ui_unit := 0.0
var _duel_mode := false
var _duel_microphone := false
var _duel_turn_open := false
var _duel_observed_frames := 0
var _duel_frame_limit := 0


func _ready() -> void:
	_enable.pressed.connect(_toggle_microphone)
	_record.pressed.connect(_toggle_recording)
	_reference_button.pressed.connect(keep_reference)
	_clear_reference.pressed.connect(clear_reference)
	(%StartRemo as Button).pressed.connect(_toggle_remo)
	(%RemoBreak as Button).pressed.connect(func() -> void: _remo.quiebre())
	(%RemoFinish as Button).pressed.connect(func() -> void: _remo.remate())
	_ribbon.set("source", _remo)
	_ribbon.set("break_button", %RemoBreak)
	_ribbon.connect("turn_requested", _start_remo)
	_remo_tone = RemoTone.new()
	add_child(_remo_tone)
	(%ShapedExample as Button).pressed.connect(load_example.bind(true))
	(%FlatExample as Button).pressed.connect(load_example.bind(false))
	(%Pause as Button).pressed.connect(func() -> void: pause_requested.emit())
	(%FinishSession as Button).pressed.connect(func() -> void: finish_requested.emit())
	(%BackToDuel as Button).pressed.connect(func() -> void: duel_requested.emit())
	(%Pause as Button).visible = not standalone_tool
	(%FinishSession as Button).visible = not standalone_tool
	for device: String in AudioServer.get_input_device_list():
		_device.add_item(device)
		if device == AudioServer.input_device:
			_device.select(_device.item_count - 1)
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.connect("changed", _on_setting_changed)
	get_viewport().size_changed.connect(_fit_ui)
	resized.connect(_fit_ui)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_reload_bindings()
	_reload_options()
	_update_controls()
	_fit_ui.call_deferred()


func _process(delta: float) -> void:
	if _remo_active:
		_process_remo(delta)
		return
	if _capture == null or not bool(_capture.call("is_ready")):
		return
	var frames: PackedVector2Array = _capture.call("poll")
	if not _recording:
		return
	_elapsed += delta
	_no_audio_seconds = _no_audio_seconds + delta if frames.is_empty() else 0.0
	if _no_audio_seconds >= Capture.NO_INPUT_TIMEOUT:
		var error := (
			"No microphone audio arrived for %.0f seconds. Check the device and "
			+ "microphone permission, then enable it again. Remo needs no microphone."
		) % Capture.NO_INPUT_TIMEOUT
		push_warning("Sailor Man recording: %s" % error)
		_on_capture_failed(error)
		return
	_track.append_array(_source.push_frames(frames))
	_publish_duel_frames()
	_ribbon.call("show_tracks", _track, _reference, {}, _window)
	_status.text = "Listening: %.1f / %.0f s. Stop whenever comfortable." % [_elapsed, _window]
	if _elapsed >= _window:
		_finish_recording()


func _input(event: InputEvent) -> void:
	var voice_pressed := _is_remo_voice_press(event)
	if (
		_recording or not is_visible_in_tree() or event.is_action_pressed(&"pause")
		or (_duel_mode and not _duel_turn_open)
	):
		return
	if not _remo_active:
		if not _ribbon.has_focus() or not voice_pressed:
			return
		_start_remo()
	if _remo.handle_event(event, _remo_bindings):
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		InputMap.has_action(Options.RECORD_ACTION)
		and event.is_action_pressed(Options.RECORD_ACTION) and not event.is_echo()
	):
		_toggle_recording()
		get_viewport().set_input_as_handled()


## Deliberately synthetic visual fixtures, never a stand-in for a cast rival.
func load_example(shaped: bool) -> void:
	if _duel_mode:
		_status.text = "Synthetic examples belong to Practice, not a scored duel turn."
		return
	_cancel_recording()
	_cancel_remo()
	_profile = Frame.profile()
	_track.clear()
	for index in 550:
		var t := float(index) / Frame.RATE_HZ
		var pitch := 0.0
		if shaped:
			if t >= 1.2 and t < 2.4:
				pitch = 1000.0
			elif t >= 3.6 and t < 4.6:
				pitch = 1000.0
			elif t >= 4.6 and t < 5.0:
				pitch = 1000.0 * (5.0 - t) / 0.4
		_track.append(Frame.make(t, pitch, t < 5.0, 1.0 if t < 5.0 else 0.0))
	if not _judge():
		return
	_status.text = (
		"SYNTHETIC shaped fixture - not a saloma recording."
		if shaped else "SYNTHETIC flat hold - not a saloma recording."
	)


## Eco uses the next performance, not a retroactive perfect match of this one.
func keep_reference() -> void:
	if (
		_recording or _remo_active or _track.is_empty()
		or not bool(_last_result.get("valid", false))
	):
		_status.text = "Finish and score a valid call before keeping a reference."
		return
	_reference = _track.duplicate(true)
	_clear_reference.disabled = false
	_status.text = "Reference kept. Try Remo, record or load the next answer to test Eco."
	_ribbon.call("show_tracks", _track, _reference, _last_result.get("evidence", {}), _window)


## Returning to call mode removes Eco's weight rather than scoring it as zero.
func clear_reference() -> void:
	_reference.clear()
	_clear_reference.disabled = true
	_status.text = "Reference cleared. The next performance is a call."
	_ribbon.call("show_tracks", _track, _reference, _last_result.get("evidence", {}), _window)


## Replays do not inherit an earlier call, score or live capture session.
func reset_session() -> void:
	stop_capture()
	_track.clear()
	_reference.clear()
	_last_result.clear()
	_marks.text = "No call scored yet. Try Remo, enable a microphone or load an example."
	_status.text = "Microphone off. Start a Remo call or hold the ribbon; no microphone needed."
	_ribbon.call("show_tracks", _track, _reference, {}, _window)
	_update_controls()


## The duel reuses this input path, but only its model may open a scored window.
func configure_duel(enabled: bool, microphone := false) -> void:
	stop_capture()
	_duel_mode = enabled
	_duel_microphone = microphone
	_duel_turn_open = false
	set_process(not enabled)
	_ui_unit = 0.0
	_update_controls()
	_fit_ui()


## Room checks stay explicit; neither source selection nor a cue opens a device.
func microphone_ready() -> bool:
	return _capture != null and bool(_capture.call("is_ready"))


## Discard idle audio at the real cue and preserve only this tanda's call.
func begin_duel_turn(reference: Array[Dictionary]) -> bool:
	assert(_duel_mode)
	if _duel_microphone and not microphone_ready():
		_status.text = "Enable the microphone and finish its room check, or use Remo."
		_duel_fail(_status.text)
		return false
	_reference = reference.duplicate(true)
	_duel_observed_frames = 0
	_duel_frame_limit = roundi(_window * Frame.RATE_HZ)
	_duel_turn_open = true
	if _duel_microphone:
		_toggle_recording()
	else:
		_start_remo()
	var started := _recording or _remo_active
	if not started:
		_duel_fail(_status.text)
	return started


## One owner advances input and the duel clock in the same frame.
func advance_duel_input(delta: float) -> void:
	assert(_duel_mode)
	_process(delta)


## Early silence and model deadlines finish through the existing buffered Stop path.
func finish_duel_turn() -> void:
	if _recording:
		_finish_recording()
	elif _remo_active:
		_finish_remo()


## A buffered poll must not score samples after the model's real-silence cutoff.
func limit_duel_turn(frame_count: int) -> void:
	assert(_duel_mode and frame_count >= 0)
	_duel_frame_limit = mini(_duel_frame_limit, frame_count)
	if _track.size() > _duel_frame_limit:
		_track.resize(_duel_frame_limit)


## Explicitly release both input paths and the tone on pause, results or exit.
func stop_capture() -> void:
	_cancel_recording()
	_cancel_remo()
	if is_instance_valid(_capture):
		_capture.call("stop")
		_capture.queue_free()
	_capture = null
	if is_instance_valid(_status):
		_status.text = "Microphone disconnected. Enable it again when ready."
		_update_controls()


func _toggle_microphone() -> void:
	_cancel_remo()
	if _capture != null:
		stop_capture()
		return
	if _device.item_count == 0:
		_status.text = "No input device is available. Remo needs no microphone."
		_update_controls()
		return
	_capture = Capture.new()
	_capture.connect("calibrated", _on_calibrated)
	_capture.connect("capture_failed", _on_capture_failed)
	add_child(_capture)
	_status.text = "Room check: stay quiet for two seconds. Headphones are recommended."
	_capture.call("start", _device.get_item_text(_device.selected))
	_update_controls()


func _on_calibrated(noise_floor: float) -> void:
	_noise_floor = noise_floor
	_status.text = (
		"Room check complete. Set a comfortable chest reference, then Record. "
		+ "This is not yet a full vocal-range calibration."
	)
	if _duel_mode:
		_status.text = (
			"Room check complete. Set a comfortable chest reference, then press Ready "
			+ "for your turn. This is not a full vocal-range calibration."
		)
	_update_controls()


func _on_capture_failed(reason: String) -> void:
	stop_capture()
	_status.text = reason
	_duel_fail(reason)


func _toggle_recording() -> void:
	if _duel_mode and (not _duel_turn_open or not _duel_microphone):
		_status.text = "Recording is available only in an admitted Microphone turn."
		return
	_cancel_remo()
	if _recording:
		_finish_recording()
		return
	if _capture == null or not bool(_capture.call("is_ready")):
		_status.text = "Enable the microphone and finish the room check first."
		_update_controls()
		return
	_profile = Frame.profile(_chest.value)
	_profile["carry_level"] = _carry.value
	var error := Frame.profile_error(_profile)
	if not error.is_empty():
		_status.text = error
		_update_controls()
		return
	_capture.call("discard")
	_source.begin(AudioServer.get_mix_rate(), _profile, _noise_floor, _sensitivity)
	_track.clear()
	_last_result.clear()
	_elapsed = 0.0
	_no_audio_seconds = 0.0
	_recording = true
	_marks.text = "Listening. Use a comfortable voice; extra volume earns nothing."
	_ribbon.call("show_tracks", _track, _reference, {}, _window)
	_update_controls()


func _finish_recording() -> void:
	if not _recording:
		return
	# GUI input can stop the call before this frame's regular poll.
	if _capture != null and bool(_capture.call("is_ready")):
		var frames: PackedVector2Array = _capture.call("poll")
		_track.append_array(_source.push_frames(frames))
	_track.append_array(_source.finish())
	_publish_duel_frames()
	_recording = false
	if _track.is_empty():
		var error := (
			"No analyzable audio was captured. Try a longer call, or check the "
			+ "microphone device and permission."
		)
		_last_result = {"valid": false, "error": error}
		_status.text = error
		_marks.text = "No call scored."
		push_warning("Sailor Man recording: %s" % error)
		_update_controls()
		_duel_fail(error)
		return
	if not _judge():
		return
	_status.text = (
		"Call scored. Rest whenever needed; try the synthetic examples instead."
		if float(_last_result.get("total", 0.0)) > 0.0
		else "No voiced input was detected. Check the device or try a synthetic example."
	)


func _cancel_recording() -> void:
	if _recording:
		_source.finish()
		_track.clear()
		_last_result.clear()
		_marks.text = "Call cancelled. No score recorded."
		_ribbon.call("show_tracks", _track, _reference, {}, _window)
		_duel_fail("Microphone turn cancelled. Ready again to retry the same turn.")
	_recording = false
	_elapsed = 0.0
	_no_audio_seconds = 0.0


func _toggle_remo() -> void:
	if _remo_active:
		_finish_remo()
	else:
		_start_remo()


func _start_remo() -> void:
	if _duel_mode and (not _duel_turn_open or _duel_microphone):
		_status.text = "Remo is available only in an admitted Remo turn."
		return
	stop_capture()
	_profile = RemoSource.profile()
	_track.clear()
	_last_result.clear()
	_elapsed = 0.0
	_remo.begin()
	_remo_active = true
	_marks.text = "Remo listening. Hold Voice, shape the pitch, then finish."
	_status.text = "Remo uses buttons or touch, not your microphone. Preview: synthetic tone."
	_ribbon.call("show_tracks", _track, _reference, {}, _window)
	if _duel_mode:
		_ribbon.grab_focus.call_deferred()
	else:
		_ribbon.grab_focus()
	_update_controls()
	(%Scroll as ScrollContainer).ensure_control_visible.call_deferred(%RemoPanel)


func _process_remo(delta: float) -> void:
	var step := minf(delta, maxf(_window - _elapsed, 0.0))
	var frames := _remo.advance(step)
	_track.append_array(frames)
	_publish_duel_frames()
	_elapsed += step
	if not frames.is_empty():
		_remo_tone.play_frame(frames[-1])
	_ribbon.call("show_tracks", _track, _reference, {}, _window)
	_status.text = "Remo: %.1f / %.0f s | Synthetic tone, not a captain recording." % [
		_elapsed, _window,
	]
	if _remo.is_finished() or _elapsed >= _window:
		_finish_remo()


func _finish_remo() -> void:
	if not _remo_active:
		return
	_remo_active = false
	_remo.finish()
	_remo_tone.stop()
	if _track.is_empty():
		_status.text = "No Remo frames captured. Start a call and hold Voice or the ribbon."
		_marks.text = "No call scored."
		_update_controls()
		_duel_fail(_status.text)
		return
	if _judge():
		_status.text = "Remo scored by the shared saloma scorer. Keep it as a reference to test Eco."


func _cancel_remo() -> void:
	if _remo_active:
		_track.clear()
		_last_result.clear()
		_marks.text = "Remo call cancelled. No score recorded."
		_ribbon.call("show_tracks", _track, _reference, {}, _window)
		_duel_fail("Remo turn cancelled. Ready again to retry the same turn.")
	_remo_active = false
	_remo.finish()
	if is_instance_valid(_remo_tone):
		_remo_tone.stop()
	if is_instance_valid(_ribbon):
		_ribbon.call("clear_contacts")


func _is_remo_voice_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := int(key.physical_keycode if key.physical_keycode != KEY_NONE
			else key.keycode)
		return key.pressed and not key.echo and code == _remo_bindings.get(&"voice", KEY_NONE)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index == JOY_BUTTON_A
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis != JOY_AXIS_TRIGGER_RIGHT:
			return false
		var held := motion.axis_value > RemoSource.TRIGGER_THRESHOLD
		var pressed := held and not bool(_remo_triggers.get(motion.device, false))
		# Keep the edge across turn boundaries so analog jitter cannot restart.
		_remo_triggers[motion.device] = held
		return pressed
	return false


func _reload_bindings() -> void:
	var settings := get_node_or_null("/root/Settings")
	_remo_bindings.clear()
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		if binding["action"] not in Options.REMO_ACTIONS:
			continue
		var action := StringName(str(binding["action"]).trim_prefix("sailor_man_"))
		_remo_bindings[action] = int(
			settings.call("binding_keycode", str(binding["key"]))
			if settings != null else binding["default"]
		)
	(%RemoHelp as Label).text = (
		"Start Remo, then hold %s for Voice. Pitch: %s / %s (or arrows). "
		+ "%s: Quiebre. %s: Remate.\n"
		+ "Pad: hold A / RT; left stick or D-pad for pitch; X / RB for Break; B to finish.\n"
		+ "Touch or mouse: hold the ribbon and drag vertically. Flick up or press Break; "
		+ "flick down to finish. The preview is a synthetic tone, not a captain recording."
	) % [
		OS.get_keycode_string(_remo_bindings[&"voice"]),
		OS.get_keycode_string(_remo_bindings[&"pitch_up"]),
		OS.get_keycode_string(_remo_bindings[&"pitch_down"]),
		OS.get_keycode_string(_remo_bindings[&"quiebre"]),
		OS.get_keycode_string(_remo_bindings[&"remate"]),
	]


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_remo.forget_device(device)
		_remo_triggers.erase(device)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and _remo_active:
		_cancel_remo()
		_status.text = "Remo cancelled when the window lost focus. Start again when ready."
		_update_controls()


func _judge() -> bool:
	_last_result = Scorer.score(_track, _profile, _reference, _quiet)
	if not bool(_last_result["valid"]):
		_status.text = str(_last_result["error"])
		_marks.text = "No call scored."
		_update_controls()
		_duel_fail(_status.text)
		return false
	var lines := PackedStringArray()
	lines.append("%s: %.1f / 100" % [
		"ANSWER" if bool(_last_result["answering"]) else "CALL",
		float(_last_result["total"]) * 100.0,
	])
	var marks: Dictionary = _last_result["marks"]
	for key: String in MARK_NAMES:
		lines.append(
			"%s: %.0f%%" % [MARK_NAMES[key], float(marks[key]) * 100.0]
			if key != "eco" or bool(_last_result["answering"])
			else "Eco / Echo: answers only"
		)
	var evidence: Dictionary = _last_result["evidence"]
	lines.append("Breaks: %d | Longest breath: %.2f s | Power gate: %s" % [
		(evidence["breaks"] as Array).size(),
		float(evidence["longest_breath"]["seconds"]),
		"-20%" if bool(_last_result["power_gated"]) else "none",
	])
	_marks.text = "\n".join(lines)
	_ribbon.call("show_tracks", _track, _reference, evidence, _window)
	print("Sailor Man scorer: %s" % JSON.stringify(_last_result))
	_duel_turn_open = false
	score_ready.emit(_last_result)
	_update_controls()
	return true


func _reload_options() -> void:
	var settings := get_node_or_null("/root/Settings")
	if (
		settings != null
		and not (settings.call("options_for_game", Options.GAME_ID) as Array).is_empty()
	):
		_quiet = bool(settings.call("tunable_bool", Options.QUIET_MODE_KEY))
		_window = LONG_WINDOW if bool(
			settings.call("tunable_bool", Options.LONG_WINDOWS_KEY)
		) else NORMAL_WINDOW
		_sensitivity = float(settings.call("tunable", Options.MIC_SENSITIVITY_KEY))
	_options_label.text = (
		"%.0f s window | Quiet Mode %s | Sensitivity %.0f%%\n"
		+ "Mic: unmeasured falsetto uses the softer rule. Remo: authored 700-1300-cent band."
	) % [_window, "on" if _quiet else "off", _sensitivity * 100.0]


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key in [Options.QUIET_MODE_KEY, Options.LONG_WINDOWS_KEY, Options.MIC_SENSITIVITY_KEY]:
		_reload_options()
	elif key == "ui/scale":
		_fit_ui()
	else:
		for binding: Dictionary in Options.CONTROL_BINDINGS:
			if key == str(binding["key"]):
				_cancel_remo()
				_reload_bindings()
				_update_controls()
				break


func _fit_ui() -> void:
	var transform := get_window().get_final_transform() * get_global_transform_with_canvas()
	var settings := get_node_or_null("/root/Settings")
	var preference := float(settings.call("get_value", "ui/scale", 1.0)) if settings != null else 1.0
	(%Profile as GridContainer).columns = 1 if float(get_window().size.x) / preference < 480.0 else 2
	var unit := preference / maxf(transform.get_scale().x, 0.001)
	var ribbon_height := 180.0 * preference
	if _duel_mode:
		var available := size.y * transform.get_scale().y - 58.0 * preference
		ribbon_height = maxf(80.0 * preference, minf(ribbon_height, available))
	_ribbon.custom_minimum_size.y = ribbon_height / maxf(transform.get_scale().y, 0.001)
	if is_equal_approx(unit, _ui_unit):
		return
	_ui_unit = unit
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control is Label or control is BaseButton or control is LineEdit:
			control.add_theme_font_size_override("font_size", roundi(17.0 * unit))
		if control is BaseButton:
			control.custom_minimum_size.y = 44.0 * unit
		if control is HFlowContainer:
			control.add_theme_constant_override("h_separation", roundi(8.0 * unit))
			control.add_theme_constant_override("v_separation", roundi(8.0 * unit))
	(%Title as Label).add_theme_font_size_override("font_size", roundi(22.0 * unit))
	(%Content as VBoxContainer).add_theme_constant_override("separation", roundi(10.0 * unit))
	(%RemoPanel as VBoxContainer).add_theme_constant_override(
		"separation", roundi((6.0 if _duel_mode else 10.0) * unit))
	(%Profile as GridContainer).add_theme_constant_override("h_separation", roundi(12.0 * unit))
	(%Profile as GridContainer).add_theme_constant_override("v_separation", roundi(8.0 * unit))
	var margin := (4.0 if _duel_mode else 16.0) * unit
	Responsive.set_margins(%Margins, roundi(margin), roundi(margin),
		roundi(margin), roundi(margin))
	for spin: SpinBox in [_chest, _carry]:
		spin.custom_minimum_size = Vector2(110.0, 44.0) * unit
		spin.get_line_edit().add_theme_font_size_override("font_size", roundi(17.0 * unit))
	_ribbon.call("fit", unit)


func _update_controls() -> void:
	_record.disabled = _remo_active or _capture == null or not bool(_capture.call("is_ready"))
	_record.text = "Stop and score" if _recording else "Record call"
	_enable.text = "Disconnect mic" if _capture != null else "Enable microphone"
	_reference_button.disabled = (
		_recording or _remo_active or _track.is_empty()
		or not bool(_last_result.get("valid", false))
	)
	_clear_reference.disabled = _reference.is_empty() or _recording or _remo_active
	_device.disabled = _capture != null
	_chest.editable = not _recording and not _remo_active
	_carry.editable = not _recording and not _remo_active
	(%StartRemo as Button).text = "Stop Remo" if _remo_active else "Start Remo call"
	(%StartRemo as Button).disabled = _duel_mode and not _duel_turn_open
	(%RemoBreak as Button).disabled = not _remo_active
	(%RemoFinish as Button).disabled = not _remo_active
	_ribbon.set("enabled", not _recording)
	(%BackToDuel as Button).visible = not standalone_tool and not _duel_mode
	if _duel_mode:
		_record.disabled = _record.disabled or not _duel_turn_open
		_ribbon.set("enabled", _duel_turn_open and not _duel_microphone)
	_update_duel_presentation()


func _update_duel_presentation() -> void:
	for child: Control in (%Content as VBoxContainer).get_children():
		var shown := not _duel_mode
		if _duel_mode:
			match child.name:
				"DeviceTitle", "InputDevice", "Profile", "Status":
					shown = _duel_microphone and not _duel_turn_open
				"Actions":
					shown = _duel_microphone
				"RemoPanel":
					shown = true
		child.visible = shown
	_enable.visible = not _duel_mode or not _duel_turn_open
	_record.visible = not _duel_mode or _duel_turn_open
	(%StartRemo as Button).visible = not _duel_mode
	((%RemoBreak as Button).get_parent() as Control).visible = (
		not _duel_mode or not _duel_microphone
	)


func _publish_duel_frames() -> void:
	if not _duel_mode:
		return
	var maximum := mini(roundi(_window * Frame.RATE_HZ), _duel_frame_limit)
	if _track.size() > maximum:
		_track.resize(maximum)
	var frames := _track.slice(mini(_duel_observed_frames, _track.size()))
	_duel_observed_frames = _track.size()
	if not frames.is_empty():
		duel_frames_ready.emit(frames)


func _duel_fail(reason: String) -> void:
	if _duel_mode:
		_duel_turn_open = false
		duel_turn_cancelled.emit(reason)
		_update_controls()


func _exit_tree() -> void:
	stop_capture()
