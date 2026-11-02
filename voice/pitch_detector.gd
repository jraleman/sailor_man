extends RefCounted

## Game-local adaptation of Dead Metal Jam's MPM/NSDF detector. Only continuous
## frequency, clarity and RMS survive; instrument note/onset rules do not.

const DEFAULT_INPUT_RATE := 44100.0
const DECIMATION := 4
const WINDOW_SIZE := 512
const HOP_SECONDS := 0.01
const MIN_FREQUENCY := 70.0
const MAX_FREQUENCY := 1100.0
const RANGE_PADDING_SEMITONES := 1.0
const PEAK_THRESHOLD := 0.9
const MIN_CLARITY := 0.65
const DEFAULT_NOISE_FLOOR := 0.004
const GUARD_LAGS := 4

var _input_rate := DEFAULT_INPUT_RATE
var _work_rate := DEFAULT_INPUT_RATE / float(DECIMATION)
var _noise_floor := DEFAULT_NOISE_FLOOR
var _min_lag := 2
var _max_lag := 2
var _search_lag := 2
var _window_size := WINDOW_SIZE
var _hop_size := 110
var _raw := PackedFloat32Array()
var _pending := PackedFloat32Array()
var _consumed := 0


func _init(input_rate := DEFAULT_INPUT_RATE, noise_floor := DEFAULT_NOISE_FLOOR) -> void:
	configure(input_rate, noise_floor)


## Derive lags and hop size from the device, including 48 kHz microphones.
func configure(input_rate: float, noise_floor: float) -> void:
	assert(input_rate > MAX_FREQUENCY * 2.0 * DECIMATION)
	assert(is_finite(noise_floor) and noise_floor >= 0.0)
	_input_rate = input_rate
	_work_rate = input_rate / float(DECIMATION)
	_noise_floor = noise_floor
	var padding := pow(2.0, RANGE_PADDING_SEMITONES / 12.0)
	_min_lag = maxi(int(floor(_work_rate / (MAX_FREQUENCY * padding))), 2)
	_max_lag = int(ceil(_work_rate / (MIN_FREQUENCY / padding)))
	_search_lag = _max_lag + GUARD_LAGS
	_window_size = maxi(WINDOW_SIZE, _search_lag * 2 + 1)
	_hop_size = maxi(int(round(_work_rate * HOP_SECONDS)), 1)
	reset()


## No analysis from before a listening window may leak into the next call.
func reset() -> void:
	_raw = PackedFloat32Array()
	_pending = PackedFloat32Array()
	_consumed = 0


## Accept capture buffers without dropping hops when a render frame is late.
func push_frames(frames: PackedVector2Array) -> Array[Dictionary]:
	var mono := PackedFloat32Array()
	mono.resize(frames.size())
	for index in frames.size():
		mono[index] = (frames[index].x + frames[index].y) * 0.5
	return push_samples(mono)


## A mono entry point keeps the full streaming path testable without hardware.
func push_samples(samples: PackedFloat32Array) -> Array[Dictionary]:
	_raw.append_array(samples)
	var usable := _raw.size() - _raw.size() % DECIMATION
	for offset in range(0, usable, DECIMATION):
		var sum := 0.0
		for index in DECIMATION:
			sum += _raw[offset + index]
		_pending.append(sum / float(DECIMATION))
	_raw = _raw.slice(usable)
	var results: Array[Dictionary] = []
	while _pending.size() >= _window_size:
		var analysis := analyse_window(_pending.slice(0, _window_size))
		analysis["t"] = float((_consumed + _window_size) * DECIMATION) / _input_rate
		results.append(analysis)
		_pending = _pending.slice(_hop_size)
		_consumed += _hop_size
	return results


## The single-window path takes decimated samples and has no streaming state.
func analyse_window(window: PackedFloat32Array) -> Dictionary:
	var result := {
		"t": 0.0, "voiced": false, "frequency": 0.0,
		"rms": 0.0, "confidence": 0.0,
	}
	if window.size() < _window_size:
		return result
	var mean := 0.0
	for index in _window_size:
		mean += window[index]
	mean /= float(_window_size)
	var centred := PackedFloat32Array()
	centred.resize(_window_size)
	var energy := 0.0
	for index in _window_size:
		var value := window[index] - mean
		centred[index] = value
		energy += value * value
	var rms := sqrt(energy / float(_window_size))
	result["rms"] = rms
	if rms <= _noise_floor:
		return result

	var nsdf := _normalised_square_difference(centred)
	var peak := _pick_peak(nsdf)
	if peak < 0:
		return result
	var refined := _interpolate_peak(nsdf, peak)
	result["voiced"] = true
	result["frequency"] = _work_rate / refined.x
	result["confidence"] = clampf(refined.y, 0.0, 1.0)
	return result


## Exposed for deterministic sample synthesis at the actual analysis rate.
func work_sample_rate() -> float:
	return _work_rate


## High-rate devices need a larger window to retain at least two low periods.
func window_size() -> int:
	return _window_size


func _normalised_square_difference(samples: PackedFloat32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(_search_lag + 1)
	for lag in range(_search_lag + 1):
		var correlation := 0.0
		var magnitude := 0.0
		for index in samples.size() - lag:
			var a := samples[index]
			var b := samples[index + lag]
			correlation += a * b
			magnitude += a * a + b * b
		result[lag] = 2.0 * correlation / magnitude if magnitude > 0.0 else 0.0
	return result


func _pick_peak(nsdf: PackedFloat32Array) -> int:
	var peaks := PackedInt32Array()
	var clarities := PackedFloat32Array()
	var strongest := 0.0
	for lag in range(_min_lag, _max_lag + 1):
		if nsdf[lag] > nsdf[lag - 1] and nsdf[lag] >= nsdf[lag + 1]:
			var clarity := _interpolate_peak(nsdf, lag).y
			peaks.append(lag)
			clarities.append(clarity)
			strongest = maxf(strongest, clarity)
	if strongest < MIN_CLARITY:
		return -1
	for index in peaks.size():
		if clarities[index] >= strongest * PEAK_THRESHOLD:
			return peaks[index]
	return -1


func _interpolate_peak(nsdf: PackedFloat32Array, lag: int) -> Vector2:
	var before := nsdf[lag - 1]
	var here := nsdf[lag]
	var after := nsdf[lag + 1]
	var curvature := before - 2.0 * here + after
	if absf(curvature) < 0.000001:
		return Vector2(float(lag), here)
	var shift := clampf(0.5 * (before - after) / curvature, -1.0, 1.0)
	return Vector2(float(lag) + shift, here - 0.25 * (before - after) * shift)
