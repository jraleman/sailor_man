extends SceneTree

## Real input, source admission and shell results exercise complete duels without
## opening hardware. Native runs also guard the actual GL arena and touch layouts.

const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const CanalAudio = preload("res://games/sailor_man/audio/sailor_audio.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const Judges = preload("res://games/sailor_man/duel/judges.gd")
const Rivals = preload("res://games/sailor_man/duel/rival_book.gd")
const Calibration = preload("res://games/sailor_man/voice/voice_calibration.gd")
const Identity = preload("res://scripts/player_identity.gd")
const LOW_PROFILE := "Low voice"
const HIGH_PROFILE := "High voice - comfortable profile for P2"

## A checked PCM queue substitutes only for the hardware, not the voice pipeline.
class BufferedCapture extends Node:
	signal calibrated(noise_floor: float)
	signal capture_failed(reason: String)

	var discarded := false
	var stopped := false
	var pending := PackedVector2Array()
	var starts := 0

	func start(_device: String) -> void:
		starts += 1

	func is_ready() -> bool:
		return true

	func discard() -> void:
		discarded = true
		pending = PackedVector2Array()

	func poll() -> PackedVector2Array:
		var result := pending
		pending = PackedVector2Array()
		return result

	func stop() -> void:
		stopped = true
		pending = PackedVector2Array()

var _failures := PackedStringArray()
var _captions := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameCatalog.select(Options.GAME_ID)
	var session := get_root().get_node("GameSession")
	session.call("configure_single_player")
	session.call("set_level", Arenas.GATUN)
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values["ui/scale"] = 1.0
	values[Settings.AUDIO_CAPTIONS_KEY] = true
	for option: Dictionary in Options.TUNABLES:
		values[option["key"]] = option["default"]
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		values[binding["key"]] = binding["default"]
	settings.set("_values", values)
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	var packed := load("res://games/sailor_man/gameplay.tscn") as PackedScene
	if packed == null:
		printerr("Sailor Man duel could not load.")
		quit(1)
		return
	var buses := AudioServer.bus_count
	var manager := get_root().get_node("AudioManager")
	manager.connect("caption_requested", func(text: String) -> void: _captions.append(text))
	manager.call("play_music", CanalAudio.make_stream(CanalAudio.Sound.WATER), 10.0)
	var game := packed.instantiate()
	game.set("voice_profile_path", "user://sailor_duel_scene_unwritten_%d.cfg"
		% OS.get_process_id())
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	var spike := game.get_node("%ScorerSpike") as Control
	var hud := game.get_node("%DuelHud") as Control
	_expect(spike.get("_capture") == null and AudioServer.bus_count == buses,
		"Entering a duel must not request microphone access or create a capture bus.")
	_expect(not bool(manager.call("is_music_playing")),
		"The duel must stop even an incoming menu-music crossfade before microphone setup.")
	_test_canal_state(game, hud)
	_test_audio_policy(game, spike)
	_test_remo_win(game, spike, hud)
	await process_frame
	_test_pause_and_guard(game, spike)
	await process_frame
	_test_microphone_loss(game, spike)
	_test_missing_audio(game, spike)
	_test_buffered_silence(game, spike)
	await process_frame
	_test_practice_return(game, spike, hud)
	await _test_arenas(game, spike, hud)
	await _test_self_echo(game, spike, hud)
	await _test_echo_layouts(game, spike, hud)
	await _test_layouts(game, spike, hud)
	game.queue_free()
	await process_frame
	await process_frame
	await _test_hot_seat(packed)
	# Mixer cleanup is asynchronous; fast headless frames do not drain playback.
	await create_timer(0.1, true, false, true).timeout
	_expect(AudioServer.bus_count == buses, "Leaving the duel must release every owned bus.")
	settings.set("_values", original)
	settings.call("save")
	get_root().min_size = old_minimum
	get_root().size = old_size
	settings.call("_update_content_scale")
	settings.call("apply_controls")
	if _failures.is_empty():
		print("Sailor duel scene tests passed (%s)." % DisplayServer.get_name())
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_hot_seat(packed: PackedScene) -> void:
	var session := get_root().get_node("GameSession")
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	values["ui/scale"] = 1.0
	values[Options.INPUT_SOURCE_KEY] = Options.InputSource.AUTO
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	var setup := (load("res://scenes/menus/mode_select.tscn") as PackedScene).instantiate()
	get_root().add_child(setup)
	await process_frame
	(setup.get("_multiplayer_button") as Button).pressed.emit()
	var picker := setup.get("_level_choice") as OptionButton
	_expect(int(setup.get("_pending_mode")) == 1
		and (setup.get("_human_option_button") as Button).button_pressed
		and picker.item_count == Arenas.ENTRIES.size(),
		"The shared setup must offer a two-human hot seat, not another synthetic-rival mode.")
	for index in picker.item_count:
		picker.select(index)
		picker.item_selected.emit(index)
		_expect(not picker.is_item_disabled(index),
			"Every current practice arena must remain available for hot seat.")
	setup.queue_free()
	await process_frame
	session.call("configure_multiplayer", 0)
	session.call("set_level", Arenas.GATUN)
	var instructions := (load("res://scenes/menus/instructions.tscn") as PackedScene).instantiate()
	get_root().add_child(instructions)
	await process_frame
	_expect(bool(session.call("takes_turns"))
		and (instructions.get("_summary") as Label).text.contains("Two humans")
		and (instructions.get("_opponent_controls") as Label).text.contains("same keyboard"),
		"The real briefing must describe alternating human turns and shared controls.")
	instructions.queue_free()
	await process_frame
	var path := "user://sailor_hot_seat_scene_%d.cfg" % OS.get_process_id()
	var low := _hot_seat_profile(160.0, true)
	var high := _hot_seat_profile(280.0, false)
	_expect(Calibration.save_profile(LOW_PROFILE, low, path).is_empty()
		and Calibration.save_profile(HIGH_PROFILE, high, path).is_empty(),
		"The isolated hot-seat profiles must be valid scalar calibrations.")
	var game := packed.instantiate()
	game.set("voice_profile_path", path)
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	var spike := game.get_node("%ScorerSpike") as Control
	var hud := game.get_node("%DuelHud") as Control
	var duel: Duel = game.get("_duel")
	var canal: Control = hud.get("lock")
	for arena: Dictionary in Arenas.ENTRIES:
		session.call("set_level", str(arena["id"]))
		game.call("_return_to_duel")
		var before := duel.chamber_left
		_tick(game, 900.0)
		_expect(duel.hot_seat and not duel.uses_chamber_clock
			and duel.phase == Duel.Phase.PLAYER_READY and duel.records.is_empty()
			and duel.singer == Duel.Singer.PLAYER and duel.chamber_left == before
			and duel.judge_count == int(arena["judges"]) and spike.get("_capture") == null
			and (game.get("_rival") as Dictionary).is_empty()
			and not (hud.get_node("%EchoChallenge") as Button).visible
			and (hud.get("_clock") as Label).text.contains("Hot seat - no chamber deadline"),
			"Every hot-seat arena must wait for actual P1/P2 input, without a clock or fake rival.")
		_expect((canal.get("boats")[1].get("plaque") as Label3D).text == "P2"
			and (hud.get("_judges")[0] as Label).text.contains("/ P2"),
			"The real second boat and numbered paddles must identify P2, never CPU or ECHO.")
	session.call("set_level", Arenas.GATUN)
	game.call("_return_to_duel")
	game.call("_on_source_requested", false)
	_open_player(game)
	_draw_call(game)
	var reference := duel.call_track.duplicate(true)
	game.call("_on_duel_action")
	_expect(duel.singer == Duel.Singer.RIVAL and (spike.get("_track") as Array).is_empty()
		and (hud.get("_turn") as Label).text.contains("Player 2 (P2)")
		and (hud.get("_turn") as Label).get_theme_color("font_color") == Identity.color(1),
		"The handoff must name/tint P2 and remove P1's input track from the new input lane.")
	_open_player(game)
	_send_key(KEY_SPACE)
	_tick(game, 0.2)
	game.call("open_pause_menu")
	_expect(paused and duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1
		and duel.call_track == reference and duel.points[1] == 0
		and (spike.get("_track") as Array).is_empty(),
		"Pausing P2's partial answer must discard only that input, never P1's completed call.")
	(game.get("_pause_menu") as Node).call("resume")
	_send_key(KEY_SPACE, false)
	game.call("_on_repeat")
	_tick(game, 0.2)
	_expect(duel.phase == Duel.Phase.REPEAT and int(canal.get("_track_singer")) == 0
		and duel.records.size() == 1 and not bool(spike.get("_duel_turn_open"))
		and (game.get("_rival_tone") as AudioStreamPlayer).playing,
		"P2's repeat must play P1's completed contour from P1's boat, with input closed.")
	game.call("open_pause_menu")
	(game.get("_pause_menu") as Node).call("resume")
	var before_caption := _captions.size()
	_tick(game, 0.0)
	_tick(game, 6.0)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.singer == Duel.Singer.RIVAL
		and duel.records.size() == 1 and duel.call_track == reference and duel.repeat_used
		and _captions.slice(before_caption).has(str(game.call("_playback_caption"))),
		"Interrupted hot-seat playback must restart/reannounce the same free, unscored call.")
	_open_player(game)
	_draw_weak_call(game)
	_expect(duel.records.size() == 2 and int(duel.records[-1]["singer"]) == 1,
		"The recovered answer must be scored as actual P2 input.")
	_test_hot_seat_win(game, spike, hud, 0)
	_test_hot_seat_win(game, spike, hud, 1)
	session.call("set_level", Arenas.PACIFIC)
	_test_hot_seat_win(game, spike, hud, 0)
	_expect(duel.judge_count == 5,
		"Pacific hot seat must also settle actual two-human performances with all five judges.")
	session.call("set_level", Arenas.GATUN)
	game.call("_on_play_again_pressed")
	await _test_hot_seat_profiles(game, spike, hud, path, low, high)
	await _test_hot_seat_layouts(game, spike, hud)
	game.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	session.call("configure_single_player")
	session.call("set_level", Arenas.GATUN)


