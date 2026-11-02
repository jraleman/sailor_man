extends SceneTree

## Synthetic audio exercises the actual detector and streaming path, not a
## mocked pitch estimate. Hardware/permission checks remain manual.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Detector = preload("res://games/sailor_man/voice/pitch_detector.gd")
const Track = preload("res://games/sailor_man/voice/voice_track.gd")
const Source = preload("res://games/sailor_man/voice/mic_voice_source.gd")
const Capture = preload("res://games/sailor_man/voice/mic_capture.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_detector_range()
	_test_detector_silence()
	_test_buffer_boundaries()
	_test_track_octaves()
	_test_microphone_source()
	_test_dead_input()
	if _failures.is_empty():
		print("Voice pipeline tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_detector_range() -> void:
	for rate in [44100.0, 48000.0, 96000.0]:
		var detector := Detector.new(rate, 0.001)
		for frequency in [70.0, 90.0, 160.0, 220.0, 440.0, 700.0, 1100.0]:
			var samples := _tone(
				detector.window_size(), detector.work_sample_rate(), frequency
			)
			var analysis := detector.analyse_window(samples)
			var cents := (
				absf(1200.0 * log(float(analysis["frequency"]) / frequency) / log(2.0))
				if bool(analysis["voiced"]) else INF
			)
			_expect(
				cents < 15.0,
				"%.0f Hz at %.0f Hz input must be detected within 15 cents (got %.1f)."
				% [frequency, rate, cents]
			)


func _test_detector_silence() -> void:
	var detector := Detector.new()
	var silence := PackedFloat32Array()
	silence.resize(detector.window_size())
	_expect(
		not bool(detector.analyse_window(silence)["voiced"]),
		"Digital silence must not invent a pitch."
	)
	silence.fill(0.25)
	_expect(
		not bool(detector.analyse_window(silence)["voiced"]),
		"A DC offset must not invent a pitch."
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1907
	for index in silence.size():
		silence[index] = rng.randf_range(-0.2, 0.2)
	_expect(
		not bool(detector.analyse_window(silence)["voiced"]),
		"Uncorrelated room noise must not invent a confident pitch."
	)


func _test_buffer_boundaries() -> void:
	for rate in [44100.0, 48000.0]:
		var samples := _tone(int(rate * 0.4), rate, 220.0)
		var whole := Detector.new(rate).push_samples(samples)
		var streamed := Detector.new(rate)
		var split: Array[Dictionary] = []
		var cursor := 0
		var chunks := [13, 997, 4096]
		while cursor < samples.size():
			var end := mini(cursor + int(chunks[cursor % chunks.size()]), samples.size())
			split.append_array(streamed.push_samples(samples.slice(cursor, end)))
			cursor = end
		_expect(whole == split, "Irregular capture buffers must preserve every sample and hop.")


func _test_track_octaves() -> void:
	for glitch_length in [1, 2]:
		var frames := _tracked_jump(1200.0, glitch_length)
		var peak := 0.0
		for frame in frames:
			if bool(frame["voiced"]):
				peak = maxf(peak, absf(float(frame["cents"])))
		_expect(peak < 1.0, "One/two-frame octave errors must be removed before the live ribbon.")
	for jump in [700.0, 1200.0]:
		var frames := _tracked_jump(jump, 30)
		var peak := 0.0
		for frame in frames:
			peak = maxf(peak, float(frame["cents"]))
		_expect(absf(peak - jump) < 1.0, "Real register changes must bypass the median filter.")
		_expect(Frame.track_error(frames).is_empty(), "Normalized tracks must stay at 100 Hz.")


func _test_microphone_source() -> void:
	for rate in [44100.0, 48000.0]:
		var source := Source.new()
		var profile := Frame.profile(160.0, true)
		source.begin(rate, profile, 0.001)
		var started := Time.get_ticks_usec()
		var frames := source.push_samples(_tone(int(rate), rate, 160.0))
		var silence := PackedFloat32Array()
		silence.resize(int(rate * 0.2))
		frames.append_array(source.push_samples(silence))
		frames.append_array(source.finish())
		print("Microphone pipeline: 1.2 s of %.0f Hz PCM processed in %.1f ms." % [
			rate, float(Time.get_ticks_usec() - started) / 1000.0,
		])
		_expect(Frame.track_error(frames).is_empty(), "Microphone frames must use the shared clock.")
		var result := Scorer.score(frames, profile)
		_expect(
			bool(result["valid"]) and float(result["marks"]["aliento"]) > 0.15,
			"Real PCM must reach the scorer as a sustained breath."
		)
		var near_chest := 0
		for frame in frames:
			if bool(frame["voiced"]) and absf(float(frame["cents"])) < 15.0:
				near_chest += 1
		_expect(near_chest > 80, "A chest-centre tone must remain continuous cents, not MIDI notes.")
		source.begin(rate, profile, 0.001)
		var fresh := source.push_samples(silence)
		fresh.append_array(source.finish())
		for frame in fresh:
			_expect(not bool(frame["voiced"]), "A new window must not inherit the previous voice.")


func _test_dead_input() -> void:
	var silence := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	_expect(Capture.digital_silence(silence), "A dead input must be distinguishable from a quiet mic.")
	silence.append(Vector2(0.0000001, 0.0))
	_expect(not Capture.digital_silence(silence), "Quiet microphone self-noise is not digital silence.")
	var old_enabled: bool = ProjectSettings.get_setting("audio/driver/enable_input")
	var buses := AudioServer.bus_count
	var capture := Capture.new()
	get_root().add_child(capture)
	_expect(AudioServer.bus_count == buses, "Adding a capture node must not open the microphone.")
	ProjectSettings.set_setting("audio/driver/enable_input", false)
	capture.start()
	_expect(
		not capture.failure_reason().is_empty() and not capture.is_ready(),
		"Disabled input must surface a failure, not pretend to be calibrated."
	)
	capture.free()
	ProjectSettings.set_setting("audio/driver/enable_input", old_enabled)
	_expect(AudioServer.bus_count == buses, "A refused capture must not leak an audio bus.")


func _tracked_jump(cents: float, length: int) -> Array[Dictionary]:
	var track := Track.new()
	var profile := Frame.profile(160.0, true)
	track.configure(profile)
	var result: Array[Dictionary] = []
	for index in 80:
		var pitch := cents if index >= 20 and index < 20 + length else 0.0
		result.append_array(track.push({
			"t": float(index) / Frame.RATE_HZ,
			"frequency": 160.0 * pow(2.0, pitch / 1200.0),
			"voiced": true, "rms": 0.1, "confidence": 1.0,
		}))
	result.append_array(track.finish())
	return result


func _tone(count: int, rate: float, frequency: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(count)
	for index in count:
		var phase := TAU * frequency * float(index) / rate + 0.31
		result[index] = sin(phase) * 0.2 + sin(phase * 2.0) * 0.1 + sin(phase * 3.0) * 0.04
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
