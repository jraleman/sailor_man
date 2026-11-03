extends AudioStreamPlayer

## An original, neutral tone previews Remo pitch while captain takes are absent.
## This is explicitly synthetic development audio, not an imitation salomero.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const SAMPLE_RATE := 22050
const CHEST_HZ := Frame.DEFAULT_CHEST_HZ
const LOOP_SECONDS := 0.1
const VOLUME_DB := -18.0


func _ready() -> void:
	bus = &"SFX"
	volume_db = VOLUME_DB
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = SAMPLE_RATE
	tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tone.loop_end = roundi(LOOP_SECONDS * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(tone.loop_end * 2)
	for index in tone.loop_end:
		var phase := TAU * CHEST_HZ * float(index) / float(SAMPLE_RATE)
		var sample := sin(phase) * 0.7 + sin(phase * 2.0) * 0.2 + sin(phase * 3.0) * 0.1
		pcm.encode_s16(index * 2, roundi(sample * 16000.0))
	tone.data = pcm
	stream = tone


## Live Remo and completed reference tracks use pitch alone, never microphone PCM.
func play_frame(frame: Dictionary) -> void:
	if not bool(frame["voiced"]):
		stop()
		return
	pitch_scale = pow(2.0, float(frame["cents"]) / 1200.0)
	if not playing:
		play()