func _test_hot_seat_win(game: Node, spike: Control, hud: Control, winner: int) -> void:
	game.call("_on_play_again_pressed")
	var duel: Duel = game.get("_duel")
	for singer: int in [0, 1, 1, 0]:
		_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.singer == singer,
			"Hot-seat matches must admit P1 call/P2 answer, then P2 call/P1 answer.")
		game.call("_on_source_requested", false)
		_open_player(game)
		if singer == winner:
			_draw_call(game)
		else:
			_draw_weak_call(game)
		_expect((duel.records[-1]["judgement"]["paddles"] as Array).size() == duel.judge_count,
			"Each actual human performance must count every arena judge, not just their labels.")
		if duel.phase == Duel.Phase.REVIEW:
			game.call("_on_duel_action")
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.winner == winner
		and duel.wins[winner] == 2 and duel.records.size() == 4
		and int(game.get("_calls")) == 4,
		"Either human must be able to win 2-0 through actual input, not injected scores.")
	var totals: Dictionary = game.call("_round_totals")
	for singer in 2:
		var stats: Dictionary = game.call("_player_stats", singer)
		_expect(int(stats["maximum_judge_points"]) == duel.judge_count * 20
			and str(stats["source"]) == "Remo"
			and int(stats["score"]) == duel.points[singer],
			"Each human's statistics must count only their own two actual performances.")
	_expect(int(totals["attempts"]) == duel.judge_count * 40
		and int(totals["hits"]) == duel.points[0] + duel.points[1],
		"Combined statistics must count both humans without doubling either player's maximum.")
	game.call("_on_duel_action")
	var panels: Array = game.get("_player_ui")
	_expect((game.get_node("%ResultLabel") as Label).text.contains("P%d WINS" % (winner + 1))
		and (panels[1]["result_card"] as Control).visible and not hud.visible
		and (game.get("_round_player_two_score") as Label).text == str(duel.points[1]),
		"Both real winners and P2's real score must reach the shared shell results.")
	game.call("_on_play_again_pressed")
	_expect(duel.hot_seat and duel.records.is_empty() and duel.call_track.is_empty()
		and (game.get("_rival_frames") as Array).is_empty() and spike.get("_capture") == null
		and duel.phase == Duel.Phase.PLAYER_READY and duel.singer == Duel.Singer.PLAYER,
		"A hot-seat rematch must reset both scores/tracks without opening a microphone.")


func _test_hot_seat_profiles(
	game: Node, spike: Control, hud: Control, path: String, low: Dictionary, high: Dictionary
) -> void:
	var stored := FileAccess.get_file_as_bytes(path)
	var settings := get_root().get_node("Settings")
	var preference := int(settings.call("tunable_choice", Options.INPUT_SOURCE_KEY))
	_select_seat_profile(hud, LOW_PROFILE)
	(hud.get_node("%UseMicrophone") as Button).pressed.emit()
	var capture := _checked_capture(spike)
	game.call("_sync_hud")
	_open_player(game)
	capture.pending = _pcm(0.9, 160.0)
	_tick(game, 0.9)
	spike.call("finish_duel_turn")
	var duel: Duel = game.get("_duel")
	var reference := duel.call_track.duplicate(true)
	var profile: Dictionary = (game.get("_call_profile") as Dictionary).duplicate(true)
	_expect(duel.records.size() == 1 and capture.stopped and spike.get("_capture") == null
		and is_equal_approx(float(profile["chest_hz"]), 160.0),
		"P1's real PCM must use P1's calibration and disconnect before the human handoff.")
	game.call("_on_duel_action")
	_expect((spike.get("_human_profile") as Dictionary).is_empty()
		and str(game.get("_profile_name")).is_empty(),
		"P2 must explicitly choose a profile, not silently inherit P1's voice calibration.")
	game.call("_open_soundcheck")
	var wizard := game.get("_soundcheck") as Control
	await process_frame
	_expect(wizard.get("seat_tag") == "P2" and (wizard.get("_name") as LineEdit).text == "P2"
		and (wizard.get("_names") as OptionButton).selected == -1
		and (wizard.get("_use_saved") as Button).disabled and wizard.get("_capture") == null,
		"New P2 Soundcheck must identify P2, not preselect or overwrite P1's profile.")
	wizard.call("_cancel")
	_select_seat_profile(hud, HIGH_PROFILE)
	(hud.get_node("%UseMicrophone") as Button).pressed.emit()
	game.call("_on_duel_action")
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1
		and duel.call_track == reference and bool((hud.get("primary") as Button).disabled),
		"Profile/source selection must never open hardware or bypass explicit Enable.")
	capture = _checked_capture(spike)
	capture.pending = _pcm(0.1, 280.0)
	game.call("_on_repeat")
	_tick(game, 0.2)
	var canal: Control = hud.get("lock")
	var ribbon: Node3D = canal.get("ribbon")
	_expect(capture.stopped and spike.get("_capture") == null
		and int(canal.get("_track_singer")) == 0
		and is_equal_approx(float(ribbon.get("_profile")["chest_hz"]), 160.0)
		and game.get("_call_profile") == profile and duel.records.size() == 1,
		"Even after choosing P2's profile, Repeat must close capture and retain P1's source band.")
	_tick(game, 6.0)
	capture = _checked_capture(spike)
	_open_player(game)
	capture.pending = _pcm(0.9, 280.0)
	_tick(game, 0.9)
	spike.call("finish_duel_turn")
	var frames: Array[Dictionary] = spike.get("_track")
	var voiced := 0
	var deviation := 0.0
	for frame: Dictionary in frames:
		if bool(frame["voiced"]):
			voiced += 1
			deviation = maxf(deviation, absf(float(frame["cents"])))
	var rests: Array = game.get("_seat_rest")
	_expect(duel.records.size() == 2 and int(duel.records[-1]["singer"]) == 1
		and voiced >= 60 and deviation < 40.0
		and is_equal_approx(float(spike.get("_profile")["chest_hz"]), 280.0)
		and not bool(spike.get("_profile")["falsetto_calibrated"])
		and duel.call_track == reference and game.get("_call_profile") == profile,
		"P2's different-frequency PCM must normalize through P2's own unmeasured human profile.")
	_expect((rests[0].get("_turns") as Array).size() == 1
		and (rests[1].get("_turns") as Array).size() == 1
		and FileAccess.get_file_as_bytes(path) == stored
		and int(settings.call("tunable_choice", Options.INPUT_SOURCE_KEY)) == preference,
		"Voice-rest counts and card choices must stay per seat, without saving tracks or defaults.")
	game.call("_on_duel_action")
	(hud.get_node("%UseRemo") as Button).pressed.emit()
	_open_player(game)
	_draw_call(game)
	_expect(bool(spike.get("_profile")["falsetto_calibrated"])
		and not bool(spike.get("_human_profile")["falsetto_calibrated"])
		and is_equal_approx(float(spike.get("_human_profile")["chest_hz"]), 280.0),
		"P2 may switch to Remo's authored range without rewriting their human calibration.")
	game.call("_on_duel_action")
	_expect(str(game.get("_profile_name")) == LOW_PROFILE and bool(game.get("_use_microphone"))
		and spike.get("_capture") == null and spike.get("_human_profile") == low,
		"Returning to P1 must restore P1's profile/source, but never reactivate their microphone.")
	game.call("_open_soundcheck")
	wizard = game.get("_soundcheck") as Control
	await process_frame
	_expect((wizard.get("_name") as LineEdit).text == LOW_PROFILE,
		"Existing-seat Soundcheck must select that seat's profile, not the file's last selection.")
	(wizard.get("_use_saved") as Button).pressed.emit()
	_expect(game.get("_soundcheck") == null and spike.get("_capture") == null
		and (game.get("_seat_profiles") as PackedStringArray)
			== PackedStringArray([LOW_PROFILE, HIGH_PROFILE])
		and Calibration.load_profiles(path)["profiles"][HIGH_PROFILE] == high,
		"Using a saved profile must update only its seat and leave the other calibration intact.")
	for _turn in 5:
		rests[0].call("record_turn", float(Time.get_ticks_msec()) / 1000.0, true)
	game.call("_on_play_again_pressed")
	_expect((hud.get("_rest_offer") as Control).visible,
		"A singer's own completed microphone turns must carry a rest offer into their next duel.")
	var p2_source := int(game.get("_seat_sources")[1])
	(hud.get_node("%RestUseRemo") as Button).pressed.emit()
	_expect(not bool(game.get("_use_microphone"))
		and int(game.get("_seat_sources")[1]) == p2_source
		and int(settings.call("tunable_choice", Options.INPUT_SOURCE_KEY)) == preference,
		"P1's rest choice must not change P2's input preference or the saved solo default.")
	_open_player(game)
	_draw_call(game)
	reference = duel.call_track.duplicate(true)
	profile = (game.get("_call_profile") as Dictionary).duplicate(true)
	game.call("_on_duel_action")
	game.call("_open_soundcheck")
	wizard = game.get("_soundcheck") as Control
	await process_frame
	wizard.set_process(false)
	(wizard.get("_name") as LineEdit).text = "Fresh P2"
	capture = BufferedCapture.new()
	wizard.call("_begin_capture", capture)
	var capture_parent := capture.get_parent()
	capture.calibrated.emit(0.002)
	_soundcheck_take(wizard, capture)
	_soundcheck_take(wizard, capture)
	wizard.call("_skip_high")
	_soundcheck_take(wizard, capture)
	_expect(wizard.get("_model").step == Calibration.Step.COMPLETE
		and duel.records.size() == 1 and duel.call_track == reference
		and (rests[1].get("_turns") as Array).size() == 1,
		"P2's fresh Soundcheck must be unscored and preserve P1's completed reference.")
	(wizard.get("_save") as Button).pressed.emit()
	await process_frame
	await process_frame
	var saved := Calibration.load_profiles(path)
	_expect(game.get("_soundcheck") == null and spike.get("_capture") == capture
		and not capture.stopped and capture.starts == 1 and capture.get_parent() == capture_parent
		and (game.get("_seat_profiles") as PackedStringArray)
			== PackedStringArray([LOW_PROFILE, "Fresh P2"])
		and int(game.get("_seat_sources")[0]) == Options.InputSource.REMO
		and int(game.get("_seat_sources")[1]) == Options.InputSource.MICROPHONE
		and saved["profiles"][LOW_PROFILE] == low and saved["profiles"][HIGH_PROFILE] == high
		and absf(float(saved["profiles"]["Fresh P2"]["chest_hz"]) - 280.0) < 2.0
		and int(settings.call("tunable_choice", Options.INPUT_SOURCE_KEY)) == preference
		and duel.call_track == reference and game.get("_call_profile") == profile,
		"Explicit P2 Save must adopt live capture without reparent/restart or changing P1/defaults.")
	_open_player(game)
	capture.pending = _pcm(0.9, 280.0)
	_tick(game, 0.9)
	spike.call("finish_duel_turn")
	_expect(duel.records.size() == 2 and int(duel.records[-1]["singer"]) == 1
		and capture.stopped and spike.get("_capture") == null,
		"The adopted P2 capture must score only P2's next actual turn and close at its handoff.")
	game.call("_on_duel_action")
	_select_seat_profile(hud, HIGH_PROFILE)


