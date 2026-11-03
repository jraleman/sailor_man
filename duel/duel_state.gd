extends RefCounted

## A node-free best-of-three duel. Views play audio and collect input; only this
## model advances turns, awards tandas and owns the between-turn chamber clock.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Judges = preload("res://games/sailor_man/duel/judges.gd")
const Rivals = preload("res://games/sailor_man/duel/rival_book.gd")
const NORMAL_WINDOW := 6.0
const LONG_WINDOW := 9.0
const SILENCE_SECONDS := 1.2
const TAIL_SECONDS := 0.25
const CHAMBER_SECONDS := 240.0
const ECHO_DELAY := 0.6

enum Phase { READY, RIVAL, PLAYER_READY, GUARD, LISTENING, REVIEW, REPEAT, COMPLETE,
	ECHO_WAIT }
enum Singer { PLAYER, RIVAL }

var phase := Phase.READY
var tanda := 1
var leader := Singer.RIVAL
var singer := Singer.RIVAL
var turn := 0
var winner := -1
var reason := ""
var wins := PackedInt32Array([0, 0])
var points := PackedInt32Array([0, 0])
var records: Array[Dictionary] = []
var tandas: Array[Dictionary] = []
var call_track: Array[Dictionary] = []
var window_seconds := NORMAL_WINDOW
var window_elapsed := 0.0
var chamber_left := CHAMBER_SECONDS
var judge_count := 3
var uses_chamber_clock := true
var close_requested := false
var repeat_used := false
var echo_challenge := false
var preparing_seed := false
var echo_rival: Dictionary = {}
var hot_seat := false

var _chamber_seconds := CHAMBER_SECONDS
var _guard_left := 0.0
var _echo_left := 0.0
var _echo_phase := Phase.RIVAL
var _heard_voice := false
var _silent_frames := 0
var _received_frames := 0


## Retries discard duel-local results, never a save, calibration or achievement.
func reset(
	long_windows := false, chamber_seconds := CHAMBER_SECONDS, panel_size := 3,
	chamber_clock := true, self_echo := false, two_humans := false
) -> void:
	assert(is_finite(chamber_seconds) and chamber_seconds > 0.0)
	assert(panel_size in [3, 5])
	assert(not (self_echo and two_humans))
	phase = Phase.READY
	tanda = 1
	hot_seat = two_humans
	leader = Singer.PLAYER if hot_seat else Singer.RIVAL
	singer = leader
	turn = 0
	winner = -1
	reason = ""
	wins = PackedInt32Array([0, 0])
	points = PackedInt32Array([0, 0])
	records.clear()
	tandas.clear()
	call_track.clear()
	window_seconds = LONG_WINDOW if long_windows else NORMAL_WINDOW
	window_elapsed = 0.0
	_chamber_seconds = chamber_seconds
	chamber_left = chamber_seconds
	judge_count = panel_size
	uses_chamber_clock = chamber_clock and not hot_seat
	close_requested = false
	repeat_used = false
	echo_challenge = self_echo
	preparing_seed = self_echo
	echo_rival.clear()
	_echo_left = 0.0
	_echo_phase = Phase.RIVAL
	_reset_window()


## P1 calls first in hot seat; solo starts with its rival or an unscored seed.
func start() -> String:
	if phase != Phase.READY:
		return _error("Start a duel only from its ready card.")
	if preparing_seed or hot_seat:
		singer = leader if hot_seat else Singer.PLAYER
		phase = Phase.PLAYER_READY
	else:
		phase = Phase.RIVAL
	return ""


## Seed capture uses the same guarded window, but cannot award points or a tanda.
func finish_seed(
	track: Array[Dictionary], profile: Dictionary, quiet_mode := false
) -> String:
	if not preparing_seed or phase != Phase.LISTENING:
		return _error("A seed is accepted only inside the self-echo seed window.")
	if track.size() > roundi(window_seconds * Frame.RATE_HZ):
		return _error("The seed exceeds its listening window. Ready again to retry.")
	var snapshot := Rivals.echo_rival(track, profile, quiet_mode)
	if not bool(snapshot["valid"]):
		return str(snapshot["error"])
	echo_rival = snapshot
	preparing_seed = false
	singer = Singer.RIVAL
	_reset_window()
	_begin_playback(Phase.RIVAL)
	return ""


