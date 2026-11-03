extends SceneTree

## Generated PCM and real owned players guard smooth cues, quiet contexts and
## complete captions without requesting hardware or recording any input.

const CanalAudio = preload("res://games/sailor_man/audio/sailor_audio.gd")

var _failures := PackedStringArray()
var _captions := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_pcm()
	var buses := AudioServer.bus_count
	var audio := CanalAudio.new()
	audio.caption_requested.connect(func(text: String) -> void: _captions.append(text))
	get_root().add_child(audio)
	audio.review("P1")
	audio.complete("P1")
	_expect(_silent(audio) and _captions.is_empty() and AudioServer.bus_count == buses,
		"An unadmitted audio context must stay silent without allocating a capture bus.")
	audio.set_context(true, true)
	audio.review("P1")
	_expect(_captions.size() == 1 and _captions[-1].contains("P1")
		and _captions[-1].contains("Paddles") and _captions[-1].contains("bell")
		and _captions[-1].contains("applause"),
		"A tanda's simultaneous sounds need one complete caption, not overwriting fragments.")
	var water := audio.get_node("FillingWater") as AudioStreamPlayer
	_expect(water.playing and (audio.get_node("MulaBell") as AudioStreamPlayer).playing
		and (audio.get_node("PaddleClack") as AudioStreamPlayer).playing,
		"Admitted review must actually play the water and its authored effects.")
	# Let the mixer consume starts before testing interruption of real playback.
	await create_timer(0.08, true, false, true).timeout
	audio.set_context(false, false)
	var caption_count := _captions.size()
	audio.review("CPU")
	_expect(_silent(audio) and _captions.size() == caption_count,
		"A guard/setup context must stop existing effects and refuse new ones.")
	audio.set_context(true, false)
	audio.complete("CPU", true)
	_expect(not water.playing and (audio.get_node("LockHorn") as AudioStreamPlayer).playing
		and not (audio.get_node("PaddleClack") as AudioStreamPlayer).playing
		and _captions[-1].contains("time is up"),
		"A real timeout gets a horn/caption without implying another scored paddle.")
	await create_timer(0.08, true, false, true).timeout
	audio.stop()
	audio.set_context(true, true)
	await create_timer(0.08, true, false, true).timeout
	audio.complete("P1")
	_expect(not water.playing and _captions[-1].contains("P1 wins the duel"),
		"Completion must stop water and describe the actual winner.")
	await create_timer(0.08, true, false, true).timeout
	audio.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1, true, false, true).timeout
	_expect(AudioServer.bus_count == buses, "Audio teardown must leave the bus layout untouched.")
	if _failures.is_empty():
		print("Sailor canal audio tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_pcm() -> void:
	for kind: CanalAudio.Sound in CanalAudio.Sound.values():
		var stream := CanalAudio.make_stream(kind)
		var pcm := stream.data
		var count := pcm.size() / 2
		var peak := 0.0
		var squares := 0.0
		var sum := 0.0
		for index in count:
			var value := float(pcm.decode_s16(index * 2)) / 32767.0
			peak = maxf(peak, absf(value))
			squares += value * value
			sum += value
		_expect(peak > 0.1 and peak <= 0.851 and sqrt(squares / float(count)) > 0.005
			and absf(sum / float(count)) < 0.02,
			"Every authored cue needs audible, unclipped PCM without substantial DC offset.")
		_expect(absi(pcm.decode_s16(0)) <= 1 and absi(pcm.decode_s16(pcm.size() - 2)) <= 1,
			"Authored clips must approach silence at both ends, including the loop seam.")
		if kind == CanalAudio.Sound.WATER:
			var seam := absf(float(pcm.decode_s16(2))
				- float(pcm.decode_s16(pcm.size() - 4))) / 32767.0
			_expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
				and stream.loop_end * 2 == pcm.size() and seam < 0.001,
				"The flowing-water loop must join its real PCM boundaries without a click.")
		_expect(pcm == CanalAudio.make_stream(kind).data,
			"Local seeded synthesis must reproduce a cue independently of game randomness.")


func _silent(audio: Node) -> bool:
	for player: AudioStreamPlayer in audio.get("_players"):
		if player.playing:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
