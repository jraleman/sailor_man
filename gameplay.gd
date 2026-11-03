extends GameShell

## One shell round is a skiff, seeded self-echo or two-human practice duel.
## Sources and presentation never decide the winner or bypass the shared scorer.

const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const Rivals = preload("res://games/sailor_man/duel/rival_book.gd")
const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Tone = preload("res://games/sailor_man/audio/remo_tone.gd")
const Cue = preload("res://games/sailor_man/audio/duel_audio.gd")
const CanalAudio = preload("res://games/sailor_man/audio/sailor_audio.gd")
const Calibration = preload("res://games/sailor_man/voice/voice_calibration.gd")
const VoiceRest = preload("res://games/sailor_man/voice/voice_rest.gd")
const Soundcheck = preload("res://games/sailor_man/ui/soundcheck.tscn")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")

@onready var _spike: Control = %ScorerSpike
@onready var _duel_hud: Control = %DuelHud
@onready var _sound_caption: Control = %AudioCaption

var _calls := 0
var _duel := Duel.new()
var _rival := Rivals.practice_rival()
var _rival_tone: Tone
var _cue: Cue
var _canal_audio: CanalAudio
var _rival_frames: Array[Dictionary] = []
var _rival_elapsed := 0.0
var _rival_index := 0
var _phase_seen := -1
var _practice := false
var _echo_challenge := false
var _hot_seat := false
var _use_microphone := false
var _message := ""
var _duel_seconds := 0.0
var voice_profile_path := Calibration.SAVE_PATH
var _voice_profile: Dictionary = {}
var _profile_name := ""
var _profile_error := ""
var _voice_profiles: Dictionary = {}
var _profiles_error := ""
var _seat_profiles := PackedStringArray(["", ""])
var _seat_sources := PackedInt32Array([0, 0])
var _seats_initialized := false
var _seat_index := -1
var _call_profile: Dictionary = {}
var _call_singer := Duel.Singer.RIVAL
var _source_preference: int = Options.InputSource.AUTO
var _soundcheck: Control
var _voice_rest := VoiceRest.new()
var _solo_voice_rest := _voice_rest
var _seat_rest: Array[VoiceRest] = [VoiceRest.new(), VoiceRest.new()]


## Keep the manifest and shell identity on the same stable key.
func game_id() -> String:
	return "sailor_man"


## Pausing disconnects capture rather than scoring audio accumulated in a menu.
func open_pause_menu() -> void:
	_close_soundcheck()
	_spike.call("stop_capture")
	_duel.cancel_player()
	_stop_sounds()
	if _duel.phase in [Duel.Phase.RIVAL, Duel.Phase.REPEAT, Duel.Phase.ECHO_WAIT]:
		_duel.restart_playback()
		if _duel.echo_challenge or _hot_seat:
			_phase_seen = -1
		_rival_elapsed = 0.0
		_rival_index = 0
		_message = "Playback restarts from the same turn. " + _playback_caption()
	super()


func _build_playfield() -> void:
	# A null gameplay music export does not stop a title-screen crossfade.
	AudioManager.stop_music(0.0)
	_spike.connect("score_ready", _on_score_ready)
	_spike.connect("pause_requested", open_pause_menu)
	_spike.connect("finish_requested", _end_round)
	_spike.connect("duel_requested", _return_to_duel)
	_spike.connect("duel_frames_ready", _on_duel_frames)
	_spike.connect("duel_turn_cancelled", _on_turn_cancelled)
	_spike.connect("soundcheck_requested", _open_soundcheck)
	_spike.connect("microphone_failed", _on_microphone_failed)
	_spike.connect("microphone_turn_completed", _on_microphone_turn_completed)
	_duel_hud.connect("action_requested", _on_duel_action)
	_duel_hud.connect("repeat_requested", _on_repeat)
	_duel_hud.connect("echo_requested", _on_echo_requested)
	_duel_hud.connect("source_requested", _on_source_requested)
	_duel_hud.connect("profile_requested", _on_profile_requested)
	_duel_hud.connect("auto_source_requested", _set_input_source.bind(Options.InputSource.AUTO))
	_duel_hud.connect("soundcheck_requested", _open_soundcheck)
	_duel_hud.connect("rest_dismissed", _on_rest_dismissed)
	_duel_hud.connect("rest_remo_requested", _on_rest_remo)
	_duel_hud.connect("practice_requested", _open_practice)
	_duel_hud.connect("pause_requested", open_pause_menu)
	_rival_tone = Tone.new()
	add_child(_rival_tone)
	_cue = Cue.new()
	add_child(_cue)
	_canal_audio = CanalAudio.new()
	_canal_audio.caption_requested.connect(AudioManager.request_caption)
	add_child(_canal_audio)
	_duel_hud.call("mount_audio_caption", _sound_caption)
	_load_voice_profile()


