extends RefCounted

## The same five marks judge microphones, Remo and authored tracks.
## This is a game simplification, not a definition of a traditional saloma.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")

const EPSILON := 0.00001
const VOICING_SECONDS := 0.04
const BRIDGE_GAP_SECONDS := 0.06
const BREATH_SECONDS := 5.0
const BREAK_CENTS := 500.0
const SOFT_BREAK_CENTS := 400.0
const SOFT_BREAK_CLEANNESS := 0.8
const BREAK_SECONDS := 0.09
const BREAK_LANDING_SECONDS := 0.12
const BREAK_SETTLE_CENTS := 100.0
const BREAK_WOBBLE_CENTS := 180.0
const MAX_BREAKS := 3.0
const OCTAVE_CENTS := 1200.0
const OCTAVE_TOLERANCE := 35.0
const OCTAVE_ERROR_FRAMES := 2
const FINISH_SECONDS := 0.4
const FINISH_FALL_CENTS := 300.0
const FINISH_GLIDE_STEPS := 8
const FINISH_GLIDE_MAX_STEP_CENTS := 120.0
const FINISH_GLIDE_FALL_FRACTION := 0.75
const FINISH_CUT_SECONDS := 0.08
const FINISH_START_LEVEL := 0.8
const FINISH_END_LEVEL := 0.1
const FINISH_FADE_LEVEL := 0.5
const FADE_MARK := 0.5
const ECHO_POINTS := 64
const ECHO_BAND := 0.12
const ECHO_DISTANCE_CENTS := 400.0
const CARRY_LEVEL := 1.0
const POWER_MAJORITY := 0.5
const POWER_MULTIPLIER := 0.8
const WEIGHTS := {
	"aliento": 0.25, "quiebre": 0.30, "altura": 0.15,
	"remate": 0.15, "eco": 0.15,
}


## An empty reference is a call; answers earn Eco against a supplied call.
## Invalid input is distinguishable from a valid, silent performance.
static func score(
	frames: Array[Dictionary], profile: Dictionary,
	reference: Array[Dictionary] = [], quiet_mode := false
) -> Dictionary:
	var error := Frame.profile_error(profile)
	if error.is_empty():
		error = Frame.track_error(frames)
	if error.is_empty():
		error = Frame.track_error(reference)
	if not error.is_empty():
		push_warning("SalomaScorer: %s" % error)
		return {"valid": false, "error": error}

	var clean := _clean_track(frames)
	var voiced := _voiced_frames(clean)
	var segments := _segments(clean)
	var longest := {"start": 0.0, "end": 0.0, "seconds": 0.0}
	for segment: Dictionary in segments:
		if float(segment["seconds"]) > float(longest["seconds"]):
			longest = segment
	var breaks := _breaks(voiced, profile)
	var cleanness := 0.0
	for evidence: Dictionary in breaks:
		cleanness += float(evidence["cleanness"])
	var pitches := PackedFloat64Array()
	var below_carry := 0
	for frame: Dictionary in voiced:
		pitches.append(float(frame["cents"]))
		if float(frame["level"]) < CARRY_LEVEL:
			below_carry += 1
	pitches.sort()
	var marks := {
		"aliento": minf(float(longest["seconds"]) / BREATH_SECONDS, 1.0),
		"quiebre": minf(cleanness / MAX_BREAKS, 1.0),
		"altura": clampf(
			(_percentile(pitches, 0.9) - _percentile(pitches, 0.1))
			/ float(profile["falsetto_high"]), 0.0, 1.0
		),
		"remate": _finish(clean),
		"eco": _echo(voiced, _voiced_frames(_clean_track(reference))),
	}
	var answering := not reference.is_empty()
	var weight_sum := 0.0
	var total := 0.0
	for key: String in WEIGHTS:
		if key == "eco" and not answering:
			continue
		var weight := float(WEIGHTS[key])
		total += float(marks[key]) * weight
		weight_sum += weight
	total /= weight_sum
	var power_gated := (
		not quiet_mode and not voiced.is_empty()
		and float(below_carry) / float(voiced.size()) > POWER_MAJORITY
	)
	if power_gated:
		total *= POWER_MULTIPLIER
	return {
		"valid": true, "marks": marks, "total": clampf(total, 0.0, 1.0),
		"answering": answering, "power_gated": power_gated,
		"evidence": {
			"breaks": breaks, "longest_breath": longest,
			"voiced_seconds": float(voiced.size()) * Frame.STEP_SECONDS,
		},
	}


