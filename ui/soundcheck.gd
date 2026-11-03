extends PanelContainer

## Explicit, unmonitored microphone setup. Only completed scalar profiles save;
## Back, focus loss and Use Remo discard partial takes and release the device.

signal completed(profile: Dictionary, capture: Node)
signal cancelled
signal remo_requested

const Calibration = preload("res://games/sailor_man/voice/voice_calibration.gd")
const Capture = preload("res://games/sailor_man/voice/mic_capture.gd")
const Source = preload("res://games/sailor_man/voice/mic_voice_source.gd")
const Ribbon = preload("res://games/sailor_man/ui/voice_ribbon.gd")
const TAKE_SECONDS := 3.0
const CALL_SECONDS := 6.0
const TITLES := ["Room", "Speak", "Low", "High", "Call", "Complete"]
const PROMPTS := [
	"Enable the microphone, then stay quiet for two seconds. Headphones can help.",
	"Say a short phrase at your normal speaking level. Stop whenever comfortable.",
	"Hold a comfortable, steady low ooo. There is no need to reach a particular note.",
	"Move from your low voice into a comfortable light eee. Or use the fallback range.",
	"Give a comfortable call, any way you like. This is not scored; the ribbon shows it.",
	"Save these scalar measurements, or leave without changing your earlier profile.",
]

var profile_path := Calibration.SAVE_PATH
var seat_tag := ""
var selected_profile_name := ""
var _model := Calibration.new()
var _source := Source.new()
var _capture: Node
var _frames: Array[Dictionary] = []
var _recording := false
var _finishing := false
var _elapsed := 0.0
var _no_audio := 0.0
var _received := 0
var _noise_floor := 0.004
var _closing := false
var _budget := Source.live_analysis_budget()
var _profiles: Dictionary = {}
var _load_error := ""
var _margins: MarginContainer
var _scroll: ScrollContainer
var _title: Label
var _back: Button
var _step: Label
var _prompt: Label
var _status: Label
var _device: OptionButton
var _names: OptionButton
var _name: LineEdit
var _use_saved: Button
var _enable: Button
var _record: Button
var _skip: Button
var _save: Button
var _ribbon: Ribbon
var _unit := 0.0


