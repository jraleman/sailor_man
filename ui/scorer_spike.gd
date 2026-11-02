extends Control

## Opt-in voice experiment, shared by the shell scaffold and the dev-only scene.
## Tracks stay in memory; no microphone samples or profiles are saved.

signal score_ready(result: Dictionary)
signal pause_requested
signal finish_requested

@export var standalone_tool := false

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const Capture = preload("res://games/sailor_man/voice/mic_capture.gd")
const Source = preload("res://games/sailor_man/voice/mic_voice_source.gd")
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
var _track: Array[Dictionary] = []
var _reference: Array[Dictionary] = []
var _profile := Frame.profile()
var _last_result: Dictionary = {}
var _noise_floor := 0.004
var _recording := false
var _elapsed := 0.0
var _window := NORMAL_WINDOW
var _quiet := false
var _sensitivity := 1.0
var _ui_unit := 0.0


func _ready() -> void:
	_enable.pressed.connect(_toggle_microphone)
	_record.pressed.connect(_toggle_recording)
	_reference_button.pressed.connect(keep_reference)
	_clear_reference.pressed.connect(clear_reference)
	(%ShapedExample as Button).pressed.connect(load_example.bind(true))
	(%FlatExample as Button).pressed.connect(load_example.bind(false))
	(%Pause as Button).pressed.connect(func() -> void: pause_requested.emit())
	(%FinishSession as Button).pressed.connect(func() -> void: finish_requested.emit())
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
	_reload_options()
	_update_controls()
	_fit_ui.call_deferred()


func _process(delta: float) -> void:
	if _capture == null or not bool(_capture.call("is_ready")):
		return
	var frames: PackedVector2Array = _capture.call("poll")
	if not _recording:
		return
	_elapsed += delta
	_track.append_array(_source.push_frames(frames))
	_ribbon.call("show_tracks", _track, _reference, {}, _window)
	_status.text = "Listening: %.1f / %.0f s. Stop whenever comfortable." % [_elapsed, _window]
	if _elapsed >= _window:
		_finish_recording()


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		InputMap.has_action(Options.RECORD_ACTION)
		and event.is_action_pressed(Options.RECORD_ACTION) and not event.is_echo()
	):
		_toggle_recording()
		get_viewport().set_input_as_handled()


## Deliberately synthetic visual fixtures, never a stand-in for a cast rival.
func load_example(shaped: bool) -> void:
	_cancel_recording()
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
	_judge()
	_status.text = (
		"SYNTHETIC shaped fixture - not a saloma recording."
		if shaped else "SYNTHETIC flat hold - not a saloma recording."
	)


## Eco uses the next performance, not a retroactive perfect match of this one.
func keep_reference() -> void:
	if _track.is_empty():
		_status.text = "Record or load a call before keeping a reference."
		return
	_reference = _track.duplicate(true)
	_clear_reference.disabled = false
	_status.text = "Reference kept. Record or load the next answer to test Eco."
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
	_marks.text = "No call scored yet. Enable the microphone or load a synthetic example."
	_status.text = "Microphone off. Nothing is recorded until you enable it."
	_ribbon.call("show_tracks", _track, _reference, {}, _window)
	_update_controls()


## Explicitly release input on pause, results or scene exit.
func stop_capture() -> void:
	_cancel_recording()
	if is_instance_valid(_capture):
		_capture.call("stop")
		_capture.queue_free()
	_capture = null
	if is_instance_valid(_status):
		_status.text = "Microphone disconnected. Enable it again when ready."
		_update_controls()


func _toggle_microphone() -> void:
	if _capture != null:
		stop_capture()
		return
	if _device.item_count == 0:
		_status.text = "No input device is available. The synthetic examples still work."
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
	_update_controls()


func _on_capture_failed(reason: String) -> void:
	stop_capture()
	_status.text = reason


func _toggle_recording() -> void:
	if _recording:
		_finish_recording()
		return
	if _capture == null or not bool(_capture.call("is_ready")):
		_status.text = "Enable the microphone and finish the room check first."
		return
	_profile = Frame.profile(_chest.value)
	_profile["carry_level"] = _carry.value
	var error := Frame.profile_error(_profile)
	if not error.is_empty():
		_status.text = error
		return
	_capture.call("discard")
	_source.begin(AudioServer.get_mix_rate(), _profile, _noise_floor, _sensitivity)
	_track.clear()
	_last_result.clear()
	_elapsed = 0.0
	_recording = true
	_marks.text = "Listening. Use a comfortable voice; extra volume earns nothing."
	_update_controls()


func _finish_recording() -> void:
	if not _recording:
		return
	_track.append_array(_source.finish())
	_recording = false
	_judge()
	if not bool(_last_result["valid"]):
		_update_controls()
		return
	_status.text = (
		"Call scored. Rest whenever needed; try the synthetic examples instead."
		if float(_last_result.get("total", 0.0)) > 0.0
		else "No voiced input was detected. Check the device or try a synthetic example."
	)
	_update_controls()


func _cancel_recording() -> void:
	if _recording:
		_source.finish()
	_recording = false
	_elapsed = 0.0


func _judge() -> void:
	_last_result = Scorer.score(_track, _profile, _reference, _quiet)
	if not bool(_last_result["valid"]):
		_status.text = str(_last_result["error"])
		return
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
	score_ready.emit(_last_result)
	_update_controls()


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
		+ "Unmeasured falsetto: the softer Quiebre rule is active."
	) % [_window, "on" if _quiet else "off", _sensitivity * 100.0]


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key in [Options.QUIET_MODE_KEY, Options.LONG_WINDOWS_KEY, Options.MIC_SENSITIVITY_KEY]:
		_reload_options()
	elif key == "ui/scale":
		_fit_ui()


func _fit_ui() -> void:
	var transform := get_window().get_final_transform() * get_global_transform_with_canvas()
	var settings := get_node_or_null("/root/Settings")
	var preference := float(settings.call("get_value", "ui/scale", 1.0)) if settings != null else 1.0
	(%Profile as GridContainer).columns = 1 if float(get_window().size.x) / preference < 480.0 else 2
	var unit := preference / maxf(transform.get_scale().x, 0.001)
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
	(%Profile as GridContainer).add_theme_constant_override("h_separation", roundi(12.0 * unit))
	(%Profile as GridContainer).add_theme_constant_override("v_separation", roundi(8.0 * unit))
	Responsive.set_margins(
		%Margins, roundi(16.0 * unit), roundi(16.0 * unit),
		roundi(16.0 * unit), roundi(16.0 * unit)
	)
	for spin: SpinBox in [_chest, _carry]:
		spin.custom_minimum_size = Vector2(110.0, 44.0) * unit
		spin.get_line_edit().add_theme_font_size_override("font_size", roundi(17.0 * unit))
	_ribbon.custom_minimum_size.y = 180.0 * unit
	_ribbon.call("fit", unit)


func _update_controls() -> void:
	_record.disabled = _capture == null or not bool(_capture.call("is_ready"))
	_record.text = "Stop and score" if _recording else "Record call"
	_enable.text = "Disconnect mic" if _capture != null else "Enable microphone"
	_reference_button.disabled = _track.is_empty() or _recording
	_clear_reference.disabled = _reference.is_empty() or _recording
	_device.disabled = _capture != null
	_chest.editable = not _recording
	_carry.editable = not _recording


func _exit_tree() -> void:
	stop_capture()
