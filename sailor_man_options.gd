extends RefCounted

## Only implemented spike controls are advertised. Remo, rivals, campaign,
## captains and cosmetics acquire their declarations with their milestones.

const GAME_ID := "sailor_man"
const QUIET_MODE_KEY := "game/sailor_man_quiet_mode"
const LONG_WINDOWS_KEY := "game/sailor_man_long_windows"
const MIC_SENSITIVITY_KEY := "game/sailor_man_mic_sensitivity"
const RECORD_KEY := "controls/sailor_man_spike_record"
const RECORD_ACTION := &"sailor_man_spike_record"

const TUNABLES: Array[Dictionary] = [
	{
		"key": QUIET_MODE_KEY,
		"type": GameManifest.OPTION_TOGGLE,
		"default": false,
		"title": "Quiet Mode",
		"description": "Removes the carrying-level gate. Extra volume never earns points.",
		"heading": "Voice scorer prototype",
	},
	{
		"key": LONG_WINDOWS_KEY,
		"type": GameManifest.OPTION_TOGGLE,
		"default": false,
		"title": "Longer listening windows",
		"description": "Record up to nine seconds instead of six. Stop whenever comfortable.",
		"heading": "Voice scorer prototype",
	},
	{
		"key": MIC_SENSITIVITY_KEY,
		"default": 1.0,
		"min": 0.5,
		"max": 1.5,
		"step": 0.05,
		"format": GameManifest.FORMAT_PERCENT,
		"title": "Microphone sensitivity",
		"description": "Adjusts input gain, not the pitch or the judges' scoring weights.",
		"heading": "Voice scorer prototype",
	},
]

const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": RECORD_KEY,
		"action": RECORD_ACTION,
		"default": KEY_R,
		"title": "Start / stop a test call",
		"description": "Records only after you explicitly enable and check the microphone.",
		"heading": "Voice scorer prototype",
	},
]
