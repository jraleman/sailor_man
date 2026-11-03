extends SceneTree

## Deterministic duel rules and real scorer/rival checks need no audio hardware.

const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const Judges = preload("res://games/sailor_man/duel/judges.gd")
const Rivals = preload("res://games/sailor_man/duel/rival_book.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Fixture = preload("res://games/sailor_man/tests/voice_track_fixture.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_leads_and_decider()
	_test_closer_tanda()
	_test_sweep_and_retry()
	_test_windows_and_guard()
	_test_clock_and_repeat()
	_test_open_water()
	_test_refused_scores()
	_test_judges()
	_test_rival()
	_test_self_echo()
	_test_echo_snapshot()
	if _failures.is_empty():
		print("Duel state, judges, synthetic rival and self-echo tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_leads_and_decider() -> void:
	var duel := Duel.new()
	duel.reset()
	_expect(duel.start().is_empty() and duel.singer == Duel.Singer.RIVAL,
		"The rival must call in tanda one.")
	_finish(duel, 0.5)
	duel.continue_duel()
	_open_player(duel)
	_finish(duel, 0.5)
	_expect(duel.wins[0] == 1, "A tied first tanda must go to the player answering.")
	duel.continue_duel()
	_expect(duel.singer == Duel.Singer.PLAYER and duel.call_track.is_empty(),
		"The player must call in tanda two, with no inherited Eco reference.")
	_open_player(duel)
	_finish(duel, 0.5)
	duel.continue_duel()
	_finish(duel, 0.5)
	_expect(duel.wins == PackedInt32Array([1, 1]),
		"The rival answering a tied second tanda must force a decider.")
	duel.continue_duel()
	_expect(duel.tanda == 3 and duel.leader == Duel.Singer.PLAYER,
		"Equal margins must give the decider call to the second tanda's loser.")
	_open_player(duel)
	_finish(duel, 1.0)
	duel.continue_duel()
	_finish(duel, 0.2)
	_expect(duel.winner == Duel.Singer.PLAYER and duel.phase == Duel.Phase.COMPLETE,
		"The first singer to two tandas must end the best-of-three duel.")


func _test_closer_tanda() -> void:
	var duel := Duel.new()
	duel.reset()
	duel.start()
	_finish(duel, 0.5)
	duel.continue_duel()
	_open_player(duel)
	_finish(duel, 0.6)
	duel.continue_duel()
	_open_player(duel)
	_finish(duel, 0.2)
	duel.continue_duel()
	_finish(duel, 0.8)
	duel.continue_duel()
	_expect(duel.leader == Duel.Singer.RIVAL,
		"The loser of the closer first tanda must lead even after winning tanda two.")


func _test_sweep_and_retry() -> void:
	var duel := Duel.new()
	duel.reset()
	duel.start()
	_finish(duel, 0.2)
	duel.continue_duel()
	_open_player(duel)
	_finish(duel, 1.0)
	duel.continue_duel()
	_open_player(duel)
	_finish(duel, 1.0)
	duel.continue_duel()
	_finish(duel, 0.2)
	_expect(duel.wins[0] == 2 and duel.tandas.size() == 2 and duel.records.size() == 4,
		"A 2-0 sweep must not manufacture a third tanda.")
	duel.reset()
	_expect(duel.phase == Duel.Phase.READY and duel.winner == -1
		and duel.records.is_empty() and duel.call_track.is_empty()
		and duel.points == PackedInt32Array([0, 0]),
		"Retry must clear all duel-local scores, references and winner state.")


func _test_windows_and_guard() -> void:
	var duel := _player_ready()
	duel.cue_player()
	duel.advance(0.24)
	_expect(duel.phase == Duel.Phase.GUARD
		and not duel.observe_frames(_track()).is_empty(),
		"Neither a cue nor a rival tail may enter the player's scored window.")
	duel.advance(0.01)
	_expect(duel.phase == Duel.Phase.LISTENING and duel.window_elapsed == 0.0,
		"Only the complete 250 ms guard may open a fresh listening clock.")
	duel.advance(1.2)
	_expect(not duel.close_requested, "Initial silence must not close a window early.")
	duel.observe_frames(_track())
	duel.advance(2.0)
	_expect(not duel.close_requested, "Missing PCM must not count as a captured silent tail.")
	var silence: Array[Dictionary] = []
	for index in 120:
		silence.append(Frame.make(0.2 + float(index) * 0.01, 0.0, false, 0.0))
	duel.observe_frames(silence)
	_expect(duel.close_requested, "1.2 seconds of actual silence after voice must close early.")
	var reference := duel.call_track.duplicate(true)
	duel.cancel_player()
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1
		and duel.call_track == reference,
		"Cancelling must retry the same answer without losing its call or scoring a turn.")
	_open_player(duel)
	duel.advance(6.0)
	_expect(duel.close_requested, "A normal window must close at six seconds.")
	duel.observe_frames(_track())
	_expect(duel.accepted_frame_count() == 20 and not duel.silence_closed(),
		"A wall-clock deadline must still admit captured frames queued for bounded analysis.")
	duel.observe_frames(silence)
	_expect(duel.silence_closed() and duel.accepted_frame_count() == 140,
		"A late analysis batch must retain the real-silence cutoff, not the queue's end.")
	duel = _player_ready(true)
	_open_player(duel)
	duel.advance(6.0)
	_expect(not duel.close_requested, "Longer windows must retain the extra three seconds.")
	duel.advance(3.0)
	_expect(duel.close_requested, "A longer window must close at nine seconds.")


func _test_clock_and_repeat() -> void:
	var duel := _player_ready()
	var before := duel.chamber_left
	duel.request_repeat()
	duel.advance(0.5)
	duel.finish_repeat()
	_expect(is_equal_approx(duel.chamber_left, before - 0.5) and duel.records.size() == 1,
		"A repeat consumes between-turn time, but never scores a second rival call.")
	_expect(not duel.request_repeat().is_empty(), "Each answer gets at most one call repeat.")
	_open_player(duel)
	before = duel.chamber_left
	duel.advance(5.0)
	_expect(duel.chamber_left == before, "Listening time must never advance the chamber clock.")
	duel.cancel_player()
	duel.advance(duel.chamber_left)
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.reason == "chamber_timeout"
		and duel.winner == Duel.Singer.RIVAL,
		"The chamber deadline must settle a rival win between turns.")


