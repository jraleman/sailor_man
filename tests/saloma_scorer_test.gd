extends SceneTree

## The scorer's rules are tested without a microphone, autoload instances or art.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const Fixture = preload("res://games/sailor_man/tests/voice_track_fixture.gd")

var _failures := PackedStringArray()
var _profile := Frame.profile(160.0, true)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_silence_and_breath()
	_test_breaks()
	_test_octaves_and_soft_rule()
	_test_range()
	_test_finish()
	_test_echo()
	_test_power_and_call_weights()
	_test_invalid_input()
	if _failures.is_empty():
		print("Saloma scorer tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_silence_and_breath() -> void:
	var silent := Fixture.new()
	silent.gap(6.0)
	var result := Scorer.score(silent.frames, _profile)
	_expect(float(result["total"]) == 0.0, "Silence must score zero.")
	_expect(not bool(result["power_gated"]), "Silence is not a quiet performance.")
	var blip := Fixture.new()
	blip.hold(0.03)
	blip.gap(0.2)
	_expect(_mark(blip.frames, "aliento") == 0.0, "A 30 ms blip is not a breath.")
	var held := Fixture.new()
	held.hold(5.5)
	_expect(_mark(held.frames, "aliento") == 1.0, "Breath saturates at five seconds.")
	var bridged := Fixture.new()
	bridged.hold(2.5)
	bridged.gap(0.06)
	bridged.hold(2.5)
	_expect(_mark(bridged.frames, "aliento") == 1.0, "A 60 ms gap must bridge.")
	var separated := Fixture.new()
	separated.hold(2.5)
	separated.gap(0.07)
	separated.hold(1.0)
	_expect(
		is_equal_approx(_mark(separated.frames, "aliento"), 0.5),
		"A 70 ms gap must split the breath."
	)
	var evidence: Dictionary = Scorer.score(separated.frames, _profile)["evidence"]
	_expect(
		is_equal_approx(float(evidence["longest_breath"]["seconds"]), 2.5),
		"Results must retain the actual longest-breath span."
	)


func _test_breaks() -> void:
	var shaped := Fixture.shaped()
	var result := Scorer.score(shaped, _profile)
	var breaks: Array = result["evidence"]["breaks"]
	_expect(breaks.size() == 3, "Three deliberate jumps must yield three pieces of evidence.")
	_expect(_mark(shaped, "quiebre") > 0.95, "Clean jumps should earn nearly full Quiebre.")
	var glide := Fixture.new()
	glide.hold(0.3)
	glide.glide(1.0, 0.0, 1000.0)
	glide.hold(0.3, 1000.0)
	_expect(_mark(glide.frames, "quiebre") == 0.0, "A slow glide is not a break.")
	var wobbly := Fixture.new()
	wobbly.hold(0.4)
	wobbly.glide(0.04, 0.0, 1000.0)
	wobbly.wobble(0.5, 1000.0, 170.0)
	var clean := Fixture.new()
	clean.hold(0.4)
	clean.glide(0.04, 0.0, 1000.0)
	clean.hold(0.5, 1000.0)
	_expect(
		_mark(wobbly.frames, "quiebre") < _mark(clean.frames, "quiebre"),
		"A wobbly landing must lose cleanness."
	)
	var gap := Fixture.new()
	gap.hold(0.4)
	gap.gap(0.14)
	gap.hold(0.4, 1000.0)
	_expect(_mark(gap.frames, "quiebre") == 0.0, "Separate phrases cannot form a jump.")


func _test_octaves_and_soft_rule() -> void:
	for length in [0.01, 0.02]:
		var glitch := Fixture.new()
		glitch.hold(0.4)
		glitch.hold(length, 1200.0)
		glitch.hold(0.4)
		var original: Array[Dictionary] = glitch.frames.duplicate(true)
		_expect(_mark(glitch.frames, "quiebre") == 0.0, "Short octave errors are not breaks.")
		_expect(glitch.frames == original, "Scoring must never rewrite the source recording.")
	var real := Fixture.new()
	real.hold(0.4)
	real.hold(0.3, 1200.0)
	real.hold(0.4)
	_expect(_mark(real.frames, "quiebre") > 0.6, "A sustained octave jump must survive.")
	var soft := Fixture.new()
	soft.hold(0.4)
	soft.hold(0.4, 420.0)
	var fallback := Frame.profile()
	var result := Scorer.score(soft.frames, fallback)
	_expect(
		is_equal_approx(float(result["marks"]["quiebre"]), 0.8 / 3.0),
		"An unmeasured falsetto band uses the 400-cent rule at 0.8 cleanness."
	)
	_expect(_mark(soft.frames, "quiebre") == 0.0, "The measured rule still needs 500 cents.")


func _test_range() -> void:
	var wide := Fixture.new()
	wide.hold(0.5)
	wide.hold(0.5, 1300.0)
	_expect(_mark(wide.frames, "altura") == 1.0, "A full calibrated span earns full Altura.")
	var outlier := Fixture.new()
	outlier.hold(1.0)
	outlier.hold(0.01, 5000.0)
	outlier.hold(1.0)
	_expect(_mark(outlier.frames, "altura") == 0.0, "A pitch outlier must not buy range.")


func _test_finish() -> void:
	var falling := Fixture.new()
	falling.hold(1.0, 600.0)
	falling.glide(0.4, 600.0, 0.0)
	falling.cut_off()
	var crisp := Fixture.new()
	crisp.hold(1.0)
	crisp.cut_off()
	var fading := Fixture.new()
	fading.hold(1.0)
	fading.fade(0.6)
	var unfinished := Fixture.new()
	unfinished.hold(1.0)
	var late_break := Fixture.new()
	late_break.hold(1.0, 1000.0)
	late_break.hold(0.2)
	var drifting_break := Fixture.new()
	drifting_break.hold(1.0, 1000.0)
	drifting_break.hold(0.1, 100.0)
	drifting_break.glide(0.1, 100.0, 90.0)
	_expect(_mark(falling.frames, "remate") == 1.0, "A falling glide earns full Remate.")
	_expect(_mark(crisp.frames, "remate") == 1.0, "A crisp stop earns full Remate.")
	_expect(_mark(fading.frames, "remate") == 0.5, "A slow fade earns half Remate.")
	_expect(_mark(unfinished.frames, "remate") == 0.0, "A window cut is not a performed finish.")
	_expect(
		_mark(late_break.frames, "remate") == 0.0,
		"A register drop followed by an unfinished hold is not a falling glide."
	)
	_expect(
		_mark(drifting_break.frames, "remate") == 0.0,
		"An abrupt drop plus tiny downward drift is not a 300-cent glide."
	)


func _test_echo() -> void:
	var call := Fixture.shaped()
	var shifted: Array[Dictionary] = call.duplicate(true)
	for frame in shifted:
		frame["cents"] = float(frame["cents"]) + 350.0
	var exact := Scorer.score(call, _profile, call)
	var transposed := Scorer.score(shifted, _profile, call)
	var stretched := Scorer.score(Fixture.shaped(1.4), _profile, call)
	var unrelated := Fixture.new()
	unrelated.hold(5.0)
	var flat := Scorer.score(unrelated.frames, _profile, call)
	_expect(float(exact["marks"]["eco"]) > 0.99, "Matching contours must earn full Eco.")
	_expect(float(transposed["marks"]["eco"]) > 0.99, "Eco must ignore vocal register.")
	_expect(float(stretched["marks"]["eco"]) > 0.9, "Eco must tolerate a slower answer.")
	_expect(float(flat["marks"]["eco"]) < 0.6, "A flat answer must not echo a shaped call.")


func _test_power_and_call_weights() -> void:
	var normal := Fixture.new()
	normal.hold(5.0)
	normal.cut_off()
	var quiet: Array[Dictionary] = normal.frames.duplicate(true)
	var clipped: Array[Dictionary] = normal.frames.duplicate(true)
	for index in normal.frames.size():
		quiet[index]["level"] = float(quiet[index]["level"]) * 0.1
		clipped[index]["level"] = float(clipped[index]["level"]) * 10.0
	var base := Scorer.score(normal.frames, _profile)
	var gated := Scorer.score(quiet, _profile)
	var bypass := Scorer.score(quiet, _profile, [], true)
	var loud := Scorer.score(clipped, _profile)
	_expect(
		is_equal_approx(float(base["total"]), 0.4 / 0.85),
		"A call must rescale the four available marks, not lose points for missing Eco."
	)
	_expect(
		bool(gated["power_gated"])
		and is_equal_approx(float(gated["total"]), float(base["total"]) * 0.8),
		"Mostly below-carrying frames must lose exactly 20 percent."
	)
	_expect(
		not bool(bypass["power_gated"])
		and is_equal_approx(float(bypass["total"]), float(base["total"])),
		"Quiet Mode must completely bypass the power gate."
	)
	_expect(
		is_equal_approx(float(loud["total"]), float(base["total"])),
		"Extra amplitude must never earn extra marks."
	)
	_expect(
		float(Scorer.score(Fixture.shaped(), _profile)["total"]) > float(base["total"]) + 0.3,
		"A shaped synthetic performance must clearly outscore a flat yell."
	)


func _test_invalid_input() -> void:
	var malformed: Array[Dictionary] = [
		Frame.make(0.0, 0.0, true, 1.0), Frame.make(1.0, 0.0, true, 1.0),
	]
	var result := Scorer.score(malformed, _profile)
	_expect(
		not bool(result["valid"]) and not str(result["error"]).is_empty(),
		"A missing second of frames must be an explicit error, not free breath."
	)
	var profile := _profile.duplicate()
	profile["falsetto_high"] = 0.0
	_expect(
		not bool(Scorer.score([], profile)["valid"]),
		"An invalid calibration must not silently change the scoring range."
	)


func _mark(track: Array[Dictionary], key: String) -> float:
	var result := Scorer.score(track, _profile)
	return float(result["marks"][key])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
