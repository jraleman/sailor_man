extends RefCounted

## Records a complete duel with actual Remo keyboard input and the real judges.
## The driver never enables, impersonates or records a real microphone.

signal keycap_requested(text: String)

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const STEPS: Array[Dictionary] = [
	{
		"time": 0.0, "title": "One synthetic practice rival",
		"body": "First to two tandas wins. Remo needs no microphone; this is a grey-box prototype.",
	},
	{
		"time": 1.0, "title": "Listen to the call",
		"body": "The practice skiff holds, breaks registers twice and finishes. Its tone is not a recording.",
	},
	{
		"time": 6.0, "title": "Ready, then answer",
		"body": "Wait for YA! Hold Space for Voice. J breaks registers; W/S or arrows glide pitch.",
	},
	{
		"time": 11.6, "title": "Finish with Remate",
		"body": "K finishes the answer. Echo the call, then top it with breath, clean breaks and a finish.",
	},
	{
		"time": 12.8, "title": "Read the numbered paddles",
		"body": "The three judges prefer Quiebre, Aliento and Eco. Tied tandas go to the answerer.",
	},
	{
		"time": 15.0, "title": "Now you call",
		"body": "Lead tanda two with your own contour. Calls do not score Eco; the rival must answer you.",
	},
	{
		"time": 22.0, "title": "The same marks judge the rival",
		"body": "Its authored track passes through the same scorer. The chamber clock pauses inside turns.",
	},
	{
		"time": 26.4, "title": "Two tandas take the duel",
		"body": "Review the verdict, then open Results. Retry costs no lives and clears this duel's state.",
	},
	{
		"time": 28.0, "title": "A prototype, not the finished voyage",
		"body": "Real recordings, microphone QA, cultural review and saved Soundcheck profiles remain pending.",
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
var _take_started := -1.0


## There is no hot-seat or campaign walkthrough to advertise yet.
func configure(variant: String) -> bool:
	_stage = 0
	_event_index = 0
	_take_started = -1.0
	return variant == "solo"


## Keep captions honest about the prototype and its source of input.
func steps() -> Array[Dictionary]:
	return STEPS


## Enough time for both tandas, their paddles and the actual shell results.
func duration() -> float:
	return 32.0


## Reproducible, in-memory options; never write a viewer's settings.
func settings_overrides() -> Dictionary:
	var values := {
		Options.QUIET_MODE_KEY: false, Options.LONG_WINDOWS_KEY: false,
		Options.MIC_SENSITIVITY_KEY: 1.0, "ui/scale": 1.0,
	}
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		values[binding["key"]] = binding["default"]
	return values


## The single-player duel owns its rival; no generic multiplayer mode is implied.
func configure_session(session: Node) -> void:
	session.call("configure_single_player")


## Start at the unmodified, microphone-off screen.
func start(_scene: Node) -> void:
	_stage = 0
	_event_index = 0
	_take_started = -1.0


## Input events, not fabricated tracks or scores, drive both call and answer.
func update(scene: Node, time: float, _delta: float) -> void:
	if not bool(scene.get("_round_active")):
		return
	var spike := scene.get_node("%ScorerSpike") as Control
	var duel: Duel = scene.get("_duel")
	if time >= 1.0 and _stage == 0:
		_press_primary(scene)
		_stage = 1
	elif _stage == 1 and time >= 6.0 and duel.phase == Duel.Phase.REVIEW:
		_press_primary(scene)
		_stage = 2
	elif _stage == 2 and time >= 6.8 and duel.phase == Duel.Phase.PLAYER_READY:
		_press_primary(scene)
		_stage = 3
	elif _stage == 4 and time >= 14.0 and duel.phase == Duel.Phase.REVIEW:
		_press_primary(scene)
		_stage = 5
	elif _stage == 5 and time >= 15.0 and duel.phase == Duel.Phase.PLAYER_READY:
		_press_primary(scene)
		_stage = 6
	elif _stage == 7 and time >= 22.0 and duel.phase == Duel.Phase.REVIEW:
		_press_primary(scene)
		_stage = 8
	elif _stage == 8 and time >= 28.0 and duel.phase == Duel.Phase.COMPLETE:
		_press_primary(scene)
		_stage = 9
	if _stage in [3, 6] and duel.phase == Duel.Phase.LISTENING:
		if _take_started < 0.0:
			_take_started = time
			_event_index = 0
		while (
			_event_index < CALL_EVENTS.size()
			and time - _take_started >= float(CALL_EVENTS[_event_index]["time"])
		):
			var action := CALL_EVENTS[_event_index]
			var event := InputEventKey.new()
			event.physical_keycode = int(action["key"])
			event.pressed = bool(action["pressed"])
			Input.parse_input_event(event)
			if event.pressed:
				keycap_requested.emit(OS.get_keycode_string(event.physical_keycode))
			_event_index += 1
	elif _stage in [3, 6] and _take_started >= 0.0 and _event_index == CALL_EVENTS.size():
		if not bool(spike.get("_remo_active")):
			_stage += 1
			_take_started = -1.0
	var hud := scene.get_node("%DuelHud") as Control
	var info := hud.get("_info") as ScrollContainer
	if duel.phase in [Duel.Phase.RIVAL, Duel.Phase.REPEAT]:
		info.ensure_control_visible(hud.get("lock") as Control)
	elif duel.phase in [Duel.Phase.REVIEW, Duel.Phase.COMPLETE]:
		info.scroll_vertical = 0


func _press_primary(scene: Node) -> void:
	var hud := scene.get_node("%DuelHud") as Control
	(hud.get_node("%PrimaryAction") as Button).pressed.emit()


## Reject a partial duel, fabricated input, an opened mic or missing shell results.
func validate_finished(scene: Node) -> bool:
	var spike := scene.get_node("%ScorerSpike") as Control
	var duel: Duel = scene.get("_duel")
	if _stage != 9 or duel.phase != Duel.Phase.COMPLETE or duel.wins[0] != 2:
		return false
	for record: Dictionary in duel.records:
		if int(record["singer"]) != Duel.Singer.PLAYER:
			continue
		var result: Dictionary = record["result"]
		if (
			str(record["source"]) != "Remo" or float(result["total"]) < 0.8
			or (result["evidence"]["breaks"] as Array).size() != 3
			or float(result["marks"]["remate"]) != 1.0
			or (bool(result["answering"]) and float(result["marks"]["eco"]) <= 0.0)
		):
			return false
	return (
		duel.records.size() == 4 and spike.get("_capture") == null
		and not bool(spike.get("_remo_active")) and not bool(scene.get("_round_active"))
		and (scene.get_node("%RoundOver") as Control).visible
	)
