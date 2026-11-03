extends Node

## Original non-vocal canal effects, owned by the game rather than the global
## SFX pool so guard, setup, pause and exit can stop every voice immediately.

signal caption_requested(text: String)

enum Sound { HORN, WATER, APPLAUSE, PADDLE, MULA_BELL }

const SAMPLE_RATE := 22050
const SECONDS := {
	Sound.HORN: 0.65, Sound.WATER: 2.0, Sound.APPLAUSE: 0.75,
	Sound.PADDLE: 0.12, Sound.MULA_BELL: 0.48,
}
const NAMES := ["LockHorn", "FillingWater", "Applause", "PaddleClack", "MulaBell"]
const VOLUMES := [-22.0, -30.0, -24.0, -20.0, -24.0]

var _players: Array[AudioStreamPlayer] = []
var _allowed := false


func _ready() -> void:
	for kind: int in Sound.values():
		var player := AudioStreamPlayer.new()
		player.name = NAMES[kind]
		player.bus = &"SFX"
		player.volume_db = VOLUMES[kind]
		player.stream = make_stream(kind)
		add_child(player)
		_players.append(player)


## Context is supplied by the duel; this node cannot open a listening window.
func set_context(allowed: bool, water_flowing: bool) -> void:
	assert(allowed or not water_flowing)
	_allowed = allowed
	if not allowed:
		stop()
	elif water_flowing:
		if not _players[Sound.WATER].playing:
			_players[Sound.WATER].play()
	else:
		_players[Sound.WATER].stop()


## One combined caption keeps simultaneous clack/bell/applause from overwriting
## each other in the shared caption widget. Empty winner means a call review.
func review(tanda_winner := "") -> void:
	if not _allowed:
		return
	_players[Sound.PADDLE].play()
	var text := "Paddles clack: judges show their scores."
	if not tanda_winner.is_empty():
		_players[Sound.MULA_BELL].play()
		_players[Sound.APPLAUSE].play()
		text = "Paddles, bell, applause: %s wins the tanda." % tanda_winner
	caption_requested.emit(text)


## A timeout has no new scored performance, so it gets a horn, not fake paddles.
func complete(winner: String, timed_out := false) -> void:
	assert(not winner.is_empty())
	if not _allowed:
		return
	_players[Sound.WATER].stop()
	_players[Sound.HORN].play()
	if timed_out:
		caption_requested.emit("Chamber horn: time is up; %s wins." % winner)
	else:
		_players[Sound.PADDLE].play()
		_players[Sound.APPLAUSE].play()
		caption_requested.emit("Horn, paddles and applause: %s wins the duel." % winner)


## No deferred callbacks may restart an effect after capture or pause begins.
func stop() -> void:
	_allowed = false
	for player in _players:
		player.stop()


## Seeded local noise never changes the game's RNG or imitates a performer.
## Smooth ends keep short cues and the repeated water wash free of hard clicks.
static func make_stream(kind: Sound) -> AudioStreamWAV:
	assert(SECONDS.has(kind))
	var duration: float = SECONDS[kind]
	var count := roundi(duration * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 57117 + kind
	var filtered := 0.0
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in count:
		var time := float(index) / float(SAMPLE_RATE)
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.08)
		var attack := 0.02 if kind == Sound.WATER else 0.004
		var release := 0.02 if kind == Sound.WATER else minf(0.08, duration * 0.3)
		var envelope := smoothstep(0.0, attack, time) \
			* smoothstep(0.0, release, duration - time)
		var value := _sample(kind, time, noise, filtered) * envelope * 0.8
		pcm.encode_s16(index * 2, roundi(clampf(value, -0.85, 0.85) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = pcm
	if kind == Sound.WATER:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream


static func _sample(kind: Sound, time: float, noise: float, filtered: float) -> float:
	match kind:
		Sound.HORN:
			var phase := TAU * 110.0 * time + sin(TAU * 4.0 * time) * 0.15
			return sin(phase) * 0.55 + sin(phase * 2.0) * 0.28 + sin(phase * 3.0) * 0.1
		Sound.WATER:
			return filtered * 0.85 + sin(TAU * 70.0 * time) * 0.06
		Sound.APPLAUSE:
			var claps := 0.0
			for onset: float in [0.0, 0.085, 0.19, 0.32, 0.49]:
				var age := time - onset
				if age >= 0.0:
					claps += minf(age / 0.003, 1.0) * exp(-age * 45.0)
			return noise * claps * 0.7
		Sound.PADDLE:
			return (sin(TAU * 1350.0 * time) * 0.65
				+ sin(TAU * 2790.0 * time) * 0.2 + noise * 0.15) * exp(-time * 55.0)
		Sound.MULA_BELL:
			var phase := TAU * 1250.0 * time
			return (sin(phase) * 0.5 + sin(phase * 2.756) * 0.3
				+ sin(phase * 4.087) * 0.12) * exp(-time * 7.0)
	assert(false, "Unknown Sailor Man sound.")
	return 0.0


func _exit_tree() -> void:
	stop()
	for player in _players:
		player.stream = null