func _soundcheck_take(wizard: Control, capture: BufferedCapture) -> void:
	wizard.call("_toggle_take")
	capture.pending = _pcm(0.9, 280.0)
	wizard.call("_process", 0.1)
	wizard.call("_toggle_take")
	var slices := 0
	while bool(wizard.get("_recording")) and slices < 1000:
		wizard.call("_process", 0.01)
		slices += 1
	_expect(slices < 1000, "A fresh human Soundcheck take must drain its bounded analysis.")


func _test_hot_seat_layouts(game: Node, spike: Control, hud: Control) -> void:
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	var duel: Duel = game.get("_duel")
	for size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720),
			Vector2i(2560, 1080)]:
		for scale: float in [1.0, 1.5]:
			game.call("_on_play_again_pressed")
			values["ui/scale"] = scale
			get_root().min_size = Vector2i.ZERO
			get_root().size = size
			settings.call("_update_content_scale")
			settings.emit_signal("changed", "ui/scale", scale)
			for singer in 2:
				(hud.get_node("%UseRemo") as Button).pressed.emit()
				for _frame in 6:
					await process_frame
				var transform := get_root().get_final_transform()
				var window := Rect2(Vector2.ZERO, Vector2(size))
				var title := hud.get("_turn") as Label
				_expect(title.is_visible_in_tree() and window.encloses(transform * title.get_global_rect())
					and title.text.contains("P%d" % (singer + 1))
					and title.text.contains("PASS THE MIC")
					and title.get_theme_color("font_color") == Identity.color(singer),
					"Each responsive handoff must visibly name and colour its numbered singer.")
				var primary := hud.get("primary") as Button
				var scroll := hud.get("_scroll") as ScrollContainer
				_expect(window.encloses(transform * primary.get_global_rect())
					and scroll.get_global_rect().grow(1.0).encloses(primary.get_global_rect()),
					"P%d Ready %s must fit %s at %s / %.1f UI (scroll=%d, focus=%s)."
					% [singer + 1, primary.get_global_rect(), scroll.get_global_rect(), size,
						scale, scroll.scroll_vertical, get_root().gui_get_focus_owner()])
				var choice := hud.get_node("%SeatVoiceProfile") as OptionButton
				scroll.ensure_control_visible(choice)
				for _frame in 3:
					await process_frame
				_expect(choice.is_visible_in_tree()
					and window.encloses(transform * choice.get_global_rect()),
					"Each singer's calibration choice must remain reachable inside the phone scroller.")
				scroll.ensure_control_visible(hud.get("primary"))
				for _frame in 3:
					await process_frame
				if DisplayServer.get_name() != "headless":
					_capture("hot-seat-p%d-ready-%dx%d-ui%.1f.png" % [
						singer + 1, size.x, size.y, scale])
				_open_player(game)
				_send_key(KEY_SPACE)
				_tick(game, 0.3)
				_send_key(KEY_SPACE, false)
				for _frame in 6:
					await process_frame
				var ribbon := spike.get_node("%VoiceRibbon") as Control
				var button := spike.get_node("%RemoBreak") as Button
				for control: Control in [ribbon, button, hud.get_node("%PauseDuel")]:
					_expect(control.is_visible_in_tree()
						and window.encloses(transform * control.get_global_rect()),
						"P%d input must fit %s at UI %.1f: %s" % [
							singer + 1, size, scale, control.name])
				var canal: Control = hud.get("lock")
				_expect(int(canal.get("_track_singer")) == singer
					and title.text.contains("P%d" % (singer + 1)),
					"Live input/ribbon geometry must belong to the actual numbered singer.")
				if DisplayServer.get_name() != "headless":
					_capture("hot-seat-p%d-live-%dx%d-ui%.1f.png" % [
						singer + 1, size.x, size.y, scale])
				if singer == 1 and size == Vector2i(320, 568) and scale == 1.5:
					_test_duel_touch(game, spike, ribbon, button)
				elif singer == 1 and size == Vector2i(1280, 720) and scale == 1.0:
					_test_duel_gamepad(game)
				else:
					_draw_call(game)
				_expect(duel.phase == Duel.Phase.REVIEW
					and int(duel.records[-1]["singer"]) == singer,
					"Every responsive input path must score the active human, never a placeholder.")
				for _frame in 3:
					await process_frame
				if DisplayServer.get_name() != "headless":
					_capture("hot-seat-p%d-review-%dx%d-ui%.1f.png" % [
						singer + 1, size.x, size.y, scale])
				if singer == 0:
					game.call("_on_duel_action")


func _select_seat_profile(hud: Control, name: String) -> void:
	var choice := hud.get_node("%SeatVoiceProfile") as OptionButton
	for index in choice.item_count:
		if choice.get_item_text(index) == name:
			choice.select(index)
			choice.item_selected.emit(index)
			return
	_expect(false, "The hot-seat card must offer the requested named profile.")


func _hot_seat_profile(chest: float, measured: bool) -> Dictionary:
	var profile := Frame.profile(chest, measured)
	profile.merge({"noise_floor": 0.003, "speak_level": 0.04, "carry_level": 0.12,
		"device": "Default"}, true)
	return profile


func _draw_weak_call(game: Node) -> void:
	_send_key(KEY_SPACE)
	_tick(game, 0.5)
	_send_key(KEY_K)
	_tick(game, 0.12)
	_send_key(KEY_K, false)
	_send_key(KEY_SPACE, false)