func _test_refused_scores() -> void:
	var duel := _player_ready()
	var count := duel.records.size()
	_expect(not duel.finish_turn(_result(0.8, true), _track(), "remo").is_empty()
		and duel.records.size() == count,
		"Input outside a listening window must never award a performance.")
	_open_player(duel)
	var invalid := _result(0.8, true)
	invalid["marks"]["eco"] = NAN
	_expect(not duel.finish_turn(invalid, _track(), "remo").is_empty()
		and duel.records.size() == count,
		"Nonfinite marks must be refused without advancing a turn.")
	_expect(not duel.finish_turn(_result(0.8, false), _track(), "remo").is_empty(),
		"A call score must not be accepted as an answer.")
	var empty: Array[Dictionary] = []
	_expect(not duel.finish_turn(_result(0.0, true), empty, "microphone").is_empty(),
		"Missing audio must not become a minimum-paddle performance.")


func _test_open_water() -> void:
	var duel := Duel.new()
	duel.reset(false, 0.1, 5, false)
	duel.start()
	_finish(duel, 1.0)
	duel.continue_duel()
	var before := duel.chamber_left
	duel.advance(900.0)
	duel.request_repeat()
	duel.advance(900.0)
	duel.finish_repeat()
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.winner == -1
		and duel.chamber_left == before and duel.records.size() == 1
		and is_zero_approx(duel.chamber_fraction()),
		"Open water has no hidden between-turn deadline, including its free Repeat.")
	_open_player(duel)
	duel.advance(6.0)
	_expect(duel.close_requested, "Untimed open water must still bound every scored window.")
	_finish(duel, 1.0)
	_expect((duel.records[-1]["judgement"]["paddles"] as Array).size() == 5
		and duel.points == PackedInt32Array([50, 50]) and duel.wins[0] == 1,
		"A Pacific tied tanda must count all five real paddles and still go to the answerer.")
	duel.reset()
	_expect(duel.uses_chamber_clock and duel.judge_count == 3,
		"Returning from open water must restore default lock rules, not leak arena state.")