## Paddles remain readable until the player continues, rather than flashing past.
func continue_duel() -> String:
	if phase != Phase.REVIEW:
		return _error("Finish and review the current performance before continuing.")
	if turn == 0:
		turn = 1
		singer = Singer.PLAYER if leader == Singer.RIVAL else Singer.RIVAL
	else:
		tanda += 1
		turn = 0
		if tanda == 2:
			leader = Singer.RIVAL if hot_seat else Singer.PLAYER
		else:
			leader = _decider_leader()
		singer = leader
		call_track.clear()
		repeat_used = false
	_reset_window()
	if hot_seat or singer == Singer.PLAYER:
		phase = Phase.PLAYER_READY
	else:
		_begin_playback(Phase.RIVAL)
	return ""


## Either human's turn needs the full cue guard before any frame is admitted.
func cue_player() -> String:
	if phase != Phase.PLAYER_READY:
		return _error("The player can be cued only before their own turn.")
	_reset_window()
	_guard_left = TAIL_SECONDS
	phase = Phase.GUARD
	return ""


## Time inside either singer's performance never consumes the chamber clock.
func advance(delta: float) -> void:
	assert(is_finite(delta) and delta >= 0.0)
	if phase in [Phase.READY, Phase.COMPLETE]:
		return
	var between := delta
	if phase in [Phase.RIVAL, Phase.LISTENING]:
		between = 0.0
	elif phase == Phase.GUARD:
		between = minf(delta, _guard_left)
	if uses_chamber_clock:
		chamber_left = maxf(chamber_left - between, 0.0)
		if chamber_left <= 0.0:
			winner = Singer.RIVAL
			reason = "chamber_timeout"
			phase = Phase.COMPLETE
			return
	if phase == Phase.GUARD:
		_guard_left = maxf(_guard_left - delta, 0.0)
		if _guard_left <= Frame.TIME_TOLERANCE:
			phase = Phase.LISTENING
	elif phase == Phase.ECHO_WAIT:
		_echo_left = maxf(_echo_left - delta, 0.0)
		if _echo_left <= Frame.TIME_TOLERANCE:
			phase = _echo_phase
	elif phase == Phase.LISTENING:
		window_elapsed = minf(window_elapsed + delta, window_seconds)
		close_requested = close_requested or window_elapsed >= window_seconds


## Only captured silence can close early; missing PCM is never presumed silence.
func observe_frames(frames: Array[Dictionary]) -> String:
	if phase != Phase.LISTENING:
		return _error("Player frames are accepted only inside the listening window.")
	var error := Frame.track_error(frames)
	if not error.is_empty():
		return _error(error)
	if not frames.is_empty() and absf(
		float(frames[0]["t"]) - float(_received_frames) * Frame.STEP_SECONDS
	) > Frame.TIME_TOLERANCE:
		return _error("Duel frames must continue the current window's 100 Hz clock.")
	for frame: Dictionary in frames:
		if silence_closed() or _received_frames >= roundi(window_seconds * Frame.RATE_HZ):
			break
		if bool(frame["voiced"]):
			_heard_voice = true
			_silent_frames = 0
		else:
			_silent_frames += 1
		_received_frames += 1
		close_requested = close_requested or silence_closed()
	return ""


## A deadline stops capture, but queued analysis must still reach a real-silence cutoff.
func silence_closed() -> bool:
	return _heard_voice and _silent_frames >= roundi(SILENCE_SECONDS * Frame.RATE_HZ)


## A buffered poll may include audio after the first real-silence cutoff.
func accepted_frame_count() -> int:
	return _received_frames