func _test_arenas(game: Node, spike: Control, hud: Control) -> void:
	var session := get_root().get_node("GameSession")
	var setup := (load("res://scenes/menus/mode_select.tscn") as PackedScene).instantiate()
	get_root().add_child(setup)
	await process_frame
	await process_frame
	var picker := setup.get("_level_choice") as OptionButton
	_expect(picker != null and picker.item_count == Arenas.ENTRIES.size(),
		"The real shared setup must offer all five practice arenas.")
	if picker == null:
		setup.queue_free()
		return
	for index in picker.item_count:
		picker.select(index)
		picker.item_selected.emit(index)
		var selected: Dictionary = session.call("selected_level")
		_expect(not picker.is_item_disabled(index) and picker.get_item_icon(index) != null
			and str(selected["id"]) == str(Arenas.ENTRIES[index]["id"]),
			"Every free arena must be selectable through setup, with its rendered icon.")
	setup.queue_free()
	await process_frame
	await process_frame
	var canal: Control = hud.get("lock")
	for arena: Dictionary in Arenas.ENTRIES:
		session.call("set_level", str(arena["id"]))
		game.call("_return_to_duel")
		game.call("_on_source_requested", false)
		var duel: Duel = game.get("_duel")
		var clocked := bool(arena["clock"])
		_expect(spike.get("_capture") == null
			and str(canal.get("_arena")["id"]) == str(arena["id"])
			and duel.uses_chamber_clock == clocked and duel.judge_count == int(arena["judges"])
			and (hud.get_node("%CanalCaption") as Label).text == str(arena["caption"]),
			"Shared selection must configure the real view, rule panel and caption without a mic.")
		_expect((hud.get_node("%EchoChallenge") as Button).visible
			== (str(arena["id"]) == Arenas.CULEBRA),
			"Only Culebra's ready card may offer the optional self-echo challenge.")
		game.call("_on_duel_action")
		_tick(game, 3.73)
		var audio := game.get("_canal_audio") as Node
		var water := audio.get_node("FillingWater") as AudioStreamPlayer
		_expect(duel.phase == Duel.Phase.REVIEW and water.playing == clocked
			and (audio.get_node("PaddleClack") as AudioStreamPlayer).playing,
			"Open water must keep verdict feedback without a false filling-water loop.")
		var chamber: Node3D = canal.get("chamber")
		var surface: MeshInstance3D = chamber.get("water")
		var initial_height := surface.position.y
		var before := duel.chamber_left
		_tick(game, 120.0 if clocked else 900.0)
		if clocked:
			var direction := -1.0 if bool(arena["descending"]) else 1.0
			_expect((surface.position.y - initial_height) * direction > 0.4,
				"Real lock time must raise Gatun and lower Pedro Miguel, not reverse the rules.")
			_tick(game, 121.0)
			_expect(duel.reason == "chamber_timeout" and duel.winner == Duel.Singer.RIVAL,
				"Both practice locks must retain their authoritative chamber deadline.")
		else:
			_expect(duel.phase == Duel.Phase.REVIEW and duel.chamber_left == before
				and is_equal_approx(surface.position.y, initial_height)
				and not chamber.has_node("ChamberAndMulas") and not chamber.has_node("TowLines")
				and (hud.get("_clock") as Label).text.contains("no chamber deadline"),
				"Open water must be untimed, level, visibly labelled and free of ghost lock walls.")
			game.call("_on_duel_action")
			game.call("_on_repeat")
			_expect(_canal_silent(game), "Even a free Repeat must silence canal effects.")
			_tick(game, 900.0)
			_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1
				and duel.chamber_left == before and duel.repeat_used
				and (hud.get("repeat") as Button).disabled,
				"Open-water Repeat must be free, once-only playback, never another score.")
			if str(arena["id"]) == Arenas.LAKE:
				_test_lake_drift(game, canal, duel)
			_open_player(game)
			_draw_call(game)
			var paddles: Array = duel.records[-1]["judgement"]["paddles"]
			var labels: Array = hud.get("_judges")
			var judged: Dictionary = Judges.evaluate(
				duel.records[-1]["result"], int(arena["judges"]))
			var totals: Dictionary = game.call("_round_totals")
			_expect(duel.wins[0] == 1 and paddles.size() == int(arena["judges"])
				and labels.size() == paddles.size() and duel.points[0] == int(judged["sum"])
				and int(totals["attempts"]) == paddles.size() * 10
				and not (audio.get_node("MulaBell") as AudioStreamPlayer).playing
				and (audio.get_node("Applause") as AudioStreamPlayer).playing,
				"Real Remo must score/display every Pacific judge, correct maxima and no lock bell.")
			for index in labels.size():
				_expect((labels[index] as Label).is_visible_in_tree()
					and (labels[index] as Label).text.contains("P1 %s" % paddles[index]["points"]),
					"Every actual judge paddle must reach a labelled HUD row.")
		game.call("_return_to_duel")
		if str(arena["id"]) == Arenas.PACIFIC:
			_test_remo_win(game, spike, hud)
		_expect(str(canal.get("_arena")["id"]) == str(arena["id"])
			and duel.judge_count == int(arena["judges"]) and duel.records.is_empty(),
			"Replay, including five-judge shell results, must keep the arena but clear results.")
	session.call("set_level", Arenas.GATUN)
	game.call("_return_to_duel")


func _test_self_echo(game: Node, spike: Control, hud: Control) -> void:
	var session := get_root().get_node("GameSession")
	session.call("set_level", Arenas.CULEBRA)
	game.call("_return_to_duel")
	game.call("_on_source_requested", false)
	var echo := hud.get_node("%EchoChallenge") as Button
	echo.pressed.emit()
	var duel: Duel = game.get("_duel")
	_expect(duel.echo_challenge and duel.preparing_seed and duel.records.is_empty()
		and spike.get("_capture") == null and (game.get("_rival") as Dictionary).is_empty()
		and (hud.get("_turn") as Label).text.contains("UNSCORED"),
		"Choosing self-echo must ask for an unscored seed without opening a microphone.")
	_open_player(game)
	_tick(game, 0.2)
	spike.call("finish_duel_turn")
	_expect(duel.preparing_seed and duel.phase == Duel.Phase.PLAYER_READY
		and duel.echo_rival.is_empty() and int(game.get("_calls")) == 0
		and str(game.get("_message")).contains("voiced seed"),
		"A silent seed must fail visibly and remain retryable without a score or opponent.")
	_open_player(game)
	_send_key(KEY_SPACE)
	_tick(game, 0.2)
	game.call("open_pause_menu")
	_expect(paused and duel.preparing_seed and duel.echo_rival.is_empty()
		and (spike.get("_track") as Array).is_empty() and duel.records.is_empty(),
		"Pausing a partial seed must discard it, not silently establish an opponent.")
	(game.get("_pause_menu") as Node).call("resume")
	_send_key(KEY_SPACE, false)
	game.call("_on_source_requested", true)
	_checked_capture(spike)
	_open_player(game)
	_tick(game, 4.0)
	_expect(duel.preparing_seed and duel.echo_rival.is_empty()
		and spike.get("_capture") == null and str(game.get("_message")).contains("No microphone"),
		"Missing seed PCM must remain a capture error, never a zero-scoring seed.")
	var capture := _checked_capture(spike)
	_open_player(game)
	capture.pending = _pcm(0.7)
	_tick(game, 0.7)
	(spike.get_node("%RecordCall") as Button).pressed.emit()
	var seed: Array[Dictionary] = (spike.get("_track") as Array[Dictionary]).duplicate(true)
	var profile: Dictionary = (spike.get("_profile") as Dictionary).duplicate(true)
	var snapshot: Dictionary = (game.get("_rival") as Dictionary).duplicate(true)
	_expect(duel.phase == Duel.Phase.ECHO_WAIT and not duel.preparing_seed
		and duel.echo_rival["frames"] == seed and snapshot["profile"] == profile
		and not bool(profile["falsetto_calibrated"]) and duel.records.is_empty()
		and int(game.get("_calls")) == 0 and not bool(spike.get("_duel_turn_open"))
		and not (game.get("_rival_tone") as AudioStreamPlayer).playing
		and _canal_silent(game),
		"Real buffered PCM must create only a frozen source-relative seed and a quiet gap.")
	capture.pending = _pcm(0.1)
	_tick(game, 0.3)
	_expect(capture.pending.is_empty() and spike.get("_track") == seed
		and game.get("_rival") == snapshot and duel.phase == Duel.Phase.ECHO_WAIT,
		"Idle mic buffers must be discarded, not monitored or appended to the fixed echo.")
	game.call("open_pause_menu")
	_expect(capture.stopped and spike.get("_capture") == null,
		"Pausing the echo gap must release microphone capture.")
	(game.get("_pause_menu") as Node).call("resume")
	_tick(game, 0.59)
	_expect(duel.phase == Duel.Phase.ECHO_WAIT
		and not (game.get("_rival_tone") as AudioStreamPlayer).playing,
		"Resuming must retain all 600 ms of silence before any echo playback.")
	_tick(game, 0.01)
	_tick(game, 0.2)
	var tone := game.get("_rival_tone") as AudioStreamPlayer
	var frame: Dictionary = seed[int(game.get("_rival_index")) - 1]
	_expect(duel.phase == Duel.Phase.RIVAL and int(game.get("_rival_index")) > 0
		and not bool(spike.get("_duel_turn_open")) and game.get("_rival") == snapshot
		and tone.playing == bool(frame["voiced"])
		and tone.volume_db < (spike.get("_remo_tone") as AudioStreamPlayer).volume_db,
		"Only completed snapshot frames may play; rival playback must never reopen input.")
	game.call("open_pause_menu")
	_expect(duel.phase == Duel.Phase.ECHO_WAIT
		and not (game.get("_rival_tone") as AudioStreamPlayer).playing,
		"Interrupting a returning echo must stop its tone and restart the quiet delay.")
	(game.get("_pause_menu") as Node).call("resume")
	var captions_before := _captions.size()
	_play_echo(game)
	_expect(duel.phase == Duel.Phase.REVIEW and duel.records.size() == 1
		and int(duel.records[0]["judgement"]["sum"])
			== int(Judges.evaluate(Rivals.score(snapshot))["sum"])
		and duel.call_track == seed and game.get("_rival") == snapshot
		and _captions.slice(captions_before).has(str(snapshot["caption"])),
		"The echo's actual first call must be scored from the frozen seed, not a skiff take.")
	game.call("_on_duel_action")
	game.call("_on_repeat")
	_tick(game, 0.59)
	_expect(duel.phase == Duel.Phase.ECHO_WAIT and duel.repeat_used
		and duel.records.size() == 1,
		"Even a free echo Repeat must wait 600 ms and cannot score.")
	_tick(game, 0.01)
	_tick(game, float(seed.size()) * Frame.STEP_SECONDS + 0.01)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1,
		"Echo Repeat must return to the same guarded answer.")
	game.call("_on_source_requested", false)
	_open_player(game)
	_draw_call(game)
	game.call("_on_duel_action")
	_open_player(game)
	_draw_call(game)
	game.call("_on_duel_action")
	_play_echo(game)
	var canal: Control = hud.get("lock")
	var boats: Array = canal.get("boats")
	var stats: Dictionary = game.call("_player_stats", 0)
	var totals: Dictionary = game.call("_round_totals")
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.wins[0] == 2
		and duel.records.size() == 4 and int(game.get("_calls")) == 2
		and int(totals["attempts"]) == 60 and str(stats["source"]) == "Remo"
		and duel.echo_rival["frames"] == seed and game.get("_rival") == snapshot,
		"A real Remo win must beat the unchanged mic seed; the seed cannot inflate results.")
	_expect((boats[1].get("plaque") as Label3D).text == "ECHO"
		and (hud.get("_clock") as Label).text.contains("ECHO")
		and (hud.get("_judges")[0] as Label).text.contains("/ ECHO")
		and str(game.call("_round_highlight_summary")).contains("ECHO"),
		"The boat, panel and result evidence must identify the echo, not a fictitious CPU crew.")
	game.call("_on_duel_action")
	_expect((game.get_node("%RoundOver") as Control).visible and not hud.visible
		and (game.get_node("%ResultLabel") as Label).text.contains("P1 WINS"),
		"Winning the self-echo challenge must reach the actual shell results.")
	game.call("_on_play_again_pressed")
	_expect(duel.echo_challenge and duel.preparing_seed and duel.echo_rival.is_empty()
		and (game.get("_rival") as Dictionary).is_empty() and duel.records.is_empty()
		and (game.get("_rival_frames") as Array).is_empty() and spike.get("_capture") == null,
		"Echo replay must keep the challenge but discard every previous seed/playback track.")
	game.call("_on_source_requested", false)
	_open_player(game)
	_draw_seed(game)
	_expect(bool(game.get("_rival")["profile"]["falsetto_calibrated"])
		and game.get("_rival")["frames"] != seed,
		"A new Remo seed must replace the old mic snapshot, not borrow its profile or samples.")
	_play_echo(game)
	game.call("_on_duel_action")
	for _tanda in 2:
		_open_player(game)
		_tick(game, 0.2)
		spike.call("finish_duel_turn")
		game.call("_on_duel_action")
		if duel.phase == Duel.Phase.ECHO_WAIT:
			_play_echo(game)
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.winner == Duel.Singer.RIVAL,
		"Actual silent duel turns must remain valid losses, unlike an invalid silent seed.")
	game.call("_on_duel_action")
	_expect((game.get_node("%ResultLabel") as Label).text.contains("ECHO WINS"),
		"An echo win must not be mislabeled as the practice skiff in shell results.")
	game.call("_on_play_again_pressed")
	echo.pressed.emit()
	_expect(not duel.echo_challenge and duel.phase == Duel.Phase.READY
		and str(game.get("_rival")["id"]) == "synthetic_skiff"
		and (boats[1].get("plaque") as Label3D).text == "CPU",
		"Skiff practice must remain a separate usable choice without the old seed.")
	session.call("set_level", Arenas.GATUN)
	game.call("_return_to_duel")
	await process_frame