func _set_capture_inset(bottom: float) -> void:
	_duel_hud.offset_bottom = -maxf(bottom, 0.0)
	if _practice:
		_spike.offset_bottom = -maxf(bottom, 0.0)
	if is_instance_valid(_soundcheck):
		_soundcheck.offset_bottom = -maxf(bottom, 0.0)


func _reset_round_state() -> void:
	_close_soundcheck()
	_stop_sounds()
	_spike.call("stop_capture")
	_calls = 0
	_duel_seconds = 0.0
	var arena := Arenas.arena(str(GameSession.selected_level().get("id", Arenas.GATUN)))
	_hot_seat = not _practice and GameSession.player_two_enabled() \
		and not GameSession.player_two_is_cpu()
	_echo_challenge = _echo_challenge and not _practice and not _hot_seat \
		and str(arena["id"]) == Arenas.CULEBRA
	_duel.reset(Settings.tunable_bool(Options.LONG_WINDOWS_KEY),
		Duel.CHAMBER_SECONDS, int(arena["judges"]), bool(arena["clock"]),
		_echo_challenge, _hot_seat)
	_rival = {} if _echo_challenge or _hot_seat else Rivals.practice_rival()
	_call_profile.clear()
	_call_singer = Duel.Singer.RIVAL
	_seat_index = -1
	if _hot_seat and not _seats_initialized:
		_seat_sources.fill(Settings.tunable_choice(Options.INPUT_SOURCE_KEY))
		_seats_initialized = true
	if not _hot_seat:
		_voice_rest = _solo_voice_rest
	_rival_tone.volume_db = Tone.VOLUME_DB - (6.0 if _echo_challenge else 0.0)
	_resolve_source()
	_duel_hud.call("configure_arena", str(arena["id"]))
	_duel_hud.call("set_player_names",
		PackedStringArray([_player_name(PLAYER_ONE), _player_name(PLAYER_TWO)]))
	_duel_hud.call("reset_view")
	_duel_hud.call("show_track", _duel.call_track, _duel.call_track, {},
		_duel.window_seconds, Frame.profile())
	_phase_seen = -1
	_rival_frames = []
	_rival_elapsed = 0.0
	_rival_index = 0
	_spike.call("configure_duel", not _practice, _use_microphone)
	_spike.call("reset_session")
	if _practice:
		_spike.reparent(_hud.get_node("Overlay"))
		_spike.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_duel_hud.call("mount_input", _spike)
	_spike.show()
	_duel_hud.visible = not _practice
	if _echo_challenge or _hot_seat:
		_duel.start()
	_apply_phase()


func _activate_round() -> void:
	pass


func _update_round(delta: float, _time_left: float) -> void:
	if _practice or is_instance_valid(_soundcheck):
		return
	var phase := _duel.phase
	if phase not in [Duel.Phase.READY, Duel.Phase.COMPLETE]:
		_duel_seconds += delta
	_spike.call("advance_duel_input", delta)
	if _duel.phase != Duel.Phase.LISTENING and (
		bool(_spike.get("_recording")) or bool(_spike.get("_remo_active"))
	):
		_spike.call("stop_capture")
	if _duel.phase == phase:
		_duel.advance(delta)
		if _duel.phase == phase:
			if phase in [Duel.Phase.RIVAL, Duel.Phase.REPEAT]:
				_advance_rival(delta)
			elif phase == Duel.Phase.LISTENING and _duel.close_requested:
				_spike.call("finish_duel_turn")
	_apply_phase()


func _finish_round() -> void:
	_close_soundcheck()
	_spike.call("stop_capture")
	_stop_sounds()
	_spike.hide()
	_duel_hud.hide()