func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("15242b")
	add_theme_stylebox_override("panel", background)
	_margins = MarginContainer.new()
	add_child(_margins)
	var column := VBoxContainer.new()
	_margins.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _label(header, "SoundcheckTitle", "Soundcheck")
	if not seat_tag.is_empty():
		_title.text += " - " + seat_tag
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back = _button(header, "BackSoundcheck", "Back", _cancel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_step = _label(body, "CalibrationStep", "")
	_prompt = _label(body, "CalibrationPrompt", "")
	_status = _label(body, "CalibrationStatus", "Microphone off. Remo needs no microphone.")
	_status.accessibility_live = 1
	_label(body, "ProfileTitle", "Saved voice profile")
	_names = OptionButton.new()
	_names.name = "VoiceProfiles"
	_names.accessibility_name = "Saved voice profile"
	_names.accessibility_description = "Choose scalar measurements, without enabling the microphone."
	_names.fit_to_longest_item = false
	_names.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(_names)
	_use_saved = _button(body, "UseSavedProfile", "Use saved profile", _select_saved)
	_label(body, "DeviceTitle", "Input device (off until Enable microphone)")
	_device = OptionButton.new()
	_device.name = "CalibrationDevice"
	_device.accessibility_name = "Microphone input device"
	_device.accessibility_description = "The microphone stays off until Enable microphone."
	_device.fit_to_longest_item = false
	_device.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(_device)
	for device: String in AudioServer.get_input_device_list():
		_device.add_item(device)
		if device == AudioServer.input_device:
			_device.select(_device.item_count - 1)
	_label(body, "NameTitle", "Save as (replaces this named calibration)")
	_name = LineEdit.new()
	_name.name = "ProfileName"
	_name.accessibility_name = "Calibration profile name"
	_name.accessibility_description = "Only Save replaces the calibration with this name."
	_name.text = seat_tag if not seat_tag.is_empty() else "P1"
	_name.max_length = 40
	_name.text_changed.connect(func(_text: String) -> void: _update())
	body.add_child(_name)
	_label(body, "CalibrationPrivacy",
		"Use a comfortable voice and stop if it feels uncomfortable. No audio or tracks "
		+ "are saved or monitored. Profiles keep only range/level measurements and device. "
		+ "This is input setup, not cultural validation.")
	_ribbon = Ribbon.new()
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_ribbon)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	_enable = _button(actions, "EnableCalibrationMic", "Enable microphone", _enable_microphone)
	_record = _button(actions, "RecordCalibration", "Record", _toggle_take)
	_skip = _button(actions, "SkipHighVoice", "Skip high", _skip_high)
	_skip.tooltip_text = "Use the unmeasured fallback range; no high voice is required."
	_save = _button(actions, "SaveVoiceProfile", "Save and use mic", _save_profile)
	_button(actions, "CalibrationRemo", "Use Remo", _use_remo)
	var loaded := Calibration.load_profiles(profile_path)
	_profiles = loaded["profiles"]
	_load_error = str(loaded["error"])
	var selected := selected_profile_name if not seat_tag.is_empty() \
		else str(loaded["selected"])
	var selected_index := -1
	for name: String in _profiles:
		_names.add_item(name)
		if name == selected:
			selected_index = _names.item_count - 1
	_names.item_selected.connect(_on_profile_selected)
	if selected_index >= 0:
		_names.select(selected_index)
		_on_profile_selected(selected_index)
	elif not seat_tag.is_empty():
		_names.select(-1)
		_names.text = "Choose a saved profile"
	elif _names.item_count > 0:
		_on_profile_selected(_names.selected)
	if not _load_error.is_empty():
		_status.text = _load_error + " Remo is still available."
	get_viewport().size_changed.connect(_fit)
	_scroll.resized.connect(_fit)
	_scroll.get_v_scroll_bar().changed.connect(_reveal_call_ribbon)
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.connect("changed", _on_setting_changed)
	_update()
	_update.call_deferred()
	_fit.call_deferred()
	_focus_back.call_deferred()


func _focus_back() -> void:
	if not _closing and is_visible_in_tree():
		_back.grab_focus()


func _enable_microphone() -> void:
	if _device.item_count == 0:
		_status.text = "No input device is available. Use Remo, or retry after connecting a device."
		return
	_begin_capture(Capture.new())


func _on_profile_selected(index: int) -> void:
	var name := _names.get_item_text(index)
	_name.text = name
	for device_index in _device.item_count:
		if _device.get_item_text(device_index) == str(_profiles[name]["device"]):
			_device.select(device_index)
	_update()


func _begin_capture(capture: Node) -> void:
	_stop_capture()
	var device := _device.get_item_text(_device.selected)
	_model.reset(device)
	_frames.clear()
	_capture = capture
	_capture.connect("calibrated", _on_room)
	_capture.connect("capture_failed", _on_failure)
	# Live audio must not exit the tree when this transient overlay closes.
	get_parent().add_child(_capture)
	_status.text = "Measuring the room. Stay quiet for two seconds."
	_capture.call("start", device)
	_update()


func _on_room(noise_floor: float) -> void:
	var error := _model.accept_room(noise_floor)
	if not error.is_empty():
		_on_failure(error)
		return
	_noise_floor = noise_floor
	_status.text = "Room measured. Record a short phrase at your normal speaking level."
	_update()


func _toggle_take() -> void:
	if _recording:
		_request_finish()
		return
	if _capture == null or not bool(_capture.call("is_ready")):
		_status.text = "Enable the microphone and complete the room measurement first."
		return
	if _model.step in [Calibration.Step.ROOM, Calibration.Step.COMPLETE]:
		return
	_capture.call("discard")
	_source.begin(AudioServer.get_mix_rate(), Calibration.analysis_profile(), _noise_floor)
	_frames.clear()
	_elapsed = 0.0
	_no_audio = 0.0
	_received = 0
	_recording = true
	_finishing = false
	_status.text = "Recording %s. Stop whenever comfortable." % TITLES[_model.step]
	_update()
	_reveal_call_ribbon()