static func _clean_track(frames: Array[Dictionary]) -> Array[Dictionary]:
	var clean: Array[Dictionary] = frames.duplicate(true)
	var index := 0
	while index < clean.size():
		if not bool(clean[index]["voiced"]):
			index += 1
			continue
		var start := index
		while index < clean.size() and bool(clean[index]["voiced"]):
			index += 1
		if float(index - start) * Frame.STEP_SECONDS + EPSILON < VOICING_SECONDS:
			for short_index in range(start, index):
				clean[short_index]["voiced"] = false

	for i in range(1, clean.size() - 1):
		if not bool(clean[i - 1]["voiced"]) or not bool(clean[i]["voiced"]):
			continue
		var before := float(clean[i - 1]["cents"])
		if absf(absf(float(clean[i]["cents"]) - before) - OCTAVE_CENTS) > OCTAVE_TOLERANCE:
			continue
		for length in range(1, OCTAVE_ERROR_FRAMES + 1):
			if i + length >= clean.size() or not bool(clean[i + length]["voiced"]):
				break
			var after := float(clean[i + length]["cents"])
			if absf(after - before) <= OCTAVE_TOLERANCE:
				for transient in range(i, i + length):
					clean[transient]["cents"] = before
				break
			if absf(absf(after - before) - OCTAVE_CENTS) > OCTAVE_TOLERANCE:
				break
	return clean


