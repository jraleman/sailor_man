extends RefCounted

## Pure capture-buffer-to-VoiceFrame pipeline. The scene owns permissions and
## audio devices; this object owns only one explicitly opened listening window.

const Detector = preload("res://games/sailor_man/voice/pitch_detector.gd")
const Track = preload("res://games/sailor_man/voice/voice_track.gd")

var _detector := Detector.new()
var _track := Track.new()
var _sensitivity := 1.0
var _active := false


## Reset both filters at the cue, not when a previous call happens to finish.
func begin(
	sample_rate: float, profile: Dictionary, noise_floor: float, sensitivity := 1.0
) -> void:
	assert(is_finite(sensitivity) and sensitivity > 0.0)
	_sensitivity = sensitivity
	_detector.configure(sample_rate, noise_floor / sensitivity)
	_track.configure(profile)
	_active = true


## The view passes only samples captured inside its listening window.
func push_frames(frames: PackedVector2Array) -> Array[Dictionary]:
	assert(_active, "Open a listening window before feeding microphone samples.")
	return _consume(_detector.push_frames(frames))


## Exercise the same detector and normalization with synthesized mono buffers.
func push_samples(samples: PackedFloat32Array) -> Array[Dictionary]:
	assert(_active, "Open a listening window before feeding microphone samples.")
	return _consume(_detector.push_samples(samples))


## Finish preserves buffered observations without fabricating a sung ending.
func finish() -> Array[Dictionary]:
	_active = false
	return _track.finish()


func _consume(observations: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for observation in observations:
		observation["rms"] = float(observation["rms"]) * _sensitivity
		result.append_array(_track.push(observation))
	return result