func _reveal_call_ribbon() -> void:
	if _recording and _model.step == Calibration.Step.CALL:
		_scroll.ensure_control_visible.call_deferred(_ribbon)


func _process(delta: float) -> void:
	if _capture == null or not bool(_capture.call("is_ready")):
		return
	var pcm: PackedVector2Array = _capture.call("poll")
	if not _recording:
		return
	if not _finishing:
		_elapsed += delta
		_no_audio = _no_audio + delta if pcm.is_empty() else 0.0
		if _no_audio >= Capture.NO_INPUT_TIMEOUT:
			_on_failure("No microphone audio arrived. Check permission/device, or use Remo.")
			return
		var remaining := maxi(roundi(_take_seconds() * AudioServer.get_mix_rate()) - _received, 0)
		pcm = pcm.slice(0, remaining)
		_received += pcm.size()
	else:
		pcm = PackedVector2Array()
	_frames.append_array(_source.push_frames(pcm, _budget))
	_show_track()
	if _elapsed >= _take_seconds():
		_finishing = true
	if _finishing:
		_drain_finish()


func _request_finish() -> void:
	if not _finishing:
		var pcm: PackedVector2Array = _capture.call("poll")
		var remaining := maxi(roundi(_take_seconds() * AudioServer.get_mix_rate()) - _received, 0)
		pcm = pcm.slice(0, remaining)
		_received += pcm.size()
		_source.push_frames(pcm, 0)
		_finishing = true
	_drain_finish()


func _drain_finish() -> void:
	if _source.has_pending_analysis():
		_status.text = "Finishing the captured take. No further audio enters it."
		_update()
		return
	_frames.append_array(_source.finish())
	_recording = false
	_finishing = false
	if _frames.is_empty():
		_on_failure("No usable microphone audio arrived. Check permission/device, or use Remo.")
		return
	_show_track()
	var error := _model.accept_take(_frames)
	if not error.is_empty():
		_status.text = error + " The earlier saved profile is unchanged."
		_scroll.ensure_control_visible.call_deferred(_status)
	elif _model.step == Calibration.Step.COMPLETE:
		var profile := _model.result()
		_status.text = "Measurements complete. " + _load_error if not _load_error.is_empty() \
			else "Ready to save. %s" % (
				"Falsetto band measured from a register break." if profile["falsetto_calibrated"]
				else "No falsetto break measured; the softer fallback remains active.")
	else:
		_status.text = "Measurement accepted. " + PROMPTS[_model.step]
		_scroll.scroll_vertical = 0
	_update()


func _show_track() -> void:
	var profile := _model.preview_profile()
	var offset := 1200.0 * log(160.0 / float(profile["chest_hz"])) / log(2.0)
	var display: Array[Dictionary] = []
	for frame: Dictionary in _frames:
		var point := frame.duplicate()
		point["cents"] = float(frame["cents"]) + offset
		display.append(point)
	_ribbon.set_profile(profile)
	_ribbon.show_tracks(display, [], {}, _take_seconds())


func _take_seconds() -> float:
	return CALL_SECONDS if _model.step == Calibration.Step.CALL else TAKE_SECONDS


func _skip_high() -> void:
	if _recording:
		return
	var error := _model.skip_high()
	_status.text = error if not error.is_empty() else "Fallback selected. " + PROMPTS[_model.step]
	_update()


func _save_profile() -> void:
	var profile := _model.result()
	if profile.is_empty():
		_status.text = "Complete Soundcheck before saving a profile."
		_scroll.ensure_control_visible.call_deferred(_status)
		return
	var error := Calibration.save_profile(_name.text.strip_edges(), profile, profile_path)
	if not error.is_empty():
		_status.text = error
		_scroll.ensure_control_visible.call_deferred(_status)
		return
	var capture := _capture
	if capture != null:
		capture.disconnect("calibrated", _on_room)
		capture.disconnect("capture_failed", _on_failure)
	_capture = null
	_closing = true
	completed.emit(profile, capture)


