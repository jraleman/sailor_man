extends RefCounted

## Unscored human measurements and named scalar profiles, never recordings.
## Takes use the normal microphone pipeline with carry_level = 1 for raw RMS.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Detector = preload("res://games/sailor_man/voice/pitch_detector.gd")
const SAVE_PATH := "user://sailor_man_voice.cfg"
const FORMAT := 1
const MIN_VOICED_SECONDS := 0.6
const MAX_LOW_SPREAD := 250.0
const BREAK_CENTS := 500.0
const BREAK_SECONDS := 0.09
const BAND_PADDING := 100.0
const MIN_BAND_SECONDS := 0.3
const PROFILE_KEYS := [
	"chest_hz", "falsetto_low", "falsetto_high", "falsetto_calibrated",
	"carry_level", "noise_floor", "speak_level", "device",
]

enum Step { ROOM, SPEAK, LOW, HIGH, CALL, COMPLETE }

var step := Step.ROOM
var _profile: Dictionary = {}


func _init(device := "Default") -> void:
	reset(device)


## A cancelled or retried wizard cannot inherit another person's partial range.
func reset(device: String) -> void:
	step = Step.ROOM
	_profile = Frame.profile()
	_profile.merge({"device": device, "noise_floor": 0.004, "speak_level": 0.0})


## A fixed reference preserves absolute frequency and RMS throughout calibration.
static func analysis_profile() -> Dictionary:
	var result := Frame.profile()
	result["carry_level"] = 1.0
	return result


## Only the explicit capture's completed room check may advance this step.
func accept_room(noise_floor: float) -> String:
	if step != Step.ROOM or not is_finite(noise_floor) or noise_floor <= 0.0 \
			or noise_floor > 0.05:
		return "A working microphone and a valid room measurement are required."
	_profile["noise_floor"] = noise_floor
	step = Step.SPEAK
	return ""


## Invalid takes stay on their step; no partial profile is published or saved.
func accept_take(frames: Array[Dictionary]) -> String:
	if step in [Step.ROOM, Step.COMPLETE]:
		return "This Soundcheck step does not accept a voice take."
	var error := Frame.track_error(frames)
	if not error.is_empty():
		return error
	var levels := PackedFloat64Array()
	var cents := PackedFloat64Array()
	for frame: Dictionary in frames:
		if float(frame["level"]) > 1.0:
			return "Calibration takes must contain raw RMS levels between zero and one."
		if bool(frame["voiced"]) and float(frame["level"]) > float(_profile["noise_floor"]):
			levels.append(float(frame["level"]))
			cents.append(float(frame["cents"]))
	if float(cents.size()) / Frame.RATE_HZ < MIN_VOICED_SECONDS:
		return "Not enough clear voice was heard. Check the device or try a comfortable take."
	match step:
		Step.SPEAK:
			_profile["speak_level"] = _percentile(levels, 0.5)
			step = Step.LOW
		Step.LOW:
			if _percentile(cents, 0.9) - _percentile(cents, 0.1) > MAX_LOW_SPREAD:
				return "The low reference moved too much. Hold a comfortable, steady ooo."
			var chest_hz := Frame.DEFAULT_CHEST_HZ * pow(
				2.0, _percentile(cents, 0.5) / 1200.0)
			if not is_finite(chest_hz) or chest_hz < Detector.MIN_FREQUENCY \
					or chest_hz > Detector.MAX_FREQUENCY:
				return "The low reference is outside the microphone's supported range."
			_profile["chest_hz"] = chest_hz
			step = Step.HIGH
		Step.HIGH:
			_measure_high(frames)
			step = Step.CALL
		Step.CALL:
			_profile["carry_level"] = _percentile(levels, 0.5)
			error = profile_error(_profile)
			if not error.is_empty():
				return error
			step = Step.COMPLETE
	return ""


## A comfortable fallback is explicit, never mislabeled as measured falsetto.
func skip_high() -> String:
	if step != Step.HIGH:
		return "Only the high-voice step has a fallback."
	step = Step.CALL
	return ""


## Only a complete, validated calibration can leave the wizard.
func result() -> Dictionary:
	return _profile.duplicate() if step == Step.COMPLETE else {}


## A view-only range lacks the required scalar measurements for saving or play.
func preview_profile() -> Dictionary:
	var preview := Frame.profile(float(_profile["chest_hz"]),
		bool(_profile["falsetto_calibrated"]))
	preview["falsetto_low"] = _profile["falsetto_low"]
	preview["falsetto_high"] = _profile["falsetto_high"]
	preview["carry_level"] = 1.0
	return preview


func _measure_high(frames: Array[Dictionary]) -> void:
	var offset := 1200.0 * log(Frame.DEFAULT_CHEST_HZ / float(_profile["chest_hz"])) / log(2.0)
	var upper := PackedFloat64Array()
	var found_break := false
	for index in frames.size():
		if not bool(frames[index]["voiced"]):
			continue
		var cents := float(frames[index]["cents"]) + offset
		if cents < BREAK_CENTS:
			continue
		upper.append(cents)
		for earlier in range(maxi(0, index - roundi(BREAK_SECONDS * Frame.RATE_HZ)), index):
			if not bool(frames[earlier]["voiced"]):
				continue
			if absf(float(frames[index]["cents"]) - float(frames[earlier]["cents"])) \
					>= BREAK_CENTS:
				found_break = true
	if found_break and float(upper.size()) / Frame.RATE_HZ >= MIN_BAND_SECONDS:
		_profile["falsetto_low"] = maxf(1.0, _percentile(upper, 0.1) - BAND_PADDING)
		_profile["falsetto_high"] = _percentile(upper, 0.9) + BAND_PADDING
		_profile["falsetto_calibrated"] = true


