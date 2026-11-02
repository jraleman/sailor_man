extends RefCounted

## Read-only recorded input for the same detector/normalizer as live capture.
## No playback, capture bus, imported asset or saved track is created.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Detector = preload("res://games/sailor_man/voice/pitch_detector.gd")
const Source = preload("res://games/sailor_man/voice/mic_voice_source.gd")

const DEFAULT_NOISE_FLOOR := Detector.DEFAULT_NOISE_FLOOR
const MINIMUM_INPUT_RATE := Detector.MAX_FREQUENCY * 2.0 * Detector.DECIMATION
const BUFFER_FRAMES := 4096
const LOAD_OPTIONS := {
	# Godot's runtime WAV loader otherwise defaults to lossy QOA.
	"compress/mode": 0,
	"edit/normalize": false,
	"edit/trim": false,
	"force/8_bit": false,
	"force/max_rate": false,
	"force/mono": false,
}


## Validate before the streaming source's assertions can abort an analysis.
static func configuration_error(
	profile: Dictionary, noise_floor: float, sensitivity: float
) -> String:
	var error := Frame.profile_error(profile)
	if not error.is_empty():
		return error
	if not is_finite(noise_floor) or noise_floor < 0.0:
		return "Noise floor must be finite and nonnegative."
	if not is_finite(sensitivity) or sensitivity <= 0.0:
		return "Sensitivity must be finite and positive."
	return ""


## Treat the complete file as one window, preserving silence, gain and rate.
static func read(
	path: String, profile: Dictionary,
	noise_floor := DEFAULT_NOISE_FLOOR, sensitivity := 1.0
) -> Dictionary:
	var error := configuration_error(profile, noise_floor, sensitivity)
	if not error.is_empty():
		return _invalid(path, error)
	if path.is_empty():
		return _invalid(path, "Supply a WAV file path.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _invalid(path, "Cannot read file: %s." % error_string(FileAccess.get_open_error()))
	var size := file.get_length()
	var container := file.get_buffer(size)
	file.close()
	if container.size() != size:
		return _invalid(path, "The WAV file is truncated.")
	error = _container_error(container)
	if not error.is_empty():
		return _invalid(path, error)
	var stream := AudioStreamWAV.load_from_buffer(container, LOAD_OPTIONS)
	if stream == null:
		return _invalid(path, "Godot could not decode this WAV file.")
	if stream.format not in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
		return _invalid(path, "The decoded WAV must contain uncompressed PCM.")
	if float(stream.mix_rate) <= MINIMUM_INPUT_RATE:
		return _invalid(path, "The WAV sample rate must exceed %.0f Hz." % MINIMUM_INPUT_RATE)

	var data := stream.data
	var sample_bytes := 1 if stream.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var channels := 2 if stream.stereo else 1
	var stride := sample_bytes * channels
	if data.is_empty() or data.size() % stride != 0:
		return _invalid(path, "The WAV has no complete PCM frames.")
	var count := int(data.size() / float(stride))
	var source := Source.new()
	source.begin(float(stream.mix_rate), profile, noise_floor, sensitivity)
	var track: Array[Dictionary] = []
	for start in range(0, count, BUFFER_FRAMES):
		var buffer := PackedVector2Array()
		buffer.resize(mini(BUFFER_FRAMES, count - start))
		for index in buffer.size():
			var offset := (start + index) * stride
			var left := _sample(data, offset, sample_bytes)
			var right := (
				_sample(data, offset + sample_bytes, sample_bytes) if channels == 2 else left
			)
			buffer[index] = Vector2(left, right)
		track.append_array(source.push_frames(buffer))
	track.append_array(source.finish())
	if track.is_empty():
		return _invalid(path, "The WAV is too short to contain analyzable audio.")
	var voiced := 0
	for frame in track:
		if bool(frame["voiced"]):
			voiced += 1
	return {
		"valid": true, "file": path, "sample_rate": stream.mix_rate,
		"channels": channels, "duration_seconds": float(count) / float(stream.mix_rate),
		"frame_count": track.size(), "voiced_frames": voiced, "track": track,
	}


static func _container_error(data: PackedByteArray) -> String:
	if (
		data.size() < 12 or data.slice(0, 4) != "RIFF".to_ascii_buffer()
		or data.slice(8, 12) != "WAVE".to_ascii_buffer()
	):
		return "Expected a RIFF/WAVE file."
	var end := int(data.decode_u32(4)) + 8
	if end != data.size():
		return "The RIFF size does not match the WAV file length."
	var cursor := 12
	var alignment := 0
	var data_sizes: Array[int] = []
	# Godot can recover partial chunks/frames; scoring must not hide that damage.
	while cursor < end:
		if end - cursor < 8:
			return "The WAV has an incomplete chunk header."
		var kind := data.slice(cursor, cursor + 4)
		var size := int(data.decode_u32(cursor + 4))
		var start := cursor + 8
		var padded_end := start + size + size % 2
		if padded_end > end:
			return "A WAV chunk extends beyond the RIFF container."
		if kind == "fmt ".to_ascii_buffer():
			if size < 16:
				return "The WAV format chunk is incomplete."
			var channels := data.decode_u16(start + 2)
			var rate := data.decode_u32(start + 4)
			if channels not in [1, 2]:
				return "Use a mono or stereo WAV."
			if float(rate) <= MINIMUM_INPUT_RATE:
				return "The WAV sample rate must exceed %.0f Hz." % MINIMUM_INPUT_RATE
			alignment = data.decode_u16(start + 12)
			var bits := data.decode_u16(start + 14)
			if bits == 0 or bits % 8 != 0 or alignment != channels * int(bits / 8.0):
				return "The WAV frame alignment is invalid; use uncompressed PCM."
		elif kind == "data".to_ascii_buffer():
			data_sizes.append(size)
		cursor = padded_end
	if alignment <= 0 or data_sizes.is_empty():
		return "The WAV needs format and data chunks."
	for size in data_sizes:
		if size == 0 or size % alignment != 0:
			return "The WAV data contains no complete PCM frames or an incomplete frame."
	return ""


static func _sample(data: PackedByteArray, offset: int, width: int) -> float:
	return (
		float(data.decode_s8(offset)) / 128.0 if width == 1
		else float(data.decode_s16(offset)) / 32768.0
	)


static func _invalid(path: String, error: String) -> Dictionary:
	push_warning("Sailor Man WAV input '%s': %s" % [path, error])
	return {"valid": false, "error": error}
