extends Node

## Opt-in, unmonitored microphone capture, adapted locally from Dead Metal Jam.
## No recording is written to disk, and no device opens merely by loading a scene.

signal calibrated(noise_floor: float)
signal capture_failed(reason: String)

const BUS_PREFIX := "Saloma"
const SILENT_DB := -80.0
const ROOM_SECONDS := 2.0
const NO_INPUT_TIMEOUT := 4.0
const NOISE_MARGIN := 1.6
const MIN_NOISE_FLOOR := 0.0005
const MAX_NOISE_FLOOR := 0.05

var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _bus_name := ""
var _measuring := false
var _ready_for_input := false
var _frames := 0
var _energy := 0.0
var _peak := 0.0
var _elapsed := 0.0
var _failure := ""


func _ready() -> void:
	set_process(false)


## Called by a visible button, also providing the web user-gesture boundary.
func start(device := "") -> void:
	stop()
	_failure = ""
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		_fail("Microphone input is disabled in this project. The synthetic examples still work.")
		return
	if not device.is_empty():
		if not AudioServer.get_input_device_list().has(device):
			_fail("That input device is no longer available. Choose another device.")
			return
		AudioServer.input_device = device
	_bus_name = BUS_PREFIX + str(get_instance_id())
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, _bus_name)
	AudioServer.set_bus_volume_db(bus, SILENT_DB)
	AudioServer.set_bus_send(bus, "Master")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = _bus_name
	add_child(_player)
	_frames = 0
	_energy = 0.0
	_peak = 0.0
	_elapsed = 0.0
	_measuring = true
	_player.play()
	set_process(true)


func _process(delta: float) -> void:
	if not _measuring:
		return
	_elapsed += delta
	var available := _capture.get_frames_available()
	if available > 0:
		_measure_room(_capture.get_buffer(available))
	if _measuring and _elapsed >= NO_INPUT_TIMEOUT:
		_fail(
			"No microphone audio arrived. Check the device and microphone permission, "
			+ "then retry. Synthetic examples are available without a microphone."
		)


## Quiet room measurement must finish before frames can reach the scorer.
func poll() -> PackedVector2Array:
	if not _ready_for_input or _capture == null:
		return PackedVector2Array()
	var available := _capture.get_frames_available()
	return _capture.get_buffer(available) if available > 0 else PackedVector2Array()


## Discard speaker tails and idle audio before opening a fresh listening window.
func discard() -> void:
	if _capture != null:
		_capture.clear_buffer()


## Bus indices can shift when another game releases audio; remove ours by name.
func stop() -> void:
	set_process(false)
	_measuring = false
	_ready_for_input = false
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
		_player.queue_free()
	_player = null
	_capture = null
	if not _bus_name.is_empty():
		var index := AudioServer.get_bus_index(_bus_name)
		if index >= 0:
			AudioServer.remove_bus(index)
		_bus_name = ""


## The UI distinguishes ready, measuring and failed states without guessing.
func is_ready() -> bool:
	return _ready_for_input


## An empty reason means no failure, not that microphone permission was granted.
func failure_reason() -> String:
	return _failure


## Exact digital silence identifies a dead input rather than a quiet voice.
static func digital_silence(frames: PackedVector2Array) -> bool:
	for frame in frames:
		if frame.x != 0.0 or frame.y != 0.0:
			return false
	return true


func _measure_room(frames: PackedVector2Array) -> void:
	for frame in frames:
		var mono := (frame.x + frame.y) * 0.5
		_energy += mono * mono
		_peak = maxf(_peak, maxf(absf(frame.x), absf(frame.y)))
	_frames += frames.size()
	if float(_frames) / AudioServer.get_mix_rate() < ROOM_SECONDS:
		return
	if _peak <= 0.0:
		_fail(
			"The input is delivering digital silence: no working microphone is open. "
			+ "Check permission and the selected device, or use the synthetic examples."
		)
		return
	_measuring = false
	_ready_for_input = true
	_capture.clear_buffer()
	calibrated.emit(clampf(
		sqrt(_energy / float(_frames)) * NOISE_MARGIN,
		MIN_NOISE_FLOOR, MAX_NOISE_FLOOR
	))


func _fail(reason: String) -> void:
	_failure = reason
	stop()
	push_warning("Sailor Man microphone: %s" % reason)
	capture_failed.emit(reason)


func _exit_tree() -> void:
	stop()
