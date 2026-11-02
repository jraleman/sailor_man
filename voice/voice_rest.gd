extends RefCounted

## Session-local reminders count completed voiced microphone turns, never
## recordings, synthetic turns or elapsed play time. Dismissal prevents nagging.

const TURNS := 6
const WINDOW_SECONDS := 600.0

var _turns: Array[float] = []


## The input controller reports success only after a real take has been scored.
func record_turn(now: float, voiced: bool) -> void:
	assert(is_finite(now) and now >= 0.0)
	_prune(now)
	if voiced:
		_turns.append(now)


## A view may offer rest between duels, never interrupt a performance.
func is_due(now: float) -> bool:
	_prune(now)
	return _turns.size() >= TURNS


## Not now and Use Remo both acknowledge this group, not force a timed break.
func dismiss() -> void:
	_turns.clear()


func _prune(now: float) -> void:
	while not _turns.is_empty() and now - _turns[0] > WINDOW_SECONDS:
		_turns.remove_at(0)