func _test_echo_layouts(game: Node, spike: Control, hud: Control) -> void:
	var session := get_root().get_node("GameSession")
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	session.call("set_level", Arenas.CULEBRA)
	for size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720),
			Vector2i(2560, 1080)]:
		for scale: float in [1.0, 1.5]:
			game.call("_return_to_duel")
			values["ui/scale"] = scale
			get_root().min_size = Vector2i.ZERO
			get_root().size = size
			settings.call("_update_content_scale")
			settings.emit_signal("changed", "ui/scale", scale)
			(hud.get_node("%EchoChallenge") as Button).pressed.emit()
			for _frame in 6:
				await process_frame
			var primary := hud.get("primary") as Button
			(hud.get("_scroll") as ScrollContainer).ensure_control_visible(primary)
			for _frame in 3:
				await process_frame
			var transform := get_root().get_final_transform()
			var window := Rect2(Vector2.ZERO, Vector2(size))
			_expect(primary.is_visible_in_tree()
				and window.encloses(transform * primary.get_global_rect()),
				"The unscored-seed action must remain reachable at %s / %.1f UI." % [size, scale])
			if DisplayServer.get_name() != "headless":
				_capture("echo-ready-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
			_open_player(game)
			for _frame in 6:
				await process_frame
			for control in [spike.get_node("%VoiceRibbon"), spike.get_node("%RemoBreak"),
					hud.get_node("%PauseDuel")]:
				_expect(window.encloses(transform * (control as Control).get_global_rect()),
					"Seed input must remain in bounds at %s / %.1f UI: %s." % [
						size, scale, control.name])
			_expect((hud.get("_turn") as Label).text.contains("SEED"),
				"Listening must visibly distinguish the unscored seed from a tanda.")
			_draw_call(game)
			_play_echo(game)
			for _frame in 3:
				await process_frame
			if DisplayServer.get_name() != "headless":
				_assert_arena(hud, true)
				_capture("echo-review-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
	session.call("set_level", Arenas.GATUN)
	game.call("_return_to_duel")


func _draw_seed(game: Node) -> void:
	_send_key(KEY_SPACE)
	_tick(game, 0.4)
	_send_key(KEY_K)
	_tick(game, 0.12)
	_send_key(KEY_K, false)
	_send_key(KEY_SPACE, false)


func _play_echo(game: Node) -> void:
	var duel: Duel = game.get("_duel")
	_expect(duel.phase == Duel.Phase.ECHO_WAIT,
		"Every echo must begin with its quiet delay, including retries and repeats.")
	_tick(game, Duel.ECHO_DELAY)
	var frames: Array = game.get("_rival")["frames"]
	_tick(game, float(frames.size()) * Frame.STEP_SECONDS + 0.01)


func _test_lake_drift(game: Node, canal: Control, duel: Duel) -> void:
	var ribbon: Node3D = canal.get("ribbon")
	var boats: Array = canal.get("boats")
	var mouth: Node3D = boats[1].get("mouth")
	var points: PackedVector3Array = ribbon.get("points")
	var offset := ribbon.to_global(points[0]) - mouth.global_position
	var track := duel.call_track.duplicate(true)
	var reduced := bool(game.get("_reduced_motion_enabled"))
	game.call("_set_reduced_motion_enabled", false)
	canal.call("_process", 5.0)
	_expect((ribbon.to_global(points[0]) - mouth.global_position).distance_to(offset) < 0.02
		and duel.call_track == track,
		"A drifting lake rival must carry its contour with it, without moving scored samples.")
	game.call("_set_reduced_motion_enabled", true)
	_expect(not canal.is_processing() and is_zero_approx((boats[1] as Node3D).position.z)
		and (ribbon.to_global(points[0]) - mouth.global_position).distance_to(offset) < 0.02,
		"Reduced motion must immediately park lake drift while preserving the attached contour.")
	game.call("_set_reduced_motion_enabled", reduced)


func _test_audio_policy(game: Node, spike: Control) -> void:
	var audio := game.get("_canal_audio") as Node
	var water := audio.get_node("FillingWater") as AudioStreamPlayer
	_expect(_canal_silent(game), "Ready must not start decorative canal audio.")
	game.call("_on_duel_action")
	_tick(game, 0.5)
	_expect(_canal_silent(game) and _captions[-1].contains("Synthetic rival"),
		"Reference playback needs its shape caption, never competing canal effects.")
	var sfx := AudioServer.get_bus_index("SFX")
	var muted := AudioServer.is_bus_mute(sfx)
	AudioServer.set_bus_mute(sfx, true)
	var count := _captions.size()
	_tick(game, 3.23)
	_expect(water.playing and (audio.get_node("PaddleClack") as AudioStreamPlayer).playing
		and _captions.size() == count + 1 and _captions[-1].contains("judges"),
		"A real review must play owned effects and one caption, even with muted SFX.")
	var caption := game.get_node("%AudioCaption") as Control
	_expect(caption.is_visible_in_tree()
		and str(caption.call("caption_text")).contains("judges"),
		"The caption must really be visible outside the shell's hidden default margins.")
	AudioServer.set_bus_mute(sfx, muted)
	count = _captions.size()
	game.call("_apply_phase")
	_tick(game, 0.1)
	_expect(_captions.size() == count, "Refreshing a review must not replay its verdict.")
	game.call("_on_duel_action")
	game.call("_on_source_requested", true)
	_expect(_canal_silent(game) and spike.get("_capture") == null,
		"Selecting Microphone must silence canal audio before explicit room measurement.")
	_expect(not caption.is_visible_in_tree(),
		"Source setup must also clear the old transient verdict caption.")
	game.call("_on_source_requested", false)
	_expect(water.playing and _captions.size() == count,
		"Returning to Remo can restore water, but cannot repeat a scored verdict.")
	game.call("_open_soundcheck")
	_tick(game, 90.0)
	_expect(_canal_silent(game),
		"Soundcheck must stop water immediately and keep it stopped while suspended.")
	game.call("_on_soundcheck_cancelled")
	game.call("open_pause_menu")
	_expect(paused and _canal_silent(game), "Pause must stop every owned canal effect.")
	var pause := game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	_tick(game, 0.0)
	_expect(water.playing and _captions.size() == count,
		"Resume may restore the between-turn wash without replaying judge cues.")
	game.call("_on_duel_action")
	_expect(_canal_silent(game) and _captions[-1].contains("Ready cue"),
		"The protected cue must be alone before any admitted frames.")
	_tick(game, 0.25)
	var turn := game.get_node("%DuelHud").get("_turn") as Label
	_expect(_canal_silent(game) and turn.is_visible_in_tree() and turn.text.begins_with("YA!")
		and not caption.is_visible_in_tree(),
		"The persistent YA header must replace the transient cue, leaving input room clear.")
	spike.call("stop_capture")
	var duel: Duel = game.get("_duel")
	duel.chamber_left = 0.01
	_tick(game, 0.02)
	_expect(duel.phase == Duel.Phase.COMPLETE
		and (audio.get_node("LockHorn") as AudioStreamPlayer).playing
		and not (audio.get_node("PaddleClack") as AudioStreamPlayer).playing
		and _captions[-1].contains("time is up"),
		"An actual chamber timeout must sound its horn without inventing a scored paddle.")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.call("_apply_phase")
	_expect(_canal_silent(game) and not paused,
		"Focus loss must stop final feedback too, without replaying it on refresh.")
	game.call("_return_to_duel")
	_expect(_canal_silent(game), "Replay must stop final feedback instead of carrying it over.")


func _test_remo_win(game: Node, spike: Control, hud: Control) -> void:
	var duel: Duel = game.get("_duel")
	_first_answer(game)
	var view: Control = hud.get("lock")
	var ribbon: Node3D = view.get("ribbon")
	var rival: Dictionary = game.get("_rival")
	_expect(ribbon.get("_profile") == rival["profile"],
		"Rival presentation must retain its authored source profile, not a human fallback.")
	var count := duel.records.size()
	game.call("_on_repeat")
	_expect(_canal_silent(game),
		"Repeating the scored reference must stop the between-turn water and review effects.")
	_tick(game, 3.73)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.repeat_used
		and duel.records.size() == count,
		"Repeat must play the reference without another scored rival turn.")
	_open_player(game)
	_draw_call(game)
	_expect(duel.wins[0] == 1 and duel.phase == Duel.Phase.REVIEW,
		"A real, reachable Remo answer must beat the synthetic rival.")
	_expect(not bool(spike.get("_duel_turn_open"))
		and not (spike.get("_remo_tone") as AudioStreamPlayer).playing,
		"A scored player turn must close admission and stop its preview.")
	game.call("_on_duel_action")
	_expect(duel.tanda == 2 and duel.call_track.is_empty(),
		"The second tanda must start with an independent player call.")
	_open_player(game)
	_draw_call(game)
	game.call("_on_duel_action")
	_tick(game, 3.73)
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.wins[0] == 2
		and duel.records.size() == 4 and hud.visible,
		"Two won tandas must show the final verdict without a spurious third tanda.")
	var audio := game.get("_canal_audio") as Node
	_expect((audio.get_node("LockHorn") as AudioStreamPlayer).playing
		and not (audio.get_node("FillingWater") as AudioStreamPlayer).playing
		and _captions[-1].contains("P1 wins the duel"),
		"A judged duel win must announce the real winner once, with the water stopped.")
	var stats: Dictionary = game.call("_player_stats", 0)
	_expect(int(stats["tandas_won"]) == 2 and float(stats["best_turn"]) > 0.8
		and int(stats["quiebres"]) >= 6 and float(stats["longest_breath"]) > 4.5
		and str(stats["source"]) == "Remo",
		"Duel results must derive tandas, marks, breaks, breath and source from real turns.")
	game.call("_on_duel_action")
	_expect((game.get_node("%RoundOver") as Control).visible and not hud.visible
		and (game.get_node("%ResultLabel") as Label).text.contains("P1 WINS"),
		"Winning the duel must hand off to the real shell results.")
	_expect(_canal_silent(game), "Shell results must stop owned final feedback.")
	var report: Control = game.call("player_stats_panel", 0)
	_expect(report.has_node("Layout/ExtraStats")
		and not (report.get_node("Layout/Stats") as Control).visible,
		"Game-specific evidence must not be mislabeled as generic hits and streaks.")
	_expect(float(game.call("_round_length_seconds")) > 10.0,
		"Duel statistics must include the elapsed performances and repeat.")
	game.call("_on_play_again_pressed")
	var plot := hud.get("_rival_ribbon") as Control
	_expect(duel.phase == Duel.Phase.READY and duel.records.is_empty()
		and duel.call_track.is_empty() and hud.visible and spike.get("_capture") == null
		and (plot.get("_frames") as Array).is_empty()
		and (plot.get("_reference") as Array).is_empty(),
		"Shell replay must reset the entire duel without reopening hardware.")
	_expect(is_zero_approx(float(game.call("_round_length_seconds"))),
		"Replay must reset elapsed duel time, not carry it into the next result.")
	var canal: Control = hud.get("lock")
	var world_ribbon: Node3D = canal.get("ribbon")
	var points: PackedVector3Array = world_ribbon.get("points")
	_expect(points.is_empty() and canal.get("_focus") == Vector3.ZERO,
		"Replay must also clear the world contour and park its previous singer framing.")