func _configure_mode_ui() -> void:
	super()
	if is_instance_valid(_spike):
		_spike.visible = _round_active
	if is_instance_valid(_duel_hud):
		_duel_hud.visible = _round_active and not _practice and _soundcheck == null
	for player in GameSession.player_count():
		var layout := player_stats_panel(player).get_node("Layout")
		(layout.get_node("Stats") as Control).visible = _practice
		(layout.get_node("ScoreCaption") as Label).text = \
			"TOTAL SCORE" if _practice else "JUDGE POINTS"
	(_game_hits_stat.get_parent().get_node("Caption") as Label).text = \
		"TEST CALLS" if _practice else (
			"JUDGE POINTS" if GameSession.player_two_enabled() else "P1 JUDGE POINTS")
	(_game_accuracy_stat.get_parent().get_node("Caption") as Label).text = \
		"CHECKED CALLS" if _practice else (
			"POINTS / MAX" if GameSession.player_two_enabled() else "P1 POINTS / MAX")
	(%RoundInstructions as Label).text = \
		"Aliento, Quiebre, Altura, Remate and Eco. Calls omit Eco." if _practice else \
		"First to two tandas wins; tied tandas go to the answerer."


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if is_instance_valid(_duel_hud):
		_duel_hud.call("set_reduced_motion", value)


func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if is_instance_valid(_duel_hud):
		_duel_hud.call("set_intense_effects", value)


func _on_score_ready(result: Dictionary) -> void:
	if not _practice:
		if _duel.phase != Duel.Phase.LISTENING:
			push_warning("Sailor Man: refused a player score outside a listening turn.")
			return
		if _duel.preparing_seed:
			var seed_error := _duel.finish_seed(_spike.get("_track"),
				_spike.get("_profile"), bool(_spike.get("_quiet")))
			if not seed_error.is_empty():
				_on_turn_cancelled(seed_error)
				return
			_rival = _duel.echo_rival.duplicate(true)
			_apply_phase()
			return
		var error := _duel.finish_turn(
			result, _spike.get("_track"), "Microphone" if _use_microphone else "Remo"
		)
		if not error.is_empty():
			_on_turn_cancelled(error)
			return
		if _hot_seat and _duel.turn == 0:
			_call_profile = (_spike.get("_profile") as Dictionary).duplicate(true)
			_call_singer = _duel.singer
		_scores[PLAYER_ONE] = _duel.points[Duel.Singer.PLAYER]
		_scores[PLAYER_TWO] = _duel.points[Duel.Singer.RIVAL]
		_calls += 1
		if _hot_seat:
			_spike.call("stop_capture")
		_update_scores()
		_apply_phase()
		return
	_calls += 1
	_scores[PLAYER_ONE] = roundi(float(result["total"]) * 100.0)
	_update_scores()


func _round_totals() -> Dictionary:
	if _practice:
		return {"hits": _calls, "attempts": _calls}
	return {"hits": _duel.points[0] + (_duel.points[1] if _hot_seat else 0),
		"attempts": _calls * _duel.judge_count * 10}


func _player_stats(player_index: int) -> Dictionary:
	if _practice:
		return super(player_index)
	var turns := 0
	var best := 0.0
	var breaks := 0
	var breath := 0.0
	var sources := PackedStringArray()
	for record: Dictionary in _duel.records:
		if int(record["singer"]) != player_index:
			continue
		turns += 1
		var result: Dictionary = record["result"]
		best = maxf(best, float(result["total"]))
		breaks += (result["evidence"]["breaks"] as Array).size()
		breath = maxf(breath, float(result["evidence"]["longest_breath"]["seconds"]))
		if str(record["source"]) not in sources:
			sources.append(str(record["source"]))
	var other := 1 - player_index if _hot_seat else PLAYER_TWO
	var other_label := "P1" if _hot_seat and other == PLAYER_ONE else _opponent_label()
	return {
		"score": _scores[player_index],
		"tandas_won": _duel.wins[player_index], "best_turn": best,
		"quiebres": breaks, "longest_breath": breath,
		"source": " / ".join(sources),
		"maximum_judge_points": turns * _duel.judge_count * 10,
		"details": [
			{"label": "Tandas won", "value": str(_duel.wins[player_index])},
			{"label": "Best turn", "value": "%.1f / 100" % (best * 100.0)},
			{"label": "Detected breaks", "value": str(breaks)},
			{"label": "Longest breath", "value": "%.2f s" % breath},
			{"label": "Source", "value": " / ".join(sources)
				if not sources.is_empty() else "No completed turn"},
			{"label": "%s judge points" % other_label, "value": str(_duel.points[other])},
		],
	}


