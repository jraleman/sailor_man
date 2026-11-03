extends RefCounted

## Only implemented workbench controls are advertised. Rivals, campaign,
## captains and cosmetics acquire their declarations with their milestones.

const GAME_ID := "sailor_man"
const QUIET_MODE_KEY := "game/sailor_man_quiet_mode"
const LONG_WINDOWS_KEY := "game/sailor_man_long_windows"
const MIC_SENSITIVITY_KEY := "game/sailor_man_mic_sensitivity"
const INPUT_SOURCE_KEY := "game/sailor_man_input_source"
const REST_REMINDERS_KEY := "game/sailor_man_rest_reminders"
enum InputSource { AUTO, MICROPHONE, REMO }
const INPUT_SOURCE_TITLES := ["Auto", "Microphone", "Remo"]
const RECORD_KEY := "controls/sailor_man_spike_record"
const RECORD_ACTION := &"sailor_man_spike_record"
const VOICE_KEY := "controls/sailor_man_voice"
const PITCH_UP_KEY := "controls/sailor_man_pitch_up"
const PITCH_DOWN_KEY := "controls/sailor_man_pitch_down"
const QUIEBRE_KEY := "controls/sailor_man_quiebre"
const REMATE_KEY := "controls/sailor_man_remate"
const VOICE_ACTION := &"sailor_man_voice"
const PITCH_UP_ACTION := &"sailor_man_pitch_up"
const PITCH_DOWN_ACTION := &"sailor_man_pitch_down"
const QUIEBRE_ACTION := &"sailor_man_quiebre"
const REMATE_ACTION := &"sailor_man_remate"
const REMO_ACTIONS: Array[StringName] = [
	VOICE_ACTION, PITCH_UP_ACTION, PITCH_DOWN_ACTION, QUIEBRE_ACTION, REMATE_ACTION,
]

const TUNABLES: Array[Dictionary] = [
	{
		"key": INPUT_SOURCE_KEY,
		"type": GameManifest.OPTION_CHOICE,
		"default": InputSource.AUTO,
		"title": "Input source",
		"description": "Auto prefers an available calibrated microphone, otherwise Remo. "
			+ "A microphone always needs your explicit Enable action. "
			+ "Hot-seat card choices stay per player for this session, not in this saved default.",
		"heading": "Voice input",
		"choices": [
			{"value": InputSource.AUTO, "title": INPUT_SOURCE_TITLES[InputSource.AUTO]},
			{"value": InputSource.MICROPHONE,
				"title": INPUT_SOURCE_TITLES[InputSource.MICROPHONE]},
			{"value": InputSource.REMO, "title": INPUT_SOURCE_TITLES[InputSource.REMO]},
		],
	},
	{
		"key": QUIET_MODE_KEY,
		"type": GameManifest.OPTION_TOGGLE,
		"default": false,
		"title": "Quiet Mode",
		"description": "Uses your measured speaking level and removes the carrying-level gate. "
			+ "Extra volume never earns points.",
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
	{
		"key": REST_REMINDERS_KEY,
		"type": GameManifest.OPTION_TOGGLE,
		"default": true,
		"title": "Voice-rest reminders",
		"description": "After six voiced microphone turns in ten minutes, offer a break "
			+ "or Remo between duels. Never changes your input automatically.",
		"heading": "Voice input",
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
	{
		"key": VOICE_KEY,
		"action": VOICE_ACTION,
		"default": KEY_SPACE,
		"title": "Voice",
		"description": "Hold to voice during a Remo call. Release for a breath.",
		"heading": "Remo controls",
	},
	{
		"key": PITCH_UP_KEY,
		"action": PITCH_UP_ACTION,
		"default": KEY_W,
		"title": "Pitch up",
		"description": "Glide upward while held. The up arrow is a fixed extra.",
		"heading": "Remo controls",
	},
	{
		"key": PITCH_DOWN_KEY,
		"action": PITCH_DOWN_ACTION,
		"default": KEY_S,
		"title": "Pitch down",
		"description": "Glide downward while held. The down arrow is a fixed extra.",
		"heading": "Remo controls",
	},
	{
		"key": QUIEBRE_KEY,
		"action": QUIEBRE_ACTION,
		"default": KEY_J,
		"title": "Quiebre / Break",
		"description": "Press to switch registers during a voiced Remo call.",
		"heading": "Remo controls",
	},
	{
		"key": REMATE_KEY,
		"action": REMATE_ACTION,
		"default": KEY_K,
		"title": "Remate / Finish",
		"description": "Release the virtual voice and score the Remo call.",
		"heading": "Remo controls",
	},
]