func _test_pause_and_guard(game: Node, spike: Control) -> void:
	game.call("_on_duel_action")
	_tick(game, 0.5)
	var elapsed := float(game.call("_round_length_seconds"))
	game.call("open_pause_menu")
	_expect(paused and is_equal_approx(float(game.call("_round_length_seconds")), elapsed)
		and is_zero_approx(float(game.get("_rival_elapsed"))),
		"Pausing rival playback must restart its take without erasing elapsed duel time.")
	var pause := game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	game.call("_return_to_duel")
	_first_answer(game)
	var duel: Duel = game.get("_duel")
	var reference := duel.call_track.duplicate(true)
	game.call("_on_duel_action")
	_tick(game, 0.24)
	_send_key(KEY_SPACE)
	spike.call("_start_remo")
	_expect(duel.phase == Duel.Phase.GUARD and not bool(spike.get("_remo_active")),
		"Neither raw input nor the practice API may start a turn during the tail guard.")
	_send_key(KEY_SPACE, false)
	_tick(game, 0.01)
	spike.call("_toggle_recording")
	_expect(bool(spike.get("_remo_active")) and duel.phase == Duel.Phase.LISTENING
		and spike.get("_capture") == null,
		"The mic shortcut must not replace an admitted Remo turn.")
	_send_key(KEY_SPACE)
	_tick(game, 0.3)
	var canal: Control = game.get_node("%DuelHud").get("lock")
	var world_ribbon: Node3D = canal.get("ribbon")
	var live_points: PackedVector3Array = world_ribbon.get("points")
	_expect(live_points.size() == (spike.get("_track") as Array).size()
		and canal.get("_track_singer") == Duel.Singer.PLAYER,
		"The live world ribbon must use the admitted player track, not a rival or prediction.")
	var count := duel.records.size()
	game.call("open_pause_menu")
	_expect(paused and duel.phase == Duel.Phase.PLAYER_READY
		and duel.records.size() == count and duel.call_track == reference
		and not bool(spike.get("_remo_active"))
		and not (game.get("_rival_tone") as AudioStreamPlayer).playing,
		"Pause must discard a partial player turn while keeping the same answer and reference.")
	_expect(world_ribbon.get("_frames") == reference
		and canal.get("_track_singer") == Duel.Singer.RIVAL,
		"Cancelling a partial take must restore the scored reference in the world too.")
	pause = game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	_send_key(KEY_SPACE, false)
	_open_player(game)
	_send_key(KEY_SPACE)
	_tick(game, 0.2)
	spike.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == count,
		"Losing focus must never submit a partial Remo turn.")
	_send_key(KEY_SPACE, false)
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	var old_binding := int(values[Options.VOICE_KEY])
	values[Options.VOICE_KEY] = KEY_Z
	settings.emit_signal("changed", Options.VOICE_KEY, KEY_Z)
	_open_player(game)
	_send_key(KEY_SPACE)
	_tick(game, 0.1)
	var track: Array = spike.get("_track")
	_expect(not bool(track[-1]["voiced"]), "Old bindings must not voice a duel turn.")
	_send_key(KEY_SPACE, false)
	_send_key(KEY_Z)
	_tick(game, 0.2)
	track = spike.get("_track")
	_expect(bool(track[-1]["voiced"]), "The current bound key must voice the real duel input.")
	values[Options.VOICE_KEY] = old_binding
	settings.emit_signal("changed", Options.VOICE_KEY, old_binding)
	_send_key(KEY_Z, false)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == count
		and duel.call_track == reference,
		"Rebinding during a turn must retry without scoring or replacing its call.")