func _round_length_seconds() -> float:
	return super() if _practice else _duel_seconds


func _round_highlight_summary() -> String:
	if _practice:
		return "%d test calls checked. Real-voice validation is still pending." % _calls
	if _hot_seat:
		return "Tandas P1 %d - %d P2 | Best turns: P1 %.1f, P2 %.1f / 100" % [
			_duel.wins[0], _duel.wins[1],
			float(_player_stats(PLAYER_ONE)["best_turn"]) * 100.0,
			float(_player_stats(PLAYER_TWO)["best_turn"]) * 100.0,
		]
	var stats := _player_stats(PLAYER_ONE)
	return "P1 %d - %d %s | Best %.1f/100 | %d breaks | Breath %.2f s | %s" % [
		_duel.wins[0], _duel.wins[1], _opponent_label(), float(stats["best_turn"]) * 100.0,
		int(stats["quiebres"]), float(stats["longest_breath"]), stats["source"],
	]


func _describe_round_outcome(_one: int, _two: int) -> Dictionary:
	if _hot_seat:
		if _duel.winner < 0:
			return {
				"result": "DUEL INCOMPLETE",
				"subtitle": "Stopped before either player won two tandas. No winner awarded.",
				"color": Color("f4b941"),
			}
		return {
			"result": "P%d WINS THE DUEL" % (_duel.winner + 1),
			"subtitle": "Two-human practice. Tandas %d-%d; judges' points %d-%d." % [
				_duel.wins[0], _duel.wins[1], _duel.points[0], _duel.points[1],
			],
			"color": _player_color(_duel.winner),
		}
	if not _practice:
		return {
			"result": "P1 WINS THE DUEL" if _duel.winner == Duel.Singer.PLAYER
				else ("YOUR ECHO WINS" if _duel.echo_challenge else "PRACTICE SKIFF WINS"),
			"subtitle": "Chamber time expired. Retry costs no lives."
				if _duel.reason == "chamber_timeout" else
				"Tandas %d-%d; judges' points %d-%d. %s" % [
					_duel.wins[0], _duel.wins[1], _duel.points[0], _duel.points[1],
					"Your fixed seed contour; neutral tone, not recorded voice."
						if _duel.echo_challenge else "Synthetic development rival.",
				],
			"color": player_one_color if _duel.winner == Duel.Singer.PLAYER
				else player_two_color,
		}
	return {
		"result": "SCORER SESSION",
		"subtitle": "Development scores only. Practice does not affect the duel.",
		"color": Color("f4b941"),
	}


func _on_duel_action() -> void:
	var error := ""
	match _duel.phase:
		Duel.Phase.READY:
			error = _duel.start()
		Duel.Phase.PLAYER_READY:
			if _use_microphone and not bool(_spike.call("microphone_ready")):
				_message = "Enable and check the microphone, or choose Remo."
				_sync_hud()
				return
			error = _duel.cue_player()
		Duel.Phase.REVIEW:
			error = _duel.continue_duel()
		Duel.Phase.COMPLETE:
			_end_round()
			return
		_:
			return
	if not error.is_empty():
		_message = error
	_apply_phase()


