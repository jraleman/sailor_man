extends RefCounted

## Records the actual prototype UI with explicitly synthetic examples.
## The driver never enables, impersonates or records a real microphone.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const STEPS: Array[Dictionary] = [
	{
		"time": 0.0, "title": "A voice-scorer prototype",
		"body": "Choose a microphone and enable it yourself. This recording keeps it off.",
	},
	{
		"time": 3.5, "title": "Volume is not the challenge",
		"body": "This synthetic flat hold has breath and a crisp stop, but no breaks or range.",
	},
	{
		"time": 7.5, "title": "Follow the shape",
		"body": "A synthetic contour adds Quiebre, Altura and a falling Remate. Not a real saloma.",
	},
	{
		"time": 11.5, "title": "Keep a call, then answer",
		"body": "The next answer earns Eco for its contour. Authentic-voice validation is still pending.",
	},
]

var _stage := 0


## There is no hot-seat or campaign walkthrough to advertise yet.
func configure(variant: String) -> bool:
	_stage = 0
	return variant == "solo"


## Keep captions honest about the prototype and its source of input.
func steps() -> Array[Dictionary]:
	return STEPS


## Four short lessons, with no expectation that a viewer sings along.
func duration() -> float:
	return 16.0


## Reproducible, in-memory options; never write a viewer's settings.
func settings_overrides() -> Dictionary:
	return {
		Options.QUIET_MODE_KEY: false, Options.LONG_WINDOWS_KEY: false,
		Options.MIC_SENSITIVITY_KEY: 1.0, "ui/scale": 1.0,
	}


## The scaffold is solo, not a stand-in for an implemented CPU.
func configure_session(session: Node) -> void:
	session.call("configure_single_player")


## Start at the unmodified, microphone-off screen.
func start(_scene: Node) -> void:
	_stage = 0


## Press the same visible buttons a player can press, then reveal the ribbon.
func update(scene: Node, time: float, _delta: float) -> void:
	if not bool(scene.get("_round_active")):
		return
	var spike := scene.get_node("%ScorerSpike") as Control
	if time >= 3.5 and _stage == 0:
		(spike.get_node("%FlatExample") as Button).pressed.emit()
		_stage = 1
	elif time >= 7.5 and _stage == 1:
		(spike.get_node("%ShapedExample") as Button).pressed.emit()
		_stage = 2
	elif time >= 11.5 and _stage == 2:
		(spike.get_node("%KeepReference") as Button).pressed.emit()
		(spike.get_node("%ShapedExample") as Button).pressed.emit()
		_stage = 3
	if _stage > 0:
		(spike.get_node("%Scroll") as ScrollContainer).ensure_control_visible(
			spike.get_node("%VoiceRibbon") as Control
		)


## Reject recordings that did not actually exercise the real scorer and Eco.
func validate_finished(scene: Node) -> bool:
	var spike := scene.get_node("%ScorerSpike") as Control
	var result: Dictionary = spike.get("_last_result")
	return (
		_stage == 3 and spike.get("_capture") == null
		and bool(result.get("valid", false))
		and float((result.get("marks", {}) as Dictionary).get("eco", 0.0)) > 0.99
	)