## Quiet Mode uses measured speaking level without changing pitch or mark weights.
static func scoring_profile(profile: Dictionary, quiet: bool) -> Dictionary:
	var result := profile.duplicate()
	if quiet:
		result["carry_level"] = profile["speak_level"]
	return result


## Reject damaged or foreign data before it can affect the detector or overwrite a file.
static func profile_error(profile: Dictionary) -> String:
	var error := Frame.profile_error(profile)
	if not error.is_empty():
		return error
	if float(profile["chest_hz"]) < Detector.MIN_FREQUENCY \
			or float(profile["chest_hz"]) > Detector.MAX_FREQUENCY:
		return "The chest reference must be inside the microphone's 70-1100 Hz range."
	var max_cents := 1200.0 * log(Detector.MAX_FREQUENCY / Detector.MIN_FREQUENCY) \
		/ log(2.0) + BAND_PADDING
	if float(profile["falsetto_high"]) > max_cents:
		return "The stored high band is outside the microphone's supported range."
	for key in profile:
		if key not in PROFILE_KEYS:
			return "Unsupported calibration field: %s." % key
	for key in ["noise_floor", "speak_level", "carry_level"]:
		var value: Variant = profile.get(key)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) \
				or float(value) <= 0.0 or float(value) > 1.0:
			return "Calibration needs a positive, finite %s no greater than one." % key
	if float(profile["noise_floor"]) > 0.05:
		return "The stored room measurement is outside the capture's supported range."
	if float(profile["noise_floor"]) >= minf(
		float(profile["speak_level"]), float(profile["carry_level"])
	):
		return "The room measurement must be below the measured voice levels."
	if typeof(profile.get("device")) != TYPE_STRING or str(profile["device"]).is_empty():
		return "Calibration needs its input device."
	return ""


## Missing files are first-run state; damaged/newer files are explicit failures.
static func load_profiles(path := SAVE_PATH) -> Dictionary:
	var config := ConfigFile.new()
	var error := _read(config, path)
	if not error.is_empty():
		push_warning("Sailor Man profiles: %s" % error)
		return {"profiles": {}, "selected": "", "error": error}
	return {
		"profiles": (config.get_value("voice", "profiles", {}) as Dictionary).duplicate(true),
		"selected": str(config.get_value("voice", "selected", "")), "error": "",
	}


## Merge named profiles, retaining the previous file and selection on any failure.
static func save_profile(name: String, profile: Dictionary, path := SAVE_PATH) -> String:
	var error := _name_error(name)
	if error.is_empty():
		error = profile_error(profile)
	var config := ConfigFile.new()
	if error.is_empty():
		error = _read(config, path)
	if not error.is_empty():
		push_warning("Sailor Man profiles: %s" % error)
		return error
	var profiles: Dictionary = config.get_value("voice", "profiles", {})
	profiles[name] = profile.duplicate()
	config.set_value("voice", "format", FORMAT)
	config.set_value("voice", "profiles", profiles)
	config.set_value("voice", "selected", name)
	var temporary := path + ".tmp"
	var code := config.save(temporary)
	if code == OK:
		code = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if code != OK:
		error = "Could not save the voice profile (%s). The earlier profile is unchanged." \
			% error_string(code)
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		push_warning("Sailor Man profiles: %s" % error)
	return error


## Selecting a saved profile is a preference, not permission to open its device.
static func select_profile(name: String, path := SAVE_PATH) -> String:
	var loaded := load_profiles(path)
	if not str(loaded["error"]).is_empty():
		return str(loaded["error"])
	var profiles: Dictionary = loaded["profiles"]
	if not profiles.has(name):
		return "That voice profile is no longer available."
	if str(loaded["selected"]) == name:
		return ""
	return save_profile(name, profiles[name], path)


static func _read(config: ConfigFile, path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var code := config.load(path)
	if code != OK:
		return "Could not read voice profiles (%s). The file was not changed." % error_string(code)
	if typeof(config.get_value("voice", "format", 0)) != TYPE_INT \
			or int(config.get_value("voice", "format", 0)) != FORMAT:
		return "Unsupported voice-profile format. The file was not changed."
	var profiles: Variant = config.get_value("voice", "profiles", [])
	var selected: Variant = config.get_value("voice", "selected", 0)
	if not profiles is Dictionary or typeof(selected) != TYPE_STRING \
			or (not str(selected).is_empty() and not profiles.has(selected)):
		return "The voice-profile list or selection is damaged."
	for name: Variant in profiles:
		if typeof(name) != TYPE_STRING or not _name_error(str(name)).is_empty() \
				or not profiles[name] is Dictionary:
			return "The voice-profile list contains an invalid entry."
		var error := profile_error(profiles[name])
		if not error.is_empty():
			return error
	return ""


static func _name_error(name: String) -> String:
	if name.strip_edges().is_empty() or name.length() > 40:
		return "Use a profile name between 1 and 40 characters."
	for index in name.length():
		if name.unicode_at(index) < 32:
			return "Profile names cannot contain control characters."
	return ""


static func _percentile(values: PackedFloat64Array, fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var at := fraction * float(sorted.size() - 1)
	return lerpf(sorted[floori(at)], sorted[ceili(at)], at - floorf(at))