func _apply_phase() -> void:
	if _practice:
		return
	if _phase_seen != _duel.phase:
		_phase_seen = _duel.phase
		_stop_sounds()
		match _duel.phase:
			Duel.Phase.READY:
				_message = "One synthetic rival. Remo needs no microphone. First to two tandas."
			Duel.Phase.RIVAL, Duel.Phase.REPEAT:
				if _hot_seat:
					_spike.call("stop_capture")
				_rival_elapsed = 0.0
				_rival_index = 0
				_rival_frames = _duel.call_track if _duel.phase == Duel.Phase.REPEAT \
					else _rival["frames"]
				_message = _playback_caption()
				AudioManager.request_caption(_message)
			Duel.Phase.PLAYER_READY:
				if _hot_seat:
					_activate_seat(_duel.singer)
					_spike.call("reset_session")
				_message = "Make a comfortable seed call. No points; only its fixed pitch "
				_message += "contour returns. Nothing is saved."
				if not _duel.preparing_seed:
					_message = "Your answer: echo the call, then top it." if _duel.turn == 1 \
						else "Your call: make your own shape. Calls do not score Eco."
				if _hot_seat:
					_message = "%s Choose your profile/source, then Ready. "
					_message += "Mic needs explicit Enable."
					_message = _message % (
						"Answer the completed call." if _duel.turn == 1
							else "Make your own call; no Eco points.")
			Duel.Phase.ECHO_WAIT:
				_message = "Your completed seed returns after 600 ms. Input is closed; "
				_message += "only its contour and a neutral tone will play, not recorded voice."
			Duel.Phase.GUARD:
				AudioManager.stop_music(0.0)
				_cue.cue()
				AudioManager.request_caption("Ready cue; wait for YA.")
				_message = "Ready... the scoring window opens after the cue and tail guard."
			Duel.Phase.LISTENING:
				_cue.stop()
				_message = "YA! Your turn. Hold Voice or use a comfortable microphone call."
				if not bool(_spike.call("begin_duel_turn", _duel.call_track)):
					_duel.cancel_player()
					_phase_seen = _duel.phase
					_message = "Input is not ready. Check the microphone or use Remo."
			Duel.Phase.REVIEW:
				var record := _duel.records[-1]
				_show_last_turn()
				_message = "%s %s: %d judge points. %s" % [
					"P1" if int(record["singer"]) == Duel.Singer.PLAYER
						else _opponent_label(),
					"call" if int(record["turn"]) == 0 else "answer",
					record["judgement"]["sum"],
					"Review the paddles, then continue." if _duel.turn == 0
						else _tanda_verdict(),
				]
			Duel.Phase.COMPLETE:
				_spike.call("stop_capture")
				if not _duel.records.is_empty():
					_show_last_turn()
				_message = "Chamber time expired; CPU wins." \
					if _duel.reason == "chamber_timeout" else _tanda_verdict()
		_sync_canal_audio()
		if _duel.phase == Duel.Phase.REVIEW:
			_canal_audio.review("" if _duel.turn == 0 else (
				"P1" if int(_duel.tandas[-1]["winner"]) == Duel.Singer.PLAYER
					else _opponent_label()),
				_duel.uses_chamber_clock)
		elif _duel.phase == Duel.Phase.COMPLETE:
			_canal_audio.complete("P1" if _duel.winner == Duel.Singer.PLAYER
				else _opponent_label(),
				_duel.reason == "chamber_timeout")
	_sync_hud()


func _show_last_turn() -> void:
	var record := _duel.records[-1]
	var reference: Array[Dictionary] = []
	if _duel.turn == 1:
		reference = _duel.call_track
	_duel_hud.call("show_track", _spike.get("_track")
		if _hot_seat or int(record["singer"]) == Duel.Singer.PLAYER else _rival["frames"],
		reference, record["result"]["evidence"], _duel.window_seconds,
		_spike.get("_profile") if _hot_seat or int(record["singer"]) == Duel.Singer.PLAYER
			else _rival["profile"], int(record["singer"]))


func _advance_rival(delta: float) -> void:
	_rival_elapsed += delta
	_rival_index = mini(floori(_rival_elapsed * Frame.RATE_HZ), _rival_frames.size())
	if _rival_index > 0:
		_rival_tone.play_frame(_rival_frames[_rival_index - 1])
	var reference: Array[Dictionary] = []
	if _duel.turn == 1:
		reference = _duel.call_track
	_duel_hud.call("show_track", _rival_frames.slice(0, _rival_index),
		reference, {}, _duel.window_seconds, _reference_profile(),
		_call_singer if _hot_seat else Duel.Singer.RIVAL)
	if _rival_index < _rival_frames.size():
		return
	_rival_tone.stop()
	if _duel.phase == Duel.Phase.REPEAT:
		_duel.finish_repeat()
	else:
		assert(not _hot_seat)
		var result := Rivals.score(_rival, _duel.call_track)
		var error := _duel.finish_turn(result, _rival_frames,
			"Seed echo (neutral tone)" if _duel.echo_challenge else "Synthetic rival")
		if not error.is_empty():
			_message = error
			push_error("Sailor Man rival: %s" % error)
		_scores[PLAYER_TWO] = _duel.points[Duel.Singer.RIVAL]
		_update_scores()


func _on_duel_frames(frames: Array[Dictionary]) -> void:
	if _practice:
		return
	var error := _duel.observe_frames(frames)
	if not error.is_empty():
		_on_turn_cancelled(error)
		return
	elif _duel.silence_closed():
		_spike.call("limit_duel_turn", _duel.accepted_frame_count())
	_duel_hud.call("show_live_track", _spike.get("_track"),
		_duel.window_seconds, _spike.get("_profile"), _duel.singer)


