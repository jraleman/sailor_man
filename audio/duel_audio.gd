extends AudioStreamPlayer

## A quiet original cue above the detector's scored band, followed by the guard.
## It accompanies visible words; it is not a recorded conch or performer.

const SAMPLE_RATE := 22050
const CUE_HZ := 2400.0
const CUE_SECONDS := 0.06


func _ready() -> void:
	bus = &"SFX"
	volume_db = -18.0
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	var count := roundi(CUE_SECONDS * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in count:
		var phase := TAU * CUE_HZ * float(index) / float(SAMPLE_RATE)
		var envelope := sin(PI * float(index) / float(count))
		pcm.encode_s16(index * 2, roundi(sin(phase) * envelope * 12000.0))
	sound.data = pcm
	stream = sound


## The model's 250 ms guard still runs after this short cue begins.
func cue() -> void:
	stop()
	play()


func _exit_tree() -> void:
	stop()
	stream = null