func _test_judges() -> void:
	var result := _result(0.0, false)
	result["marks"]["aliento"] = 1.0
	result["marks"]["eco"] = 1.0
	var judged := Judges.evaluate(result)
	var paddles: Array = judged["paddles"]
	_expect(float(paddles[1]["total"]) > float(paddles[0]["total"]),
		"Judge tastes must change the weight of the actual scored marks.")
	result["marks"]["eco"] = 0.0
	_expect(Judges.evaluate(result)["sum"] == judged["sum"],
		"A call's Eco value must not influence any judge, including the Echo judge.")
	var gated := _result(1.0, true)
	gated["power_gated"] = true
	var five := Judges.evaluate(gated, 5)
	_expect((five["paddles"] as Array).size() == 5 and int(five["sum"]) == 40,
		"Five judges must apply the carrying-level penalty once, not twice.")
	_expect(Judges.evaluate(_result(0.0, true))["sum"] == 3,
		"Valid silence receives the promised minimum numbered paddles, not an error.")


func _test_rival() -> void:
	var rival := Rivals.practice_rival()
	var call := Rivals.score(rival)
	var shape := Fixture.shaped()
	var player := Scorer.score(shape, Frame.profile(), rival["frames"])
	var rival_answer := Rivals.score(rival, shape)
	var band: Vector2 = rival["score_band"]
	_expect(bool(call["valid"]) and float(call["total"]) >= band.x
		and float(call["total"]) <= band.y
		and float(rival_answer["total"]) >= band.x
		and float(rival_answer["total"]) <= band.y,
		"The actual authored rival call and answer must stay inside their declared band.")
	_expect(int(Judges.evaluate(player)["sum"]) > int(Judges.evaluate(call)["sum"]),
		"A reachable shaped player answer must beat the placeholder's real scored call.")
	var flat := Fixture.new()
	flat.hold(5.0)
	flat.cut_off()
	var weak := Scorer.score(flat.frames, Frame.profile(), rival["frames"])
	_expect(int(Judges.evaluate(weak)["sum"]) < int(Judges.evaluate(call)["sum"]),
		"The placeholder must not automatically lose to a flat hold.")
	var second := Rivals.practice_rival()
	(rival["frames"] as Array).clear()
	_expect(not (second["frames"] as Array).is_empty(),
		"One take's mutation must not damage the next duel's authored data.")