func _on_turn_cancelled(reason: String) -> void:
	if not _practice:
		_duel.cancel_player()
		_phase_seen = _duel.phase
		_message = reason
		_duel_hud.call("show_track", _duel.call_track, _duel.call_track, {},
			_duel.window_seconds, _spike.get("_profile") if _duel.preparing_seed
				else _reference_profile(),
			_call_singer if _hot_seat else Duel.Singer.RIVAL)
		_sync_hud()


func _on_repeat() -> void:
	var error := _duel.request_repeat()
	if not error.is_empty():
		_message = error
	_apply_phase()


func _on_echo_requested() -> void:
	if _practice or _hot_seat \
			or str(GameSession.selected_level().get("id", "")) != Arenas.CULEBRA \
			or not (_duel.phase == Duel.Phase.READY or (
				_duel.preparing_seed and _duel.phase == Duel.Phase.PLAYER_READY)):
		return
	_echo_challenge = not _echo_challenge
	_start_round()


func _on_source_requested(microphone: bool) -> void:
	if _duel.phase not in [Duel.Phase.READY, Duel.Phase.PLAYER_READY]:
		return
	_set_input_source(Options.InputSource.MICROPHONE if microphone else Options.InputSource.REMO)


func _sync_hud() -> void:
	_sync_canal_audio()
	if is_instance_valid(_duel_hud) and not _practice:
		var names := PackedStringArray(_voice_profiles.keys())
		names.sort()
		_duel_hud.call("set_voice_profiles", names, _profile_name)
		_duel_hud.call("present", _duel, _message, _use_microphone,
			bool(_spike.call("microphone_ready")), _source_preference, _source_status(),
			Settings.tunable_bool(Options.REST_REMINDERS_KEY)
				and _voice_rest.is_due(float(Time.get_ticks_msec()) / 1000.0))


func _sync_canal_audio() -> void:
	if not is_instance_valid(_canal_audio):
		return
	var between := _duel.phase in [Duel.Phase.REVIEW, Duel.Phase.PLAYER_READY]
	# Selecting Microphone already protects its room check, before Enable.
	var allowed := _round_active and not _practice and not is_instance_valid(_soundcheck) \
		and not get_tree().paused and _spike.get("_capture") == null \
		and not bool(_spike.get("_recording")) and not bool(_spike.get("_remo_active")) \
		and (_duel.phase == Duel.Phase.COMPLETE or (between and not _use_microphone))
	_canal_audio.set_context(allowed, allowed and between
		and _duel.uses_chamber_clock and _duel.chamber_left > 0.0)


func _load_voice_profile() -> void:
	var loaded := Calibration.load_profiles(voice_profile_path)
	_voice_profiles = loaded["profiles"]
	_profiles_error = str(loaded["error"])
	_profile_error = _profiles_error
	_profile_name = str(loaded["selected"])
	_voice_profile = _voice_profiles.get(_profile_name, {})
	_spike.call("set_voice_profile", _voice_profile)
	_resolve_source()


func _resolve_source() -> void:
	_source_preference = _seat_sources[_seat_index] if _hot_seat and _seat_index >= 0 \
		else Settings.tunable_choice(Options.INPUT_SOURCE_KEY)
	_use_microphone = _source_preference == Options.InputSource.MICROPHONE or (
		_source_preference == Options.InputSource.AUTO and not _voice_profile.is_empty()
		and AudioServer.get_input_device_list().has(str(_voice_profile["device"]))
	)


func _set_input_source(preference: int) -> void:
	if _hot_seat:
		_seat_sources[_seat_index] = preference
		_apply_input_source()
		return
	if Settings.tunable_choice(Options.INPUT_SOURCE_KEY) == preference:
		_apply_input_source()
	else:
		Settings.set_value(Options.INPUT_SOURCE_KEY, preference)


func _activate_seat(player_index: int) -> void:
	if _seat_index == player_index:
		return
	_seat_index = player_index
	_voice_rest = _seat_rest[player_index]
	_apply_seat_profile()