func _select_saved() -> void:
	if _names.item_count == 0 or _names.selected < 0 or _capture != null:
		return
	var name := _names.get_item_text(_names.selected)
	var error := Calibration.select_profile(name, profile_path)
	if not error.is_empty():
		_status.text = error
		_scroll.ensure_control_visible.call_deferred(_status)
		return
	var loaded := Calibration.load_profiles(profile_path)
	if not str(loaded["error"]).is_empty():
		_status.text = str(loaded["error"])
		_scroll.ensure_control_visible.call_deferred(_status)
		return
	_closing = true
	completed.emit(loaded["profiles"][name].duplicate(), null)


func _on_failure(reason: String) -> void:
	_stop_capture()
	_model.reset(_device.get_item_text(_device.selected)
		if _device.item_count > 0 else "Default")
	_status.text = reason + " No partial profile was saved. Remo is available."
	_scroll.ensure_control_visible.call_deferred(_status)
	push_warning("Sailor Man Soundcheck: %s" % reason)
	_update()


func _stop_capture() -> void:
	_source.cancel()
	_recording = false
	_finishing = false
	if is_instance_valid(_capture):
		_capture.disconnect("calibrated", _on_room)
		_capture.disconnect("capture_failed", _on_failure)
		_capture.call("stop")
		_capture.queue_free()
	_capture = null
	_frames.clear()


func _cancel() -> void:
	if _closing:
		return
	_closing = true
	_stop_capture()
	cancelled.emit()


func _use_remo() -> void:
	if _closing:
		return
	_closing = true
	_stop_capture()
	remo_requested.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_cancel()


func _update() -> void:
	if not is_node_ready():
		return
	_step.text = "Room > Speak > Low > High > Call | %s" % TITLES[_model.step]
	_prompt.text = PROMPTS[_model.step]
	_enable.visible = _model.step == Calibration.Step.ROOM
	_enable.disabled = _capture != null or _device.item_count == 0
	_record.visible = _model.step in [
		Calibration.Step.SPEAK, Calibration.Step.LOW, Calibration.Step.HIGH, Calibration.Step.CALL,
	]
	_record.text = "Finishing..." if _finishing else (
		"Stop take" if _recording else "Record " + TITLES[_model.step])
	_record.disabled = _capture == null or _finishing
	_skip.visible = _model.step == Calibration.Step.HIGH
	_skip.disabled = _recording
	_save.visible = _model.step == Calibration.Step.COMPLETE
	_save.disabled = _name.text.strip_edges().is_empty()
	_device.disabled = _capture != null
	_names.disabled = _capture != null or _names.item_count == 0
	_use_saved.disabled = _capture != null or _names.selected < 0


func _fit() -> void:
	var settings := get_node_or_null("/root/Settings")
	var preference := float(settings.call("get_value", "ui/scale", 1.0)) \
		if settings != null else 1.0
	var transform := get_window().get_final_transform() * get_global_transform_with_canvas()
	var unit := preference / maxf(transform.get_scale().x, 0.001)
	_ribbon.custom_minimum_size.y = minf(180.0 * unit,
		maxf(80.0 * unit, _scroll.size.y - 16.0 * unit))
	if is_equal_approx(unit, _unit):
		return
	_unit = unit
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control is Label or control is BaseButton or control is LineEdit:
			control.add_theme_font_size_override("font_size", roundi(17.0 * unit))
		if control is BaseButton or control is LineEdit:
			control.custom_minimum_size.y = 44.0 * unit
		if control is BoxContainer:
			control.add_theme_constant_override("separation", roundi(8.0 * unit))
		if control is HFlowContainer:
			control.add_theme_constant_override("h_separation", roundi(8.0 * unit))
			control.add_theme_constant_override("v_separation", roundi(8.0 * unit))
	_title.add_theme_font_size_override("font_size", roundi(22.0 * unit))
	_ribbon.fit(unit)
	Responsive.set_margins(_margins, roundi(8 * unit), roundi(8 * unit),
		roundi(8 * unit), roundi(8 * unit))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "ui/scale":
		_fit()


func _label(parent: Node, name: String, text: String) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _exit_tree() -> void:
	_stop_capture()
