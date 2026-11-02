extends RefCounted

## Judges reweight the shared marks, never the microphone or a rival's raw track.
## Numbered paddles and evidence-based notes keep preferences visible and testable.

const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const PANEL: Array[Dictionary] = [
	{"id": "break", "name": "Break judge", "badge": "Q", "taste": "quiebre"},
	{"id": "breath", "name": "Breath judge", "badge": "A", "taste": "aliento"},
	{"id": "echo", "name": "Echo judge", "badge": "E", "taste": "eco"},
	{"id": "finish", "name": "Finish judge", "badge": "R", "taste": "remate"},
	{"id": "range", "name": "Range judge", "badge": "H", "taste": "altura"},
]
const TASTE_MULTIPLIER := 1.5


## Neutral development names do not stand in for culturally reviewed characters.
static func panel(count := 3) -> Array[Dictionary]:
	assert(count in [3, 5], "A duel needs three or five judges.")
	return PANEL.slice(0, count).duplicate(true)


## Calls omit Eco; a carrying-level penalty applies once, after reweighting.
static func evaluate(result: Dictionary, count := 3) -> Dictionary:
	var error := result_error(result)
	if not error.is_empty():
		push_warning("Sailor Man judges: %s" % error)
		return {"valid": false, "error": error}
	var paddles: Array[Dictionary] = []
	var points := 0
	for judge: Dictionary in panel(count):
		var weighted := 0.0
		var weight_sum := 0.0
		for mark: String in Scorer.WEIGHTS:
			if mark == "eco" and not bool(result["answering"]):
				continue
			var weight := float(Scorer.WEIGHTS[mark])
			if mark == str(judge["taste"]):
				weight *= TASTE_MULTIPLIER
			weighted += float(result["marks"][mark]) * weight
			weight_sum += weight
		var total := weighted / weight_sum
		if bool(result["power_gated"]):
			total *= Scorer.POWER_MULTIPLIER
		var paddle := judge.duplicate(true)
		paddle["total"] = total
		paddle["points"] = clampi(roundi(total * 10.0), 1, 10)
		paddle["note"] = _note(str(judge["taste"]), result)
		paddles.append(paddle)
		points += int(paddle["points"])
	return {"valid": true, "paddles": paddles, "sum": points}


## A malformed score is an error, not three plausible minimum paddles.
static func result_error(result: Dictionary) -> String:
	if result.get("valid") != true:
		return str(result.get("error", "A valid scored performance is required."))
	for key in ["answering", "power_gated"]:
		if typeof(result.get(key)) != TYPE_BOOL:
			return "A scored performance needs its %s flag." % key
	if not _unit_number(result.get("total")):
		return "A scored performance needs a finite total between zero and one."
	if typeof(result.get("marks")) != TYPE_DICTIONARY:
		return "A scored performance needs all five marks."
	for mark: String in Scorer.WEIGHTS:
		if not _unit_number(result["marks"].get(mark)):
			return "A scored performance needs a finite %s mark between zero and one." % mark
	if typeof(result.get("evidence")) != TYPE_DICTIONARY:
		return "A scored performance needs its evidence."
	var evidence: Dictionary = result["evidence"]
	if typeof(evidence.get("breaks")) != TYPE_ARRAY:
		return "Break evidence must be an array."
	if (
		typeof(evidence.get("longest_breath")) != TYPE_DICTIONARY
		or not _nonnegative_number(evidence["longest_breath"].get("seconds"))
	):
		return "Breath evidence needs a finite, nonnegative duration."
	return ""


static func _note(mark: String, result: Dictionary) -> String:
	var evidence: Dictionary = result["evidence"]
	var percent := roundi(float(result["marks"][mark]) * 100.0)
	match mark:
		"quiebre":
			return "%d detected breaks; clean-break mark %d%%." % [
				(evidence["breaks"] as Array).size(), percent,
			]
		"aliento":
			return "Longest breath %.2f s." % float(evidence["longest_breath"]["seconds"])
		"eco":
			return "Echo match %d%%." % percent if bool(result["answering"]) \
				else "Calls do not score Eco."
		"remate":
			return "Finish mark %d%%." % percent
	return "Range mark %d%%." % percent


static func _unit_number(value: Variant) -> bool:
	return _nonnegative_number(value) and float(value) <= 1.0


static func _nonnegative_number(value: Variant) -> bool:
	return (
		typeof(value) in [TYPE_FLOAT, TYPE_INT]
		and is_finite(float(value)) and float(value) >= 0.0
	)