func _apply_seat_profile() -> void:
	_stop_sounds()
	_profile_name = _seat_profiles[_seat_index]
	_profile_error = _profiles_error
	_voice_profile = (_voice_profiles.get(_profile_name, {}) as Dictionary).duplicate(true)
	if not _profile_name.is_empty() and _voice_profile.is_empty():
		_profile_error = "That player's voice profile is unavailable. Choose another or use Remo."
	var error: String = _spike.call("set_voice_profile", _voice_profile)
	if not error.is_empty():
		_profile_error = error
		_voice_profile = {}
		_spike.call("set_voice_profile", {})
	_resolve_source()
	_spike.call("configure_duel", true, _use_microphone)


func _on_profile_requested(name: String) -> void:
	if not _hot_seat or _duel.phase != Duel.Phase.PLAYER_READY:
		return
	if not name.is_empty() and not _voice_profiles.has(name):
		_message = "That voice profile is unavailable. Choose another or use Remo."
		push_warning("Sailor Man hot seat: %s" % _message)
		_sync_hud()
		return
	_seat_profiles[_seat_index] = name
	_apply_seat_profile()
	_message = "P%d profile: %s. The microphone stays off until explicitly enabled." % [
		_seat_index + 1, name if not name.is_empty() else "none; Remo is ready",
	]
	_sync_hud()


func _apply_input_source() -> void:
	_stop_sounds()
	_spike.call("stop_capture")
	_duel.cancel_player()
	_resolve_source()
	_spike.call("configure_duel", not _practice, _use_microphone)
	_message = "Microphone remains off until you explicitly enable it or complete Soundcheck." \
		if _use_microphone else \
		"Remo uses keys, gamepad or the touch ribbon. No microphone is open."
	_apply_phase()


func _source_status() -> String:
	var status := "%s -> %s" % [
		Options.INPUT_SOURCE_TITLES[_source_preference],
		"Microphone" if _use_microphone else "Remo",
	]
	if not _profile_error.is_empty():
		return status + " | " + _profile_error
	if _voice_profile.is_empty():
		return status + " | No voice profile. Soundcheck is optional; Remo works immediately."
	if not AudioServer.get_input_device_list().has(str(_voice_profile["device"])):
		return status + " | Profile device unavailable. Check Soundcheck, or use Remo."
	return status + " | Profile: " + _profile_name + " | Mic %s" % (
		"enabled" if bool(_spike.call("microphone_ready")) else "off until enabled")


func _open_soundcheck() -> void:
	if _practice or is_instance_valid(_soundcheck) \
			or _duel.phase not in [Duel.Phase.READY, Duel.Phase.PLAYER_READY]:
		return
	_spike.call("stop_capture")
	_stop_sounds()
	AudioManager.stop_music(0.0)
	_spike.process_mode = Node.PROCESS_MODE_DISABLED
	_duel_hud.hide()
	_soundcheck = Soundcheck.instantiate()
	_soundcheck.set("profile_path", voice_profile_path)
	if _hot_seat:
		_soundcheck.set("seat_tag", "P%d" % (_seat_index + 1))
		_soundcheck.set("selected_profile_name", _profile_name)
	_soundcheck.connect("completed", _on_soundcheck_completed)
	_soundcheck.connect("cancelled", _on_soundcheck_cancelled)
	_soundcheck.connect("remo_requested", _on_soundcheck_remo)
	_hud.get_node("Overlay").add_child(_soundcheck)


func _close_soundcheck() -> void:
	if not is_instance_valid(_soundcheck):
		return
	var wizard := _soundcheck
	_soundcheck = null
	wizard.set("_closing", true)
	wizard.call("_stop_capture")
	wizard.process_mode = Node.PROCESS_MODE_DISABLED
	wizard.hide()
	wizard.queue_free()
	_spike.process_mode = Node.PROCESS_MODE_INHERIT
	_duel_hud.visible = _round_active and not _practice
	_duel_hud.call_deferred("focus_ready_action")


