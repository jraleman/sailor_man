extends RefCounted

## Development opponents use authored or completed tracks, never live microphone
## playback. Every turn passes through the same scorer as player performances.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const VOICED_SECONDS := 3.6
const RELEASE_SECONDS := 0.12


## Return fresh data so a replay or test cannot mutate the next duel's take.
static func practice_rival() -> Dictionary:
	return {
		"id": "synthetic_skiff",
		"title": "Practice skiff",
		"synthetic": true,
		"caption": "Synthetic rival: a held call, two register breaks, then a crisp finish.",
		"score_band": Vector2(0.55, 0.9),
		"profile": Frame.profile(Frame.DEFAULT_CHEST_HZ, true),
		"frames": _take(),
	}


## A fresh completed call is copied, not borrowed or saved as recorded audio.
static func echo_rival(
	frames: Array[Dictionary], profile: Dictionary, quiet_mode := false
) -> Dictionary:
	var error := Frame.profile_error(profile)
	if error.is_empty():
		error = Frame.track_error(frames)
	if error.is_empty() and (frames.is_empty()
			or absf(float(frames[0]["t"])) > Frame.TIME_TOLERANCE):
		error = "Make a complete seed call starting at the beginning of its window."
	if not error.is_empty():
		return _echo_error(error)
	var analysis := Scorer.score(frames, profile, [], quiet_mode)
	var evidence: Dictionary = analysis["evidence"]
	if float(evidence["voiced_seconds"]) <= 0.0:
		return _echo_error("Make a voiced seed call; silence cannot seed an echo.")
	var finish := float(analysis["marks"]["remate"])
	return {
		"valid": true, "id": "self_echo", "title": "Your echo",
		"caption": (
			"Your seed: %.1f s voiced, %d breaks, %s finish. "
			+ "Neutral synthetic tone, not recorded voice."
		) % [
			evidence["voiced_seconds"], (evidence["breaks"] as Array).size(),
			"clear" if finish >= 1.0 else ("soft" if finish > 0.0 else "no detected"),
		],
		"profile": profile.duplicate(true), "frames": frames.duplicate(true),
		"quiet_mode": quiet_mode,
	}


## Difficulty will choose takes later; it must never alter scoring rules.
static func score(rival: Dictionary, reference: Array[Dictionary] = []) -> Dictionary:
	return Scorer.score(rival["frames"], rival["profile"], reference,
		bool(rival.get("quiet_mode", false)))


static func _echo_error(message: String) -> Dictionary:
	push_warning("Sailor Man seed: %s" % message)
	return {"valid": false, "error": message}


static func _take() -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for index in roundi((VOICED_SECONDS + RELEASE_SECONDS) * Frame.RATE_HZ):
		var t := float(index) * Frame.STEP_SECONDS
		var cents := 0.0
		if t >= 1.0 and t < 1.04:
			cents = 700.0 * (t - 1.0 + Frame.STEP_SECONDS) / 0.04
		elif t >= 1.04 and t < 2.0:
			cents = 700.0
		elif t >= 2.0 and t < 2.04:
			cents = 700.0 * (1.0 - (t - 2.0 + Frame.STEP_SECONDS) / 0.04)
		var voiced := t < VOICED_SECONDS
		frames.append(Frame.make(t, cents, voiced, 1.0 if voiced else 0.0))
	return frames
