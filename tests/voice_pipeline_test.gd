extends SceneTree

## Synthetic audio exercises the actual detector and streaming path, not a
## mocked pitch estimate. Hardware/permission checks remain manual.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Detector = preload("res://games/sailor_man/voice/pitch_detector.gd")
const Track = preload("res://games/sailor_man/voice/voice_track.gd")
const Source = preload("res://games/sailor_man/voice/mic_voice_source.gd")
const Capture = preload("res://games/sailor_man/voice/mic_capture.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const WavSource = preload("res://games/sailor_man/tools/wav_voice_source.gd")
const TakeAnalysis = preload("res://games/sailor_man/tools/analyse_takes.gd")

var _failures := PackedStringArray()
var _wav_files := PackedStringArray()
var _sample_wav := ""
var _wav_root := "user://sailor_wav_test_%d_%d" % [
	OS.get_process_id(), Time.get_ticks_usec(),
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_detector_range()
	_test_detector_silence()
	_test_buffer_boundaries()
	_test_track_octaves()
	_test_microphone_source()
	_test_dead_input()
	_test_wav_sources()
	_test_wav_failures()
	_test_wav_chunks()
	_test_take_analysis()
	_test_take_cli()
	for path in _wav_files:
		if FileAccess.file_exists(path):
			_expect(DirAccess.remove_absolute(path) == OK, "Remove the synthetic WAV fixture.")
	if DirAccess.dir_exists_absolute(_wav_root):
		_expect(DirAccess.remove_absolute(_wav_root) == OK, "Remove the empty WAV fixture folder.")
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


func _test_wav_sources() -> void:
	var error := DirAccess.make_dir_recursive_absolute(_wav_root)
	_expect(error == OK, "Create an isolated folder for synthetic WAV fixtures.")
	if error != OK:
		return
	var buses := AudioServer.bus_count
	var profile := Frame.profile()
	profile["carry_level"] = 0.5
	for rate in [44100, 48000, 96000]:
		for stereo in [false, true]:
			for width in [1, 2]:
				var samples := _tone(int(rate * 0.4), float(rate), 160.0)
				samples.resize(int(rate * 0.5))
				var fixture := _write_wav(
					"tone %d %s %d" % [rate, str(stereo), width], rate, stereo, width, samples
				)
				if fixture.is_empty():
					continue
				var path := str(fixture["path"])
				var before := FileAccess.get_file_as_bytes(path)
				var loaded := WavSource.read(path, profile, 0.001)
				_expect(bool(loaded["valid"]), "Load the synthetic WAV: %s." % path)
				if not bool(loaded["valid"]):
					continue
				if _sample_wav.is_empty():
					_sample_wav = path
				var direct := Source.new()
				direct.begin(float(rate), profile, 0.001)
				var expected := direct.push_frames(fixture["pcm"])
				expected.append_array(direct.finish())
				var actual: Array[Dictionary] = loaded["track"]
				var matching := actual.size() == expected.size()
				var cents_error := 0.0
				var level_error := 0.0
				for index in mini(actual.size(), expected.size()):
					matching = (
						matching and actual[index]["voiced"] == expected[index]["voiced"]
						and is_equal_approx(float(actual[index]["t"]), float(expected[index]["t"]))
					)
					cents_error = maxf(cents_error, absf(
						float(actual[index]["cents"]) - float(expected[index]["cents"])
					))
					level_error = maxf(level_error, absf(
						float(actual[index]["level"]) - float(expected[index]["level"])
					))
				_expect(
					matching and cents_error < 0.2 and level_error < 0.002,
					"WAV decoding must match captured PCM at %d Hz, stereo=%s, width=%d."
					% [rate, str(stereo), width]
				)
				_expect(
					int(loaded["sample_rate"]) == rate
					and int(loaded["channels"]) == (2 if stereo else 1)
					and is_equal_approx(float(loaded["duration_seconds"]), 0.5)
					and Frame.track_error(actual).is_empty()
					and FileAccess.get_file_as_bytes(path) == before,
					"Offline analysis must preserve rate, channels, silence and the input file."
				)
	_expect(AudioServer.bus_count == buses, "Recorded input must not create a capture bus.")


func _test_wav_failures() -> void:
	for path in [
		_wav_root.path_join("missing.wav"),
		_write_bytes("not_audio.wav", "not a WAV recording".to_ascii_buffer()),
	]:
		_expect(not bool(WavSource.read(path, Frame.profile())["valid"]), "Reject non-WAV input.")
	var truncated := "RIFF".to_ascii_buffer()
	truncated.resize(8)
	truncated.encode_u32(4, 200)
	truncated.append_array("WAVE".to_ascii_buffer())
	var path := _write_bytes("truncated.wav", truncated)
	_expect(
		not bool(WavSource.read(path, Frame.profile())["valid"]),
		"A truncated recording must not become a plausible score."
	)
	for rate in [8000, 44100]:
		var short := _write_wav(
			"unusable %d" % rate, rate, false, 2, _tone(40, float(rate), 160.0)
		)
		if not short.is_empty():
			_expect(
				not bool(WavSource.read(str(short["path"]), Frame.profile())["valid"]),
				"Unsupported rates and unanalyzable short WAVs must fail before scoring."
			)
	var silence := PackedFloat32Array()
	silence.resize(8820)
	var quiet := _write_wav("silence", 44100, false, 2, silence)
	if not quiet.is_empty():
		var loaded := WavSource.read(str(quiet["path"]), Frame.profile())
		_expect(bool(loaded["valid"]), "Recorded silence is not missing PCM.")
		if bool(loaded["valid"]):
			var score := Scorer.score(loaded["track"], Frame.profile())
			_expect(
				int(loaded["voiced_frames"]) == 0 and is_zero_approx(float(score["total"])),
				"An actual silent WAV must remain a valid zero-score take."
			)


func _test_take_analysis() -> void:
	if _sample_wav.is_empty():
		return
	for arguments in [
		[], ["--noise-floor=banana", _sample_wav], ["--sensitivity=0", _sample_wav],
		["--falsetto-low=1400", _sample_wav], ["--unknown=1", _sample_wav],
	]:
		_expect(
			not bool(TakeAnalysis.parse_arguments(PackedStringArray(arguments))["valid"]),
			"Malformed analysis arguments must fail instead of adopting silent defaults."
		)
	var options := TakeAnalysis.parse_arguments(PackedStringArray([
		"--quiet-mode", "--carry-level=0.5", "--noise-floor=0.001",
		"--reference=%s" % _sample_wav, _sample_wav,
	]))
	var report := TakeAnalysis.analyse(options)
	var take: Dictionary = report["takes"][0]
	_expect(
		bool(report["valid"]) and bool(take["score"]["answering"])
		and float(take["score"]["marks"]["eco"]) > 0.99
		and not bool(take["score"]["power_gated"])
		and not take.has("track") and not report.has("profile"),
		"Offline answers must earn Eco without putting full tracks/profiles in the report."
	)
	var normal := options.duplicate(true)
	normal["quiet_mode"] = false
	var gated := TakeAnalysis.analyse(normal)
	_expect(
		bool(gated["takes"][0]["score"]["power_gated"])
		and float(gated["takes"][0]["score"]["total"]) < float(take["score"]["total"]),
		"Offline Quiet Mode must bypass the same carrying-level gate as live scoring."
	)
	options["files"] = PackedStringArray([
		_sample_wav, _wav_root.path_join("missing_take.wav"),
	])
	report = TakeAnalysis.analyse(options)
	_expect(
		not bool(report["valid"]) and (report["takes"] as Array).size() == 2
		and bool(report["takes"][0]["valid"]) and not bool(report["takes"][1]["valid"]),
		"A missing take must be reported without hiding the successful take or overall failure."
	)
	options["reference"] = _wav_root.path_join("missing_reference.wav")
	report = TakeAnalysis.analyse(options)
	_expect(
		not bool(report["valid"]) and (report["takes"] as Array).is_empty()
		and str(report["error"]).contains("Reference"),
		"A missing reference must fail, never silently score answers as calls."
	)


func _test_wav_chunks() -> void:
	var fixture := _write_wav("chunk layout", 44100, true, 2, _tone(17640, 44100.0, 160.0))
	if fixture.is_empty():
		return
	var original := FileAccess.get_file_as_bytes(str(fixture["path"]))
	var oversized := original.duplicate()
	oversized.encode_u32(40, original.decode_u32(40) + 4)
	var partial := original.duplicate()
	partial.append_array(PackedByteArray([1, 0]))
	partial.encode_u32(4, partial.size() - 8)
	partial.encode_u32(40, original.decode_u32(40) + 1)
	var invalid_rate := original.duplicate()
	invalid_rate.encode_u32(24, 0)
	for bytes in [oversized, partial, invalid_rate]:
		var path := _write_bytes("damaged %d.wav" % _wav_files.size(), bytes)
		_expect(
			not bool(WavSource.read(path, Frame.profile())["valid"]),
			"Decoder recovery must not turn broken chunk sizes, frames or rates into valid takes."
		)
	var metadata := "JUNK".to_ascii_buffer()
	metadata.resize(8)
	metadata.encode_u32(4, 3)
	metadata.append_array(PackedByteArray([1, 2, 3, 0]))
	var tagged := original.slice(0, 12)
	tagged.append_array(metadata)
	tagged.append_array(original.slice(12))
	tagged.encode_u32(4, tagged.size() - 8)
	var path := _write_bytes("padded metadata.wav", tagged)
	var loaded := WavSource.read(path, Frame.profile())
	_expect(
		bool(loaded["valid"]) and is_equal_approx(float(loaded["duration_seconds"]), 0.4),
		"A valid odd-sized metadata chunk with RIFF padding must preserve the recording."
	)


func _test_take_cli() -> void:
	if _sample_wav.is_empty():
		return
	var base := PackedStringArray([
		"--headless", "--audio-driver", "Dummy", "--no-header",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://games/sailor_man/tools/analyse_takes.gd", "--", "--game=sailor_man",
	])
	var path := ProjectSettings.globalize_path(_sample_wav)
	for missing in [false, true]:
		var arguments := base.duplicate()
		arguments.append("--reference=%s" % path)
		arguments.append(path if not missing else path + ".missing")
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), arguments, output, true)
		var report: Dictionary = {}
		for chunk: String in output:
			for line: String in chunk.split("\n"):
				if line.begins_with("{"):
					var json := JSON.new()
					var error := json.parse(line)
					_expect(error == OK, "The analysis command must emit valid JSON.")
					if error == OK and json.data is Dictionary:
						report = json.data
		_expect(
			code == (2 if missing else 0) and not report.is_empty()
			and bool(report.get("valid", missing)) == (not missing),
			"The real analysis command must score spaced paths and return a failing exit for bad input."
		)
		var takes: Array = report.get("takes", [])
		_expect(takes.size() == 1, "The command must report the take, not just a success flag.")
		if takes.size() == 1 and not missing:
			_expect(
				bool(takes[0]["score"]["answering"])
				and float(takes[0]["score"]["marks"]["eco"]) > 0.99,
				"The command's reference argument must reach the real PCM/Eco path."
			)


