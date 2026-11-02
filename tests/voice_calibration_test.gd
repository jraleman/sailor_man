extends SceneTree

## Synthetic raw-RMS tracks prove calibration and scalar persistence, not singers.

const Calibration = preload("res://games/sailor_man/voice/voice_calibration.gd")
const Fixture = preload("res://games/sailor_man/tests/voice_track_fixture.gd")
const VoiceRest = preload("res://games/sailor_man/voice/voice_rest.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var calibration := Calibration.new("Test mic")
	_expect(not calibration.accept_room(NAN).is_empty()
		and calibration.step == Calibration.Step.ROOM, "Invalid rooms must not advance.")
	_expect(calibration.accept_room(0.002).is_empty(), "A measured room must advance.")
	var bad := _hold(0.8, 0.0, 0.03)
	bad[1]["t"] = 0.8
	_expect(not calibration.accept_take(bad).is_empty() and calibration.result().is_empty(),
		"Malformed or partial measurements cannot publish a profile.")
	var over_range := _hold(0.8, 0.0, 0.03)
	over_range[0]["level"] = 1.5
	_expect(not calibration.accept_take(over_range).is_empty(),
		"Out-of-range RMS measurements must be rejected before advancing the wizard.")
	_expect(calibration.accept_take(_hold(0.8, 0.0, 0.03)).is_empty(),
		"Speaking level must be measured independently of carrying level.")
	var offset := 1200.0 * log(240.0 / 160.0) / log(2.0)
	_expect(calibration.accept_take(_hold(0.8, offset, 0.04)).is_empty(),
		"Low voice must preserve absolute frequency through the fixed reference.")
	var high := Fixture.new()
	high.hold(0.4, offset, 0.04)
	high.glide(0.04, offset, offset + 900.0, 0.04)
	high.hold(0.8, offset + 900.0, 0.04)
	_expect(calibration.accept_take(high.frames).is_empty(), "A high take must advance.")
	_expect(calibration.accept_take(_hold(1.0, offset, 0.09)).is_empty(),
		"The final call is an unscored carrying-level measurement.")
	var measured := calibration.result()
	_expect(is_equal_approx(float(measured["chest_hz"]), 240.0)
		and bool(measured["falsetto_calibrated"])
		and absf(float(measured["falsetto_low"]) - 800.0) < 1.0
		and absf(float(measured["falsetto_high"]) - 1000.0) < 1.0,
		"Only an observed register break may produce the measured high band.")
	_expect(is_equal_approx(float(measured["speak_level"]), 0.03)
		and is_equal_approx(float(measured["carry_level"]), 0.09)
		and is_equal_approx(float(Calibration.scoring_profile(measured, true)["carry_level"]), 0.03)
		and is_equal_approx(float(measured["carry_level"]), 0.09),
		"Quiet Mode must normalize to speech without mutating the normal profile.")
	_test_fallback()
	_test_profiles(measured)
	_test_rest_reminders()
	if _failures.is_empty():
		print("Voice calibration and profile tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_fallback() -> void:
	var calibration := Calibration.new("Test mic")
	calibration.accept_room(0.002)
	calibration.accept_take(_hold(0.8, 0.0, 0.03))
	var unstable := Fixture.new()
	unstable.glide(0.8, 0.0, 800.0, 0.03)
	_expect(not calibration.accept_take(unstable.frames).is_empty()
		and calibration.step == Calibration.Step.LOW,
		"An unstable low take must retry, not move the chest reference.")
	_expect(not calibration.accept_take(_hold(0.8, 1.0e100, 0.03)).is_empty()
		and calibration.step == Calibration.Step.LOW,
		"An impossible low reference cannot poison the remaining wizard steps.")
	calibration.accept_take(_hold(0.8, 0.0, 0.03))
	calibration.accept_take(_hold(0.8, 900.0, 0.03))
	calibration.accept_take(_hold(0.8, 0.0, 0.04))
	_expect(not bool(calibration.result()["falsetto_calibrated"])
		and float(calibration.result()["falsetto_low"]) == 700.0,
		"A high hold without an observed break must retain the softer fallback.")
	calibration.reset("Other mic")
	calibration.accept_room(0.002)
	calibration.accept_take(_hold(0.8, 0.0, 0.03))
	calibration.accept_take(_hold(0.8, 0.0, 0.03))
	_expect(calibration.skip_high().is_empty(), "High voice must have an explicit comfortable skip.")
	calibration.accept_take(_hold(0.8, 0.0, 0.04))
	_expect(not bool(calibration.result()["falsetto_calibrated"])
		and calibration.result()["device"] == "Other mic",
		"Reset/skip cannot inherit measured falsetto or another device.")


func _test_profiles(profile: Dictionary) -> void:
	var path := "user://sailor_calibration_test_%d.cfg" % OS.get_process_id()
	_expect(Calibration.load_profiles(path)["profiles"].is_empty(),
		"A missing calibration file is normal first-run state.")
	_expect(Calibration.save_profile("P1", profile, path).is_empty(), "The first profile must save.")
	var second := profile.duplicate()
	second["chest_hz"] = 123.456789012345
	_expect(Calibration.save_profile("Captain two", second, path).is_empty(),
		"A second profile must merge without deleting the first.")
	var loaded := Calibration.load_profiles(path)
	_expect(loaded["profiles"].size() == 2 and loaded["selected"] == "Captain two"
		and absf(float(loaded["profiles"]["Captain two"]["chest_hz"]) - 123.456789012345)
			< 0.00000000001,
		"Profiles and selection must round-trip without 32-bit range truncation.")
	_expect(Calibration.select_profile("P1", path).is_empty()
		and Calibration.load_profiles(path)["selected"] == "P1",
		"Selecting a profile must persist without opening hardware.")
	var before := FileAccess.get_file_as_bytes(path)
	var invalid := profile.duplicate()
	invalid["speak_level"] = INF
	_expect(not Calibration.save_profile("P1", invalid, path).is_empty()
		and FileAccess.get_file_as_bytes(path) == before,
		"Invalid calibration cannot overwrite an existing profile.")
	invalid = profile.duplicate()
	invalid["pcm"] = PackedByteArray([1, 2])
	_expect(not Calibration.save_profile("P1", invalid, path).is_empty(),
		"Only scalar calibration fields, never PCM or tracks, may persist.")
	invalid = profile.duplicate()
	invalid["chest_hz"] = 1.0e200
	_expect(not Calibration.save_profile("P1", invalid, path).is_empty(),
		"Stored chest references must remain in the detector's supported range.")
	invalid = profile.duplicate()
	invalid["falsetto_high"] = 1.0e200
	_expect(not Calibration.save_profile("P1", invalid, path).is_empty(),
		"Impossible high bands cannot become misleading ribbon guides.")
	var newer := ConfigFile.new()
	newer.load(path)
	newer.set_value("voice", "format", Calibration.FORMAT + 1)
	newer.save(path)
	before = FileAccess.get_file_as_bytes(path)
	_expect(not str(Calibration.load_profiles(path)["error"]).is_empty()
		and not Calibration.save_profile("P1", profile, path).is_empty()
		and FileAccess.get_file_as_bytes(path) == before,
		"A newer format must be refused without rewriting it as an empty save.")
	var damaged := ConfigFile.new()
	damaged.set_value("voice", "format", Calibration.FORMAT)
	damaged.save(path)
	before = FileAccess.get_file_as_bytes(path)
	_expect(not str(Calibration.load_profiles(path)["error"]).is_empty()
		and not Calibration.save_profile("P1", profile, path).is_empty()
		and FileAccess.get_file_as_bytes(path) == before,
		"Missing required fields must be explicit failures, not defaults or an empty overwrite.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_expect(not Calibration.save_profile(
		"P1", profile, "user://missing_calibration_directory/profile.cfg"
	).is_empty(), "Write failures must be explicit, not success-shaped profiles.")


func _hold(seconds: float, cents: float, level: float) -> Array[Dictionary]:
	var fixture := Fixture.new()
	fixture.hold(seconds, cents, level)
	return fixture.frames


func _test_rest_reminders() -> void:
	var rest := VoiceRest.new()
	for index in 5:
		rest.record_turn(float(index), true)
	rest.record_turn(5.0, false)
	_expect(not rest.is_due(5.0), "Five voiced turns and a silent take cannot trigger a reminder.")
	rest.record_turn(600.0, true)
	_expect(rest.is_due(600.0) and not rest.is_due(600.01),
		"Six sung turns must use a rolling ten-minute window, not a lifetime count.")
	rest.record_turn(601.0, true)
	_expect(rest.is_due(601.0), "A fresh voiced turn must replace an expired one.")
	rest.dismiss()
	_expect(not rest.is_due(601.0),
		"Dismissing rest acknowledges this group without forcing a break or another prompt.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