func _on_soundcheck_completed(profile: Dictionary, capture: Node) -> void:
	_voice_profile = profile.duplicate()
	_profile_error = ""
	var loaded := Calibration.load_profiles(voice_profile_path)
	_voice_profiles = loaded["profiles"]
	_profiles_error = str(loaded["error"])
	_profile_error = _profiles_error
	_profile_name = str(loaded["selected"])
	if _hot_seat:
		_seat_profiles[_seat_index] = _profile_name
		if _seat_sources[_seat_index] == Options.InputSource.REMO:
			_seat_sources[_seat_index] = Options.InputSource.MICROPHONE
		_resolve_source()
		_spike.call("configure_duel", true, _use_microphone)
	elif Settings.tunable_choice(Options.INPUT_SOURCE_KEY) == Options.InputSource.REMO:
		Settings.set_value(Options.INPUT_SOURCE_KEY, Options.InputSource.MICROPHONE)
	else:
		_resolve_source()
		_spike.call("configure_duel", true, _use_microphone)
	var error: String = _spike.call("adopt_capture", capture, profile)
	if not error.is_empty():
		if is_instance_valid(capture):
			capture.call("stop")
			capture.queue_free()
		_close_soundcheck()
		_message = error
		_sync_hud()
		return
	_close_soundcheck()
	_message = "Voice profile ready. Use a comfortable voice, or choose Remo."
	_sync_hud()


func _on_soundcheck_cancelled() -> void:
	_close_soundcheck()
	_message = "Soundcheck cancelled. The earlier saved profile is unchanged."
	_sync_hud()


func _on_soundcheck_remo() -> void:
	_close_soundcheck()
	_set_input_source(Options.InputSource.REMO)


func _on_microphone_failed(reason: String) -> void:
	if not _practice and _source_preference == Options.InputSource.AUTO:
		_use_microphone = false
		_spike.call("configure_duel", not _practice, false)
		_message = reason + " Auto selected Remo; no microphone is open."
		_sync_hud()


func _on_microphone_turn_completed(voiced: bool) -> void:
	_voice_rest.record_turn(float(Time.get_ticks_msec()) / 1000.0, voiced)
	_sync_hud()


func _on_rest_dismissed() -> void:
	_voice_rest.dismiss()
	_sync_hud()


func _on_rest_remo() -> void:
	_voice_rest.dismiss()
	_set_input_source(Options.InputSource.REMO)


func _tanda_verdict() -> String:
	var last := _duel.tandas[-1]
	return "%s takes tanda %d (%d-%d). Tandas P1 %d - %d %s." % [
		"P1" if int(last["winner"]) == Duel.Singer.PLAYER else _opponent_label(),
		_duel.tanda, last["call_points"], last["answer_points"],
		_duel.wins[0], _duel.wins[1], _opponent_label(),
	]


func _opponent_label() -> String:
	return "P2" if _hot_seat else ("ECHO" if _duel.echo_challenge else "CPU")


func _reference_profile() -> Dictionary:
	if _hot_seat:
		return _call_profile if not _call_profile.is_empty() else Frame.profile()
	return _rival["profile"]


func _playback_caption() -> String:
	if _hot_seat:
		return "P%d's completed call: pitch contour and neutral tone, not recorded voice." % (
			_call_singer + 1)
	return str(_rival["caption"])


func _open_practice() -> void:
	if _hot_seat:
		return
	_echo_challenge = false
	_practice = true
	_start_round()


func _return_to_duel() -> void:
	_echo_challenge = false
	_practice = false
	_start_round()


func _stop_sounds() -> void:
	if is_instance_valid(_rival_tone):
		_rival_tone.stop()
	if is_instance_valid(_cue):
		_cue.stop()
	if is_instance_valid(_canal_audio):
		_canal_audio.stop()
	if is_instance_valid(_sound_caption):
		_sound_caption.call("clear")


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == Options.INPUT_SOURCE_KEY:
		_close_soundcheck()
		if _hot_seat:
			_seat_sources[_seat_index] = Settings.tunable_choice(Options.INPUT_SOURCE_KEY)
		_apply_input_source()
		return
	if key == Options.REST_REMINDERS_KEY:
		_sync_hud()
		return
	if _practice:
		return
	if key in [Options.LONG_WINDOWS_KEY, Options.QUIET_MODE_KEY, Options.MIC_SENSITIVITY_KEY]:
		_close_soundcheck()
		_spike.call("stop_capture")
		_duel.cancel_player()
		_duel.window_seconds = Duel.LONG_WINDOW if Settings.tunable_bool(
			Options.LONG_WINDOWS_KEY) else Duel.NORMAL_WINDOW
		_apply_phase()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_stop_sounds()
	if (
		what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready()
		and _round_active and not _practice
		and _duel.phase != Duel.Phase.COMPLETE
		and (_duel.phase != Duel.Phase.READY or _spike.get("_capture") != null
			or _soundcheck != null)
	):
		open_pause_menu()


func _exit_tree() -> void:
	_close_soundcheck()
	_stop_sounds()
