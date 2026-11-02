extends RefCounted

## Records actual Remo keyboard input through the workbench and shared scorer.
## The driver never enables, impersonates or records a real microphone.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const STEPS: Array[Dictionary] = [
	{
		"time": 0.0, "title": "Remo needs no microphone",
		"body": "Start Remo, then hold Space for Voice. This prototype uses a synthetic tone.",
	},
	{
		"time": 3.2, "title": "Hold, then break",
		"body": "J switches registers. W/S or arrows glide pitch; gamepad and touch work too.",
	},
	{
		"time": 7.2, "title": "Finish and meet the marks",
		"body": "K finishes the call. The same scorer judges Aliento, Quiebre, Altura and Remate.",
	},
	{
		"time": 10.0, "title": "Keep a call, then answer",
		"body": "Remo follows the kept contour for Eco. Microphone calls use this same ribbon and judge.",
	},
	{
		"time": 17.0, "title": "Still a development workbench",
		"body": "No rival or voyage yet. Real recordings, microphone QA and cultural review remain pending.",
	},
]
const CALL_EVENTS: Array[Dictionary] = [
	{"time": 0.0, "key": KEY_SPACE, "pressed": true},
	{"time": 1.2, "key": KEY_J, "pressed": true},
	{"time": 1.24, "key": KEY_J, "pressed": false},
	{"time": 2.4, "key": KEY_J, "pressed": true},
	{"time": 2.44, "key": KEY_J, "pressed": false},
	{"time": 3.6, "key": KEY_J, "pressed": true},
	{"time": 3.64, "key": KEY_J, "pressed": false},
	{"time": 4.5, "key": KEY_S, "pressed": true},
	{"time": 4.9, "key": KEY_S, "pressed": false},
	{"time": 4.9, "key": KEY_K, "pressed": true},
	{"time": 4.96, "key": KEY_K, "pressed": false},
	{"time": 4.96, "key": KEY_SPACE, "pressed": false},
]

var _stage := 0
var _event_index := 0
var _take_started := 0.0


## There is no hot-seat or campaign walkthrough to advertise yet.
func configure(variant: String) -> bool:
	_stage = 0
	_event_index = 0
	return variant == "solo"


## Keep captions honest about the prototype and its source of input.
func steps() -> Array[Dictionary]:
	return STEPS


## Two real button performances, with no expectation that a viewer sings along.
func duration() -> float:
	return 21.0


## Reproducible, in-memory options; never write a viewer's settings.
func settings_overrides() -> Dictionary:
	var values := {
		Options.QUIET_MODE_KEY: false, Options.LONG_WINDOWS_KEY: false,
		Options.MIC_SENSITIVITY_KEY: 1.0, "ui/scale": 1.0,
	}
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		values[binding["key"]] = binding["default"]
	return values


## The scaffold is solo, not a stand-in for an implemented CPU.
func configure_session(session: Node) -> void:
	session.call("configure_single_player")


## Start at the unmodified, microphone-off screen.
func start(_scene: Node) -> void:
	_stage = 0
	_event_index = 0


## Input events, not fabricated tracks or scores, drive both call and answer.
func update(scene: Node, time: float, _delta: float) -> void:
	if not bool(scene.get("_round_active")):
		return
	var spike := scene.get_node("%ScorerSpike") as Control
	if time >= 2.0 and _stage == 0:
		_start_take(spike, time)
		_stage = 1
	elif time >= 10.0 and _stage == 2:
		(spike.get_node("%KeepReference") as Button).pressed.emit()
		_start_take(spike, time)
		_stage = 3
	if _stage in [1, 3]:
		while (
			_event_index < CALL_EVENTS.size()
			and time - _take_started >= float(CALL_EVENTS[_event_index]["time"])
		):
			var action := CALL_EVENTS[_event_index]
			var event := InputEventKey.new()
			event.physical_keycode = int(action["key"])
			event.pressed = bool(action["pressed"])
			Input.parse_input_event(event)
			_event_index += 1
		if _event_index == CALL_EVENTS.size() and not bool(spike.get("_remo_active")):
			_stage += 1
	if _stage > 0:
		(spike.get_node("%Scroll") as ScrollContainer).ensure_control_visible(
			spike.get_node("%VoiceRibbon" if _stage in [1, 3] else "%Marks") as Control
		)


func _start_take(spike: Control, time: float) -> void:
	_take_started = time
	_event_index = 0
	(spike.get_node("%StartRemo") as Button).pressed.emit()


## Reject recordings that did not actually voice, break, finish and earn Eco.
func validate_finished(scene: Node) -> bool:
	var spike := scene.get_node("%ScorerSpike") as Control
	var result: Dictionary = spike.get("_last_result")
	return (
		_stage == 4 and spike.get("_capture") == null
		and not bool(spike.get("_remo_active")) and bool(result.get("valid", false))
		and float(result.get("total", 0.0)) > 0.85
		and float((result.get("marks", {}) as Dictionary).get("eco", 0.0)) > 0.95
		and ((result.get("evidence", {}) as Dictionary).get("breaks", []) as Array).size() == 3
	)
