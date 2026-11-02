extends RefCounted

## Synthetic contours, not recordings or claims about authentic saloma.
## Integer sample counts keep every fixture on the shared 100 Hz clock.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")

var frames: Array[Dictionary] = []


## A held pitch also makes a useful flat-yell counterexample.
func hold(seconds: float, cents := 0.0, level := 1.0) -> void:
	for _index in int(round(seconds * Frame.RATE_HZ)):
		_append(cents, true, level)


## Both gradual glides and short, deliberate jumps use continuous pitch.
func glide(seconds: float, from: float, to: float, level := 1.0) -> void:
	var count := int(round(seconds * Frame.RATE_HZ))
	for index in count:
		_append(lerpf(from, to, float(index + 1) / float(count)), true, level)


## Tiny gaps exercise the breath bridge without inventing voiced samples.
func gap(seconds: float) -> void:
	for _index in int(round(seconds * Frame.RATE_HZ)):
		_append(0.0, false, 0.0)


## Landing wobble must lower cleanness, not turn into extra quiebres.
func wobble(seconds: float, centre: float, amplitude: float) -> void:
	for index in int(round(seconds * Frame.RATE_HZ)):
		_append(
			centre + amplitude * sin(TAU * 20.0 * float(index) / Frame.RATE_HZ),
			true, 1.0
		)


## A slow envelope must not earn the same Remate as a crisp stop.
func fade(seconds: float, cents := 0.0) -> void:
	var count := int(round(seconds * Frame.RATE_HZ))
	for index in count:
		_append(cents, true, 1.0 - float(index + 1) / float(count))
	gap(0.12)


## Leave actual silence after the release; a window ending is not a cut-off.
func cut_off() -> void:
	gap(0.12)


## Three jumps, a held breath and a falling finish, with adjustable timing.
static func shaped(stretch := 1.0) -> Array[Dictionary]:
	var fixture := new()
	fixture.hold(1.2 * stretch)
	fixture.glide(0.04 * stretch, 0.0, 1000.0)
	fixture.hold(1.2 * stretch, 1000.0)
	fixture.glide(0.04 * stretch, 1000.0, 0.0)
	fixture.hold(1.2 * stretch)
	fixture.glide(0.04 * stretch, 0.0, 1000.0)
	fixture.hold(1.0 * stretch, 1000.0)
	fixture.glide(0.4 * stretch, 1000.0, 0.0)
	fixture.cut_off()
	return fixture.frames


func _append(cents: float, voiced: bool, level: float) -> void:
	frames.append(Frame.make(float(frames.size()) / Frame.RATE_HZ, cents, voiced, level))