func _test_microphone_loss(game: Node, spike: Control) -> void:
	game.call("_return_to_duel")
	game.call("_on_source_requested", true)
	_expect(spike.get("_capture") == null,
		"Selecting Microphone must not itself open a physical device.")
	var capture := _checked_capture(spike)
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(paused and capture.stopped and spike.get("_capture") == null,
		"Losing focus during microphone setup must release capture and pause too.")
	var pause := game.get("_pause_menu") as Node
	if pause != null:
		pause.call("resume")
	capture = _checked_capture(spike)
	capture.pending = _pcm(0.7)
	_first_answer(game)
	_expect(_canal_silent(game),
		"Microphone setup must keep canal feedback off even after a real rival review.")
	_expect((spike.get("_track") as Array).is_empty() and capture.pending.is_empty(),
		"Rival playback and idle buffers must be discarded, not scored as a player call.")
	_open_player(game)
	spike.call("_start_remo")
	_expect(capture.discarded and not bool(spike.get("_profile")["falsetto_calibrated"]),
		"Mic admission must discard cue audio and restore an unmeasured human profile.")
	_expect(bool(spike.get("_recording")) and not bool(spike.get("_remo_active"))
		and spike.get("_capture") == capture,
		"The Remo API must not replace an admitted microphone turn.")
	capture.pending = _pcm(1.0)
	_tick(game, 1.0)
	(spike.get_node("%RecordCall") as Button).pressed.emit()
	var duel: Duel = game.get("_duel")
	_expect(duel.wins[1] == 1 and duel.records.size() == 2,
		"A real, weak microphone answer must lose on its actual scored evidence.")
	game.call("_on_duel_action")
	_open_player(game)
	capture.pending = _pcm(1.0)
	_tick(game, 1.0)
	(spike.get_node("%RecordCall") as Button).pressed.emit()
	game.call("_on_duel_action")
	_tick(game, 3.73)
	_expect(duel.phase == Duel.Phase.COMPLETE and duel.winner == Duel.Singer.RIVAL,
		"Both microphone turns must complete a real losing duel through the same judges.")
	_expect(capture.stopped and spike.get("_capture") == null
		and _captions[-1].contains("CPU wins the duel"),
		"Final feedback may sound only after microphone capture has actually stopped.")
	game.call("_on_duel_action")
	_expect((game.get_node("%ResultLabel") as Label).text.contains("SKIFF WINS")
		and capture.stopped and spike.get("_capture") == null,
		"Defeat must use shell results and release capture, without losing lives.")


func _test_missing_audio(game: Node, spike: Control) -> void:
	game.call("_on_play_again_pressed")
	game.call("_on_source_requested", true)
	_checked_capture(spike)
	_first_answer(game)
	_open_player(game)
	var duel: Duel = game.get("_duel")
	var reference := duel.call_track.duplicate(true)
	_tick(game, 4.0)
	_expect(duel.phase == Duel.Phase.PLAYER_READY and duel.records.size() == 1
		and duel.call_track == reference and spike.get("_capture") == null
		and str(game.get("_message")).contains("No microphone audio"),
		"Missing PCM must retry the same answer with an explicit error, never minimum paddles.")


func _test_buffered_silence(game: Node, spike: Control) -> void:
	var capture := _checked_capture(spike)
	_open_player(game)
	capture.pending = _pcm(0.5)
	var silence := PackedVector2Array()
	silence.resize(roundi(AudioServer.get_mix_rate() * 1.4))
	capture.pending.append_array(silence)
	capture.pending.append_array(_pcm(1.0))
	_tick(game, 2.9)
	var duel: Duel = game.get("_duel")
	var track: Array = spike.get("_track")
	_expect(duel.phase == Duel.Phase.REVIEW and not track.is_empty()
		and float(track[-1]["t"]) < 2.0
		and float(duel.records[-1]["result"]["evidence"]["longest_breath"]["seconds"]) < 0.7,
		"Audio buffered after 1.2 seconds of real silence must not enter the scored turn.")


func _test_practice_return(game: Node, spike: Control, hud: Control) -> void:
	game.call("_return_to_duel")
	game.call("_on_source_requested", true)
	game.call("_open_practice")
	_expect(not hud.visible and not bool(spike.get("_duel_mode")),
		"Practice must retain the full original workbench.")
	_expect(_canal_silent(game), "The scorer workbench must not inherit duel ambience.")
	var start := spike.get_node("%StartRemo") as Button
	var quiebre := spike.get_node("%RemoBreak") as Button
	var remate := spike.get_node("%RemoFinish") as Button
	_expect(start.is_visible_in_tree() and not start.disabled
		and quiebre.is_visible_in_tree() and remate.is_visible_in_tree(),
		"Practice after microphone setup must restore visible, usable Remo controls.")
	spike.call("load_example", true)
	_expect(int(game.get("_calls")) == 1, "Practice fixtures must still exercise the scorer.")
	start.pressed.emit()
	_send_key(KEY_SPACE)
	spike.call("_process", 0.5)
	quiebre.pressed.emit()
	spike.call("_process", 0.04)
	spike.call("_process", 0.2)
	remate.pressed.emit()
	spike.call("_process", 0.12)
	_send_key(KEY_SPACE, false)
	_expect(int(game.get("_calls")) == 2 and bool(spike.get("_last_result")["valid"])
		and (spike.get("_last_result")["evidence"]["breaks"] as Array).size() == 1,
		"Restored Practice buttons must still make a scored Remo call.")
	(spike.get_node("%BackToDuel") as Button).pressed.emit()
	var duel: Duel = game.get("_duel")
	_expect(hud.visible and bool(spike.get("_duel_mode")) and duel.records.is_empty()
		and duel.phase == Duel.Phase.READY,
		"Returning from Practice must reset admission and all duel-local results.")
	game.call("_on_source_requested", false)


func _test_canal_state(game: Node, hud: Control) -> void:
	var canal: Control = hud.get("lock")
	var camera: Camera3D = canal.get("camera")
	var chamber: Node3D = canal.get("chamber")
	var water: MeshInstance3D = chamber.get("water")
	var boats: Array = canal.get("boats")
	var reduced := bool(game.get("_reduced_motion_enabled"))
	var intense := bool(game.get("_intense_effects_enabled"))
	game.call("_set_reduced_motion_enabled", false)
	canal.call("present", 0.0, Duel.Singer.RIVAL)
	canal.call("_process", 0.7)
	var moving := camera.transform
	game.call("_set_reduced_motion_enabled", true)
	var parked := camera.transform
	var camera_size := camera.size
	_expect(not moving.is_equal_approx(parked) and not canal.is_processing(),
		"Enabling reduced motion mid-ease must immediately park the two-shot and its clock.")
	var low := water.position.y
	canal.call("present", 1.0, Duel.Singer.PLAYER)
	_expect(water.position.y > low and camera.transform.is_equal_approx(parked)
		and is_equal_approx(camera.size, camera_size),
		"Essential chamber water must rise without moving a reduced-motion camera.")
	for index in boats.size():
		var boat := boats[index] as Node3D
		_expect(boat.rotation.is_zero_approx()
			and is_equal_approx(boat.position.y - water.position.y, 0.26),
			"Reduced-motion launches must stay level and afloat at the new chamber height.")
		# The dummy renderer does not retain MultiMesh instance transforms.
		if DisplayServer.get_name() == "headless":
			continue
		var lines := chamber.get_node("TowLines") as MultiMeshInstance3D
		for end in 2:
			var segment := index * 4 + end * 2
			var a := lines.multimesh.get_instance_transform(segment)
			var b := lines.multimesh.get_instance_transform(segment + 1)
			var anchors: Array = chamber.get("tow_anchors")
			var endpoint := boat.transform * Vector3(
				-1.0 if index == 0 else 1.0, 0.32, -0.85 if end == 0 else 0.85)
			_expect((a * (Vector3.DOWN * 0.5)).is_equal_approx(anchors[index * 2 + end])
				and (b * (Vector3.UP * 0.5)).is_equal_approx(endpoint),
				"Rotated tow lines must retain both actual endpoints as a launch rises.")
	var ribbon: Node3D = canal.get("ribbon")
	var track: Array[Dictionary] = []
	for index in 70:
		track.append(Frame.make(float(index) * Frame.STEP_SECONDS,
			200.0 if index < 50 else 900.0, index < 20 or index >= 50, 0.2))
	var original := track.duplicate(true)
	ribbon.call("show_track", track, {}, 6.0, Frame.profile(), Vector3.ZERO, Vector3(6, 0, 0))
	var mesh := ribbon.get_child(0) as MeshInstance3D
	var quiet: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bridges_gap := false
	for index in range(0, quiet.size(), 3):
		var left := minf(quiet[index].x, minf(quiet[index + 1].x, quiet[index + 2].x))
		var right := maxf(quiet[index].x, maxf(quiet[index + 1].x, quiet[index + 2].x))
		bridges_gap = bridges_gap or (left < 0.35 and right > 0.35)
	_expect(not bridges_gap and not quiet.is_empty(),
		"The world contour must contain real geometry without joining silent gaps.")
	var louder := track.duplicate(true)
	for frame: Dictionary in louder:
		frame["level"] = 1.0
	ribbon.call("show_track", louder, {}, 6.0, Frame.profile(), Vector3.ZERO, Vector3(6, 0, 0))
	_expect(quiet == mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] and track == original,
		"Extra amplitude must not widen or improve the contour, or mutate the source track.")
	var lower := track.duplicate(true)
	for frame: Dictionary in lower:
		frame["cents"] = float(frame["cents"]) * 0.5
	var profile := Frame.profile()
	profile["falsetto_low"] = 350.0
	profile["falsetto_high"] = 650.0
	ribbon.call("show_track", lower, {"breaks": [{"t": 0.5, "to": 450.0}]},
		6.0, profile, Vector3.ZERO, Vector3(6, 0, 0))
	var decorated: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	game.call("_set_intense_effects_enabled", false)
	var plain: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_expect(quiet == plain and decorated.size() > plain.size(),
		"Profile-relative pitch must match across singers; effects-off removes marks, not contour.")
	canal.call("reset")
	game.call("_set_reduced_motion_enabled", reduced)
	game.call("_set_intense_effects_enabled", intense)


