extends RefCounted

## Pure capture-buffer-to-VoiceFrame pipeline. The scene owns permissions and
## audio devices; this object owns only one explicitly opened listening window.

const Detector = preload("res://games/sailor_man/voice/pitch_detector.gd")
const Track = preload("res://games/sailor_man/voice/voice_track.gd")
const WEB_WINDOWS_PER_FRAME := 8

var _detector := Detector.new()
var _track := Track.new()
var _sensitivity := 1.0
var _active := false


## Keep platform policy at source construction, not in gameplay rules.
static func live_analysis_budget() -> int:
	return WEB_WINDOWS_PER_FRAME if OS.has_feature("web") else -1


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
func push_frames(frames: PackedVector2Array, max_windows := -1) -> Array[Dictionary]:
	assert(_active, "Open a listening window before feeding microphone samples.")
	return _consume(_detector.push_frames(frames, max_windows))


## Exercise the same detector and normalization with synthesized mono buffers.
func push_samples(samples: PackedFloat32Array, max_windows := -1) -> Array[Dictionary]:
	assert(_active, "Open a listening window before feeding microphone samples.")
	return _consume(_detector.push_samples(samples, max_windows))


## Finish preserves buffered observations without fabricating a sung ending.
func finish() -> Array[Dictionary]:
	_active = false
	var result := _consume(_detector.push_samples(PackedFloat32Array()))
	result.append_array(_track.finish())
	return result


## Live web callers drain this queue in bounded render-frame slices before finish.
func has_pending_analysis() -> bool:
	return _detector.has_pending_analysis()


## Cancellation drops unscored work rather than blocking to analyse an abandoned take.
func cancel() -> void:
	_active = false
	_detector.reset()
	_track = Track.new()


func _consume(observations: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for observation in observations:
		observation["rms"] = float(observation["rms"]) * _sensitivity
		result.append_array(_track.push(observation))
	return result