func _test_self_echo() -> void:
	var duel := Duel.new()
	duel.reset(false, Duel.CHAMBER_SECONDS, 3, false, true)
	duel.start()
	_expect(duel.preparing_seed and duel.phase == Duel.Phase.PLAYER_READY
		and duel.singer == Duel.Singer.PLAYER and duel.records.is_empty(),
		"Self-echo must first ask for a fresh player seed, not play the synthetic skiff.")
	duel.cue_player()
	duel.advance(0.24)
	_expect(not duel.finish_seed(_track(), Frame.profile()).is_empty(),
		"Neither a seed nor a scored turn may bypass the complete cue guard.")
	duel.advance(0.01)
	_expect(not duel.finish_turn(_result(0.5, false), _track(), "seed").is_empty(),
		"The seed window must not accidentally award player points.")
	var silence: Array[Dictionary] = [Frame.make(0.0, 0.0, false, 0.0)]
	_expect(not duel.finish_seed(silence, Frame.profile()).is_empty()
		and duel.echo_rival.is_empty() and duel.preparing_seed,
		"Silence must give a retryable seed error, not a fictional silent opponent.")
	duel.cancel_player()
	_open_player(duel)
	var seed := _track()
	_expect(duel.finish_seed(seed, Frame.profile()).is_empty()
		and duel.phase == Duel.Phase.ECHO_WAIT and not duel.preparing_seed
		and duel.records.is_empty() and duel.points == PackedInt32Array([0, 0])
		and duel.call_track.is_empty(),
		"A seed must create only the frozen opponent, not scores or an Eco reference.")
	duel.advance(0.59)
	_expect(duel.phase == Duel.Phase.ECHO_WAIT,
		"An echo may not start before the full 600 ms quiet gap.")
	duel.restart_playback()
	duel.advance(0.59)
	_expect(duel.phase == Duel.Phase.ECHO_WAIT,
		"Interrupting the gap must restart all 600 ms.")
	duel.advance(0.01)
	_expect(duel.phase == Duel.Phase.RIVAL and duel.singer == Duel.Singer.RIVAL,
		"The completed seed must become the first rival call, not another player turn.")
	duel.finish_turn(Rivals.score(duel.echo_rival), seed, "Seed echo")
	duel.continue_duel()
	var before := duel.chamber_left
	duel.request_repeat()
	duel.advance(Duel.ECHO_DELAY)
	_expect(duel.phase == Duel.Phase.REPEAT and duel.records.size() == 1,
		"Repeating an echo must retain its delay and never award a second call.")
	duel.finish_repeat()
	duel.advance(900.0)
	_expect(duel.chamber_left == before and duel.phase == Duel.Phase.PLAYER_READY,
		"The Culebra echo must retain untimed open-water rules.")
	var shape := Fixture.shaped()
	_open_player(duel)
	duel.finish_turn(Scorer.score(shape, Frame.profile(), seed), shape, "Remo")
	duel.continue_duel()
	_open_player(duel)
	duel.finish_turn(Scorer.score(shape, Frame.profile()), shape, "Remo")
	duel.continue_duel()
	duel.advance(Duel.ECHO_DELAY)
	duel.finish_turn(Rivals.score(duel.echo_rival, shape), seed, "Seed echo")
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.wins[0] == 2
		and duel.records.size() == 4,
		"Actual shared scores must allow a reachable 2-0 win over the fixed seed.")
	duel.reset(false, Duel.CHAMBER_SECONDS, 3, false, true)
	_expect(duel.preparing_seed and duel.echo_rival.is_empty() and duel.records.is_empty(),
		"Self-echo replay must require a new seed, never reuse the previous call.")
	duel.reset()
	duel.start()
	_expect(not duel.echo_challenge and not duel.preparing_seed
		and duel.phase == Duel.Phase.RIVAL and duel.echo_rival.is_empty(),
		"Ordinary practice must retain its original start and never inherit an echo.")


func _test_echo_snapshot() -> void:
	var frames := _track()
	for frame: Dictionary in frames:
		frame["level"] = 0.3
	var profile := Frame.profile()
	var snapshot := Rivals.echo_rival(frames, profile, true)
	var expected := Scorer.score(frames, profile, [], true)
	frames[0]["cents"] = 900.0
	profile["falsetto_high"] = 1800.0
	var actual := Rivals.score(snapshot)
	_expect(bool(snapshot["valid"]) and float(snapshot["frames"][0]["cents"]) == 0.0
		and float(snapshot["profile"]["falsetto_high"]) == Frame.DEFAULT_FALSETTO_HIGH
		and actual == expected and not bool(actual["power_gated"]),
		"The echo must freeze actual frames, source profile and Quiet Mode together.")
	var invalid := Frame.profile()
	invalid["chest_hz"] = NAN
	_expect(not bool(Rivals.echo_rival(_track(), invalid)["valid"]),
		"A damaged seed profile must fail explicitly instead of becoming another rival.")


func _player_ready(long_windows := false) -> Duel:
	var duel := Duel.new()
	duel.reset(long_windows)
	duel.start()
	_finish(duel, 0.5)
	duel.continue_duel()
	return duel


func _open_player(duel: Duel) -> void:
	_expect(duel.cue_player().is_empty(), "A ready player must be cueable.")
	duel.advance(Duel.TAIL_SECONDS)


func _finish(duel: Duel, value: float) -> void:
	_expect(duel.finish_turn(_result(value, duel.turn == 1), _track(), "fixture").is_empty(),
		"A valid current turn must score exactly once.")


func _track() -> Array[Dictionary]:
	var fixture := Fixture.new()
	fixture.hold(0.2)
	return fixture.frames


func _result(value: float, answering: bool) -> Dictionary:
	return {
		"valid": true, "total": value, "answering": answering, "power_gated": false,
		"marks": {"aliento": value, "quiebre": value, "altura": value,
			"remate": value, "eco": value},
		"evidence": {"breaks": [], "longest_breath": {"seconds": 0.2}},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
