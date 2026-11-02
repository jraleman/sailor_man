extends RefCounted

## Normalizes pitch, delays octave decisions by two observations and resamples
## onto the shared clock. Real, sustained register jumps bypass smoothing.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const OCTAVE_CENTS := 1200.0
const OCTAVE_TOLERANCE := 35.0
const OCTAVE_LOOKAHEAD := 2
const VOICING_OBSERVATIONS := 4
const SMOOTH_CENTS := 150.0
const MEDIAN_OBSERVATIONS := 3

var _profile: Dictionary = {}
var _pending: Array[Dictionary] = []
var _recent := PackedFloat64Array()
var _emitted := 0
var _voiced_run := 0
var _unvoiced_run := 0
var _voiced := false
var _pitch := 0.0


## A new window starts with no pitch, voicing or octave history.
func configure(profile: Dictionary) -> void:
	assert(Frame.profile_error(profile).is_empty())
	_profile = profile.duplicate()
	_pending.clear()
	_recent = PackedFloat64Array()
	_emitted = 0
	_voiced_run = 0
	_unvoiced_run = 0
	_voiced = false
	_pitch = 0.0


## Keep enough future observations to distinguish glitches from real octaves.
func push(observation: Dictionary) -> Array[Dictionary]:
	_pending.append(observation.duplicate())
	if _pending.size() <= OCTAVE_LOOKAHEAD:
		return []
	return _consume()


## Release the short look-ahead tail when recording ends.
func finish() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	while not _pending.is_empty():
		result.append_array(_consume())
	return result


func _consume() -> Array[Dictionary]:
	var observation: Dictionary = _pending.pop_front()
	var normalized := Frame.from_frequency(
		float(observation["t"]), float(observation["frequency"]),
		float(observation["rms"]), _profile, bool(observation["voiced"])
	)
	var cents := float(normalized["cents"])
	if bool(normalized["voiced"]):
		if _is_octave_error(cents):
			cents = _pitch
		if _voiced and absf(cents - _pitch) <= SMOOTH_CENTS:
			_recent.append(cents)
			while _recent.size() > MEDIAN_OBSERVATIONS:
				_recent.remove_at(0)
			var sorted := _recent.duplicate()
			sorted.sort()
			cents = sorted[sorted.size() / 2]
		else:
			_recent = PackedFloat64Array([cents])
		_pitch = cents
		_voiced_run += 1
		_unvoiced_run = 0
		if _voiced_run >= VOICING_OBSERVATIONS:
			_voiced = true
	else:
		_voiced_run = 0
		_unvoiced_run += 1
		if _unvoiced_run >= VOICING_OBSERVATIONS:
			_voiced = false
			_recent = PackedFloat64Array()
	var result: Array[Dictionary] = []
	while (
		float(_emitted) / Frame.RATE_HZ
		<= float(observation["t"]) + Frame.TIME_TOLERANCE
	):
		result.append(Frame.make(
			float(_emitted) / Frame.RATE_HZ,
			_pitch if _voiced else 0.0, _voiced, float(normalized["level"])
		))
		_emitted += 1
	return result


func _is_octave_error(cents: float) -> bool:
	if not _voiced or absf(absf(cents - _pitch) - OCTAVE_CENTS) > OCTAVE_TOLERANCE:
		return false
	for index in mini(OCTAVE_LOOKAHEAD, _pending.size()):
		var observation := _pending[index]
		if not bool(observation["voiced"]) or float(observation["frequency"]) <= 0.0:
			return false
		var future := 1200.0 * log(
			float(observation["frequency"]) / float(_profile["chest_hz"])
		) / log(2.0)
		if absf(future - _pitch) <= OCTAVE_TOLERANCE:
			return true
		if absf(absf(future - _pitch) - OCTAVE_CENTS) > OCTAVE_TOLERANCE:
			return false
	return false
