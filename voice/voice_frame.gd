extends RefCounted

## Source-neutral, 100 Hz voice tracks. Pitch is relative to the singer, and
## level is linear amplitude relative to their comfortable carrying level.

const RATE_HZ := 100.0
const STEP_SECONDS := 1.0 / RATE_HZ
const TIME_TOLERANCE := 0.00001
const DEFAULT_CHEST_HZ := 160.0
const DEFAULT_FALSETTO_LOW := 700.0
const DEFAULT_FALSETTO_HIGH := 1300.0
const DEFAULT_CARRY_LEVEL := 0.08


## A temporary reference for the spike, not a saved or measured calibration.
static func profile(
	chest_hz := DEFAULT_CHEST_HZ, falsetto_calibrated := false
) -> Dictionary:
	return {
		"chest_hz": chest_hz,
		"falsetto_low": DEFAULT_FALSETTO_LOW,
		"falsetto_high": DEFAULT_FALSETTO_HIGH,
		"falsetto_calibrated": falsetto_calibrated,
		"carry_level": DEFAULT_CARRY_LEVEL,
	}


## Capping amplitude prevents extra volume from buying a better mark.
static func make(t: float, cents: float, voiced: bool, level: float) -> Dictionary:
	return {
		"t": t, "cents": cents, "voiced": voiced,
		"level": clampf(level, 0.0, 1.0),
	}


## Normalize before judging so different vocal registers share the same rules.
static func from_frequency(
	t: float, frequency: float, rms: float, reference: Dictionary, voiced := true
) -> Dictionary:
	var audible := voiced and frequency > 0.0
	var cents := (
		1200.0 * log(frequency / float(reference["chest_hz"])) / log(2.0)
		if audible else 0.0
	)
	return make(t, cents, audible, rms / float(reference["carry_level"]))


## Reject malformed references explicitly rather than quietly changing the rules.
static func profile_error(reference: Dictionary) -> String:
	for key in ["chest_hz", "falsetto_low", "falsetto_high", "carry_level"]:
		if not reference.has(key) or not _finite_number(reference[key]):
			return "Voice profile needs a finite %s." % key
	if float(reference["chest_hz"]) <= 0.0 or float(reference["carry_level"]) <= 0.0:
		return "Chest frequency and carrying level must be positive."
	if (
		float(reference["falsetto_low"]) <= 0.0
		or float(reference["falsetto_high"]) <= float(reference["falsetto_low"])
	):
		return "The falsetto band must have positive, increasing bounds."
	if typeof(reference.get("falsetto_calibrated")) != TYPE_BOOL:
		return "Voice profile must say whether its falsetto band was measured."
	return ""


## Missing samples must not masquerade as a long, continuously held breath.
static func track_error(frames: Array[Dictionary]) -> String:
	var previous := -STEP_SECONDS
	for index in frames.size():
		var frame := frames[index]
		for key in ["t", "cents", "level"]:
			if not frame.has(key) or not _finite_number(frame[key]):
				return "Voice frame %d needs a finite %s." % [index, key]
		if typeof(frame.get("voiced")) != TYPE_BOOL:
			return "Voice frame %d needs a voiced flag." % index
		var t := float(frame["t"])
		if t < 0.0 or float(frame["level"]) < 0.0:
			return "Voice timestamps and levels cannot be negative."
		if index > 0 and absf(t - previous - STEP_SECONDS) > TIME_TOLERANCE:
			return "Voice tracks must contain consecutive 100 Hz frames."
		previous = t
	return ""


static func _finite_number(value: Variant) -> bool:
	return (
		(typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT)
		and is_finite(float(value))
	)