func _test_layouts(game: Node, spike: Control, hud: Control) -> void:
	var settings := get_root().get_node("Settings")
	var values: Dictionary = settings.get("_values")
	for size in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(1280, 720),
			Vector2i(2560, 1080)]:
		for scale: float in [1.0, 1.5]:
			game.call("_return_to_duel")
			values["ui/scale"] = scale
			get_root().min_size = Vector2i.ZERO
			get_root().size = size
			settings.call("_update_content_scale")
			settings.emit_signal("changed", "ui/scale", scale)
			for _frame in 6:
				await process_frame
			if DisplayServer.get_name() != "headless":
				await process_frame
				_assert_arena(hud, true)
				_capture("duel-ready-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
			_first_answer(game)
			_open_player(game)
			for _frame in 6:
				await process_frame
			var ribbon := spike.get_node("%VoiceRibbon") as Control
			var button := spike.get_node("%RemoBreak") as Button
			var transform := get_root().get_final_transform()
			var window := Rect2(Vector2.ZERO, Vector2(size))
			for control in [ribbon, button, hud.get_node("%PauseDuel")]:
				var rect := transform * (control as Control).get_global_rect()
				_expect(window.encloses(rect),
					"Active input must fit %s at UI %.1f: %s %s" % [
						size, scale, (control as Control).name, rect,
					])
			var caption := game.get_node("%AudioCaption") as Control
			var caption_rect := transform * caption.get_global_rect()
			var turn := hud.get("_turn") as Label
			_expect(not caption.is_visible_in_tree() and turn.is_visible_in_tree()
				and turn.text.begins_with("YA!"),
				"The YA header must caption listening without a duplicate taking input space.")
			if DisplayServer.get_name() != "headless":
				await process_frame
				_assert_arena(hud, false)
				await process_frame
				_capture("duel-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
			if size == Vector2i(320, 568) and scale == 1.5:
				_test_duel_touch(game, spike, ribbon, button)
			elif size == Vector2i(1280, 720) and scale == 1.0:
				_test_duel_gamepad(game)
			else:
				_draw_call(game)
			for _frame in 3:
				await process_frame
			caption_rect = transform * caption.get_global_rect()
			_expect(caption.is_visible_in_tree() and window.encloses(caption_rect)
				and str(caption.call("caption_text")).contains("tanda"),
				"A real tanda's full sound caption must remain visible inside every layout.")
			if DisplayServer.get_name() != "headless":
				_capture("duel-verdict-%dx%d-ui%.1f.png" % [size.x, size.y, scale])
			game.call("_on_turn_cancelled", "Layout check complete.")
			_tick(game, 0.0)


func _assert_arena(hud: Control, check_budget: bool) -> void:
	var lock: Control = hud.get("lock")
	var camera: Camera3D = lock.get("camera")
	var viewport: SubViewport = lock.get("viewport")
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
	_expect(viewport.find_world_3d() != get_root().find_world_3d(),
		"The lock must never borrow the framework's 3D world.")
	for boat: Node3D in lock.get("boats"):
		for child in boat.get_children():
			if not child is MeshInstance3D:
				continue
			var mesh := child as MeshInstance3D
			for corner in 8:
				var world := mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
				_expect(bounds.has_point(camera.unproject_position(world)),
					"Both complete boat meshes must remain within the real compatibility camera.")
	if check_budget:
		var draws := viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		_expect(draws > 0 and draws < 60,
			"The rendered lock must stay below 60 draw calls, not pass as an empty viewport.")


func _test_duel_touch(game: Node, spike: Control, ribbon: Control, button: Button) -> void:
	var position := ribbon.get_global_transform_with_canvas() * (ribbon.size * Vector2(0.5, 0.6))
	_send_touch(4, position)
	_tick(game, 0.5)
	var break_position := button.get_global_transform_with_canvas() * (button.size * 0.5)
	_send_touch(8, break_position)
	_tick(game, 0.04)
	_send_touch(8, break_position, false)
	_tick(game, 0.2)
	var source := spike.get("_remo") as RefCounted
	_expect(bool(source.call("has_contact", 4)) and bool(source.call("is_voiced"))
		and is_equal_approx(float(source.get("pitch_cents")), 700.0),
		"The compact duel must retain independent ribbon and Break fingers at 150% UI.")
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = position + Vector2(0, ribbon.size.y * 0.3)
	drag.velocity = Vector2(0, ribbon.size.y * 5.0)
	get_root().push_input(drag, true)
	_tick(game, 0.12)
	_send_touch(4, drag.position, false)
	var duel: Duel = game.get("_duel")
	_expect(duel.phase == Duel.Phase.REVIEW and duel.records.size() == 2,
		"A real touch Remate must score and close the admitted duel turn.")


func _test_duel_gamepad(game: Node) -> void:
	_send_pad(JOY_BUTTON_A)
	_tick(game, 0.5)
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER)
	_tick(game, 0.04)
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	_tick(game, 0.2)
	_send_pad(JOY_BUTTON_B)
	_tick(game, 0.12)
	_send_pad(JOY_BUTTON_B, false)
	_send_pad(JOY_BUTTON_A, false)
	var duel: Duel = game.get("_duel")
	_expect(duel.phase == Duel.Phase.REVIEW and duel.records.size() == 2
		and (duel.records[-1]["result"]["evidence"]["breaks"] as Array).size() == 1,
		"Actual pad Voice/Break/Finish must pass through duel admission and the real scorer.")


func _first_answer(game: Node) -> void:
	game.call("_on_duel_action")
	_tick(game, 3.73)
	game.call("_on_duel_action")


func _open_player(game: Node) -> void:
	game.call("_on_duel_action")
	_tick(game, 0.25)
	var duel: Duel = game.get("_duel")
	_expect(duel.phase == Duel.Phase.LISTENING, "Ready and the full guard must open a turn.")
	_expect(not (game.get("_cue") as AudioStreamPlayer).playing,
		"Cue playback must be stopped before opening the scored listening window.")
	_expect(_canal_silent(game), "No canal effect may overlap admitted player input.")


func _draw_call(game: Node) -> void:
	_send_key(KEY_SPACE)
	_tick(game, 1.2)
	for _index in 3:
		_send_key(KEY_J)
		_tick(game, 0.04)
		_send_key(KEY_J, false)
		_tick(game, 1.2)
	_send_key(KEY_K)
	_tick(game, 0.12)
	_send_key(KEY_K, false)
	_send_key(KEY_SPACE, false)


func _tick(game: Node, delta: float) -> void:
	game.call("_update_round", delta, 0.0)


func _checked_capture(spike: Control) -> BufferedCapture:
	var capture := BufferedCapture.new()
	spike.add_child(capture)
	spike.set("_capture", capture)
	return capture


func _canal_silent(game: Node) -> bool:
	var audio := game.get("_canal_audio") as Node
	for player: AudioStreamPlayer in audio.get("_players"):
		if player.playing:
			return false
	return true


func _pcm(seconds: float, frequency := 160.0) -> PackedVector2Array:
	var pcm := PackedVector2Array()
	var rate := AudioServer.get_mix_rate()
	for index in roundi(seconds * rate):
		var value := 0.12 * sin(TAU * frequency * float(index) / float(rate))
		pcm.append(Vector2(value, value))
	return pcm


func _send_key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	get_root().push_input(event, true)


func _send_pad(button: JoyButton, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	get_root().push_input(event, true)


func _send_touch(index: int, position: Vector2, pressed := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	get_root().push_input(event, true)


func _capture(filename: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-capture-dir="):
			var directory := argument.trim_prefix("--sailor-capture-dir=")
			DirAccess.make_dir_recursive_absolute(directory)
			var error := get_root().get_texture().get_image().save_png(
				directory.path_join(filename))
			_expect(error == OK, "Could not save duel layout capture.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