## Scores come from SalomaScorer, regardless of which source supplied the track.
func finish_turn(result: Dictionary, track: Array[Dictionary], source: String) -> String:
	if phase not in [Phase.RIVAL, Phase.LISTENING]:
		return _error("A performance cannot score outside its singer's turn.")
	if preparing_seed:
		return _error("Finish the unscored seed before scoring a duel performance.")
	var error := Judges.result_error(result)
	if error.is_empty():
		error = Frame.track_error(track)
	if error.is_empty() and track.is_empty():
		error = "No performance frames arrived; retry rather than awarding a score."
	if error.is_empty() and bool(result["answering"]) != (turn == 1):
		error = "The scored call/answer flag does not match the duel's current turn."
	if not error.is_empty():
		return _error(error)
	var judgement := Judges.evaluate(result, judge_count)
	var record := {
		"tanda": tanda, "turn": turn, "singer": singer, "source": source,
		"result": result.duplicate(true), "judgement": judgement,
	}
	records.append(record)
	points[singer] += int(judgement["sum"])
	if turn == 0:
		call_track = track.duplicate(true)
	else:
		_award_tanda()
	close_requested = false
	phase = Phase.COMPLETE if winner >= 0 else Phase.REVIEW
	return ""


## Pause, focus loss and failed capture retry the same turn without a score.
func cancel_player() -> void:
	if phase in [Phase.GUARD, Phase.LISTENING]:
		_reset_window()
		phase = Phase.PLAYER_READY


## A repeat is playback, not an extra scored performance or another listening window.
func request_repeat() -> String:
	if phase != Phase.PLAYER_READY or turn != 1 or call_track.is_empty() or repeat_used:
		return _error("Repeat the completed call once, before starting its answer.")
	repeat_used = true
	_begin_playback(Phase.REPEAT)
	return ""


## Interrupted echoes restart with their quiet delay, not halfway through a take.
func restart_playback() -> void:
	if phase in [Phase.RIVAL, Phase.REPEAT]:
		_begin_playback(phase)
	elif phase == Phase.ECHO_WAIT:
		_echo_left = ECHO_DELAY


## The normal cue and tail guard are still required after replaying a call.
func finish_repeat() -> String:
	if phase != Phase.REPEAT:
		return _error("No call repeat is playing.")
	phase = Phase.PLAYER_READY
	return ""


## Water is presentation; it must never change scoring, turns or clock speed.
func chamber_fraction() -> float:
	return clampf(1.0 - chamber_left / _chamber_seconds, 0.0, 1.0) \
		if uses_chamber_clock else 0.0


func _begin_playback(next_phase: Phase) -> void:
	if echo_challenge:
		_echo_phase = next_phase
		_echo_left = ECHO_DELAY
		phase = Phase.ECHO_WAIT
	else:
		phase = next_phase


func _award_tanda() -> void:
	var call := records[-2]
	var answer := records[-1]
	var call_points := int(call["judgement"]["sum"])
	var answer_points := int(answer["judgement"]["sum"])
	var victor := int(call["singer"]) if call_points > answer_points else int(answer["singer"])
	wins[victor] += 1
	tandas.append({
		"winner": victor, "margin": absi(call_points - answer_points),
		"call_points": call_points, "answer_points": answer_points,
	})
	if wins[victor] == 2:
		winner = victor
		reason = "two_tandas"


func _decider_leader() -> int:
	# The owner chose the latest tanda's loser when the two margins are equal.
	var closer := 0 if int(tandas[0]["margin"]) < int(tandas[1]["margin"]) else 1
	return 1 - int(tandas[closer]["winner"])


func _reset_window() -> void:
	window_elapsed = 0.0
	close_requested = false
	_guard_left = 0.0
	_heard_voice = false
	_silent_frames = 0
	_received_frames = 0


func _error(message: String) -> String:
	push_warning("Sailor Man duel: %s" % message)
	return message