func _write_wav(
	name: String, rate: int, stereo: bool, width: int, samples: PackedFloat32Array
) -> Dictionary:
	var channels := 2 if stereo else 1
	var data := PackedByteArray()
	data.resize(samples.size() * channels * width)
	var pcm := PackedVector2Array()
	pcm.resize(samples.size())
	var divisor := 128.0 if width == 1 else 32768.0
	for index in samples.size():
		var frame := Vector2.ZERO
		for channel in channels:
			var sample := float(samples[index]) * (0.5 if channel == 1 else 1.0)
			var quantized := roundi(sample * divisor)
			var offset := (index * channels + channel) * width
			if width == 1:
				data.encode_s8(offset, quantized)
			else:
				data.encode_s16(offset, quantized)
			frame[channel] = float(quantized) / divisor
		if not stereo:
			frame.y = frame.x
		pcm[index] = frame
	var stream := AudioStreamWAV.new()
	stream.mix_rate = rate
	stream.stereo = stereo
	stream.format = AudioStreamWAV.FORMAT_8_BITS if width == 1 else AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	var path := _wav_root.path_join(name + ".wav")
	_wav_files.append(path)
	var error := stream.save_to_wav(path)
	_expect(error == OK, "Write the synthetic WAV fixture.")
	return {"path": path, "pcm": pcm} if error == OK else {}


func _write_bytes(name: String, bytes: PackedByteArray) -> String:
	var path := _wav_root.path_join(name)
	_wav_files.append(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Write the malformed WAV fixture.")
	if file != null:
		file.store_buffer(bytes)
		file.close()
	return path


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
