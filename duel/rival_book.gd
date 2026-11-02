extends RefCounted

## One explicitly synthetic, beatable development rival; no performer is implied.
## Authored frames pass through the same scorer as player performances.

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


## Difficulty will choose takes later; it must never alter scoring rules.
static func score(rival: Dictionary, reference: Array[Dictionary] = []) -> Dictionary:
	return Scorer.score(rival["frames"], rival["profile"], reference)


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