static func _voiced_frames(frames: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for frame in frames:
		if bool(frame["voiced"]):
			result.append(frame)
	return result


static func _segments(frames: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for frame in frames:
		if not bool(frame["voiced"]):
			continue
		var t := float(frame["t"])
		if (
			not result.is_empty()
			and t - float(result[-1]["end"]) <= BRIDGE_GAP_SECONDS + EPSILON
		):
			result[-1]["end"] = t + Frame.STEP_SECONDS
			result[-1]["seconds"] = (
				float(result[-1]["end"]) - float(result[-1]["start"])
			)
		else:
			result.append({
				"start": t, "end": t + Frame.STEP_SECONDS,
				"seconds": Frame.STEP_SECONDS,
			})
	return result


static func _breaks(voiced: Array[Dictionary], profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var measured := bool(profile["falsetto_calibrated"])
	var threshold := BREAK_CENTS if measured else SOFT_BREAK_CENTS
	var last_break := -INF
	for landing in voiced.size():
		var target := voiced[landing]
		var t := float(target["t"])
		if t - last_break < BREAK_LANDING_SECONDS:
			continue
		for start in range(landing - 1, -1, -1):
			var origin := voiced[start]
			var from_time := float(origin["t"])
			if t - from_time > BREAK_SECONDS + EPSILON or from_time < last_break:
				break
			var from_pitch := float(origin["cents"])
			var to_pitch := float(target["cents"])
			if absf(to_pitch - from_pitch) + EPSILON < threshold:
				continue
			if measured and _in_band(from_pitch, profile) == _in_band(to_pitch, profile):
				continue
			var cleanness := _landing_cleanness(voiced, landing)
			if cleanness <= 0.0:
				continue
			if not measured:
				cleanness *= SOFT_BREAK_CLEANNESS
			result.append({
				"t": t, "from": from_pitch, "to": to_pitch,
				"cleanness": cleanness,
			})
			last_break = t
			break
	return result


static func _in_band(cents: float, profile: Dictionary) -> bool:
	return (
		cents >= float(profile["falsetto_low"])
		and cents <= float(profile["falsetto_high"])
	)


static func _landing_cleanness(voiced: Array[Dictionary], landing: int) -> float:
	var pitches := PackedFloat64Array()
	var start := float(voiced[landing]["t"])
	var end := start
	for index in range(landing, voiced.size()):
		var t := float(voiced[index]["t"])
		if t - start > BREAK_LANDING_SECONDS + EPSILON:
			break
		if t - end > BRIDGE_GAP_SECONDS + Frame.STEP_SECONDS + EPSILON:
			break
		pitches.append(float(voiced[index]["cents"]))
		end = t
	if end - start + Frame.STEP_SECONDS + EPSILON < VOICING_SECONDS:
		return 0.0
	pitches.sort()
	var median := _percentile(pitches, 0.5)
	if absf(float(voiced[landing]["cents"]) - median) > BREAK_SETTLE_CENTS:
		return 0.0
	var deviation := 0.0
	for pitch in pitches:
		deviation += absf(pitch - median)
	deviation /= float(pitches.size())
	return clampf(1.0 - deviation / BREAK_WOBBLE_CENTS, 0.0, 1.0)


static func _finish(frames: Array[Dictionary]) -> float:
	var last := -1
	for index in frames.size():
		if bool(frames[index]["voiced"]):
			last = index
	if last < 0:
		return 0.0
	var end_time := float(frames[last]["t"])
	var first := last
	while first > 0 and end_time - float(frames[first - 1]["t"]) <= FINISH_SECONDS + EPSILON:
		first -= 1
	var early_pitch := float(frames[last]["cents"])
	var peak_level := 0.0
	var falling_steps := 0
	var falling_cents := 0.0
	var rising_steps := 0
	for index in range(first, last + 1):
		if bool(frames[index]["voiced"]):
			early_pitch = maxf(early_pitch, float(frames[index]["cents"]))
			if index > first and bool(frames[index - 1]["voiced"]):
				var change := float(frames[index - 1]["cents"]) - float(frames[index]["cents"])
				if change > EPSILON and change <= FINISH_GLIDE_MAX_STEP_CENTS:
					falling_steps += 1
					falling_cents += change
				elif change < -EPSILON:
					rising_steps += 1
		peak_level = maxf(peak_level, float(frames[index]["level"]))
	if (
		early_pitch - float(frames[last]["cents"]) + EPSILON >= FINISH_FALL_CENTS
		and falling_cents + EPSILON >= FINISH_FALL_CENTS
		and falling_steps >= FINISH_GLIDE_STEPS
		and float(falling_steps) / float(falling_steps + rising_steps) >= FINISH_GLIDE_FALL_FRACTION
	):
		return 1.0
	if peak_level <= 0.0:
		return 0.0
	for index in range(first, last + 1):
		if float(frames[index]["level"]) < peak_level * FINISH_START_LEVEL:
			continue
		for stop in range(maxi(index + 1, last), frames.size()):
			if float(frames[stop]["t"]) - float(frames[index]["t"]) > FINISH_CUT_SECONDS + EPSILON:
				break
			if float(frames[stop]["level"]) <= peak_level * FINISH_END_LEVEL:
				return 1.0
	var tail := mini(last + int(FINISH_CUT_SECONDS * Frame.RATE_HZ), frames.size() - 1)
	return FADE_MARK if float(frames[tail]["level"]) < peak_level * FINISH_FADE_LEVEL else 0.0


static func _percentile(sorted: PackedFloat64Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	var position := float(sorted.size() - 1) * fraction
	var low := int(floor(position))
	return lerpf(sorted[low], sorted[mini(low + 1, sorted.size() - 1)], position - low)


static func _contour(voiced: Array[Dictionary]) -> PackedFloat64Array:
	var pitches := PackedFloat64Array()
	for frame in voiced:
		pitches.append(float(frame["cents"]))
	pitches.sort()
	var median := _percentile(pitches, 0.5)
	var result := PackedFloat64Array()
	var start := float(voiced[0]["t"])
	var duration := float(voiced[-1]["t"]) - start
	var cursor := 0
	for index in ECHO_POINTS:
		var t := start + duration * float(index) / float(ECHO_POINTS - 1)
		while cursor + 1 < voiced.size() and float(voiced[cursor + 1]["t"]) < t:
			cursor += 1
		var next := mini(cursor + 1, voiced.size() - 1)
		var span := float(voiced[next]["t"]) - float(voiced[cursor]["t"])
		var blend := (t - float(voiced[cursor]["t"])) / span if span > 0.0 else 0.0
		result.append(lerpf(
			float(voiced[cursor]["cents"]), float(voiced[next]["cents"]), blend
		) - median)
	return result


static func _echo(answer: Array[Dictionary], reference: Array[Dictionary]) -> float:
	if answer.is_empty() or reference.is_empty():
		return 0.0
	var a := _contour(answer)
	var b := _contour(reference)
	var previous := PackedFloat64Array()
	var previous_steps := PackedInt32Array()
	previous.resize(ECHO_POINTS + 1)
	previous.fill(INF)
	previous[0] = 0.0
	previous_steps.resize(ECHO_POINTS + 1)
	var band := int(ceil(float(ECHO_POINTS) * ECHO_BAND))
	for row in range(1, ECHO_POINTS + 1):
		var current := PackedFloat64Array()
		var steps := PackedInt32Array()
		current.resize(ECHO_POINTS + 1)
		current.fill(INF)
		steps.resize(ECHO_POINTS + 1)
		for column in range(maxi(1, row - band), mini(ECHO_POINTS, row + band) + 1):
			var cost := previous[column - 1]
			var count := previous_steps[column - 1]
			if previous[column] < cost:
				cost = previous[column]
				count = previous_steps[column]
			if current[column - 1] < cost:
				cost = current[column - 1]
				count = steps[column - 1]
			current[column] = cost + absf(a[row - 1] - b[column - 1])
			steps[column] = count + 1
		previous = current
		previous_steps = steps
	var distance := previous[ECHO_POINTS] / float(previous_steps[ECHO_POINTS])
	return exp(-distance / ECHO_DISTANCE_CENTS)
