extends SceneTree

## The same relative contour must score alike in low and high vocal registers.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const Fixture = preload("res://games/sailor_man/tests/voice_track_fixture.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var low := Frame.profile(90.0, true)
	low["carry_level"] = 0.03
	var high := Frame.profile(300.0, true)
	high["carry_level"] = 0.12
	var contour := Fixture.shaped()
	for level in [1.0, 0.3]:
		for quiet in [false, true]:
			var a := Scorer.score(_sung(contour, low, level), low, [], quiet)
			var b := Scorer.score(_sung(contour, high, level), high, [], quiet)
			for mark: String in a["marks"]:
				_expect(
					absf(float(a["marks"][mark]) - float(b["marks"][mark])) <= 0.02,
					"%s must be independent of chest frequency and microphone gain." % mark
				)
			_expect(
				absf(float(a["total"]) - float(b["total"])) <= 0.02,
				"Low and high voices must score within two percent."
			)
	if _failures.is_empty():
		print("Voice normalisation tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _sung(
	contour: Array[Dictionary], profile: Dictionary, level: float
) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for frame in contour:
		var frequency := (
			float(profile["chest_hz"]) * pow(2.0, float(frame["cents"]) / 1200.0)
		)
		frames.append(Frame.from_frequency(
			float(frame["t"]), frequency,
			float(profile["carry_level"]) * float(frame["level"]) * level,
			profile, bool(frame["voiced"])
		))
	return frames


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
