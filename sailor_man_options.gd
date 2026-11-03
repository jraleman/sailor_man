extends RefCounted

## Constants-only input, original prototype cosmetics and model presentation.
## Production rivals, campaign and recorded captains remain undeclared.

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

## One prototype entry mounts the real player launch on the shared setup plinth.
const CHARACTER_ID := "practice_launch"
const CHARACTERS: Array[Dictionary] = [
	{
		"id": CHARACTER_ID, "title": "Practice launch",
		"description": "Your player launch and plain toy crew. "
			+ "A prototype model, not a named or recorded captain.",
	},
]

const DEFAULT_OUTFIT := {
	"hat": "hat_none", "pennant": "pennant_plain",
	"paint": "paint_identity", "bow": "bow_none",
}
const STORE_CURRENCY := {
	"name": "Balboa", "plural": "Balboas", "points_per_score": 0.1,
	"round_bonus": 0, "win_bonus": 5, "max_per_round": 0,
}
const STORE_SLOTS: Array[Dictionary] = [
	{"id": "p1_hat", "kind": "hat", "title": "P1 hat"},
	{"id": "p1_pennant", "kind": "pennant", "title": "P1 pennant"},
	{"id": "p1_paint", "kind": "paint", "title": "P1 hull"},
	{"id": "p1_bow", "kind": "bow", "title": "P1 bow"},
	{"id": "p2_hat", "kind": "hat", "title": "P2 hat"},
	{"id": "p2_pennant", "kind": "pennant", "title": "P2 pennant"},
	{"id": "p2_paint", "kind": "paint", "title": "P2 hull"},
	{"id": "p2_bow", "kind": "bow", "title": "P2 bow"},
]
const STORE_ITEMS: Array[Dictionary] = [
	{
		"id": "hat_none", "kind": "hat", "title": "Plain crew", "heading": "Toy hats",
		"description": "The original bare-headed toy crew. No named or recorded captain.",
		"badge": "BARE", "color": Color("fbf2df"), "price": 0, "default": true,
	},
	{
		"id": "hat_deck_cap", "kind": "hat", "title": "Deck cap", "heading": "Toy hats",
		"description": "An original little cap and cream peak. Cosmetic, not traditional dress.",
		"badge": "CAP", "color": Color("1f2a36"), "price": 8,
	},
	{
		"id": "hat_sun_hat", "kind": "hat", "title": "Toy sun hat", "heading": "Toy hats",
		"description": "A broad toy brim with the singer's blue or red band.",
		"badge": "SUN", "color": Color("bd8555"), "price": 12,
	},
	{
		"id": "pennant_plain", "kind": "pennant", "title": "Player pennant",
		"heading": "Pennants",
		"description": "The original blue or red flag. P1/P2 labels stay on every launch.",
		"badge": "FLAG", "color": Color("fbf2df"), "price": 0, "default": true,
	},
	{
		"id": "pennant_stripes", "kind": "pennant", "title": "Cream stripes",
		"heading": "Pennants",
		"description": "Two plain cream bars on your player-coloured pennant.",
		"badge": "BARS", "color": Color("fbf2df"), "price": 8,
	},
	{
		"id": "pennant_bunting", "kind": "pennant", "title": "Toy bunting",
		"heading": "Pennants",
		"description": "Four little flags above the unchanged player pennant. No cultural pattern.",
		"badge": "FEST", "color": Color("f4b941"), "price": 12,
	},
	{
		"id": "paint_identity", "kind": "paint", "title": "Player hull",
		"heading": "Hull finishes",
		"description": "The original blue P1 or red P2 hull. Shelf previews show P1.",
		"badge": "HULL", "color": Color("5c8fe6"), "price": 0, "default": true,
	},
	{
		"id": "paint_cream_band", "kind": "paint", "title": "Cream lower hull",
		"heading": "Hull finishes",
		"description": "A cream lower hull, keeping the upper blue/red player band.",
		"badge": "CREAM", "color": Color("fbf2df"), "price": 10,
	},
	{
		"id": "paint_deep_hull", "kind": "paint", "title": "Deep lower hull",
		"heading": "Hull finishes",
		"description": "A darker lower hull in your own blue/red colour, not another player's.",
		"badge": "DEEP", "color": Color("24494e"), "price": 14,
	},
	{
		"id": "bow_none", "kind": "bow", "title": "Plain bow",
		"heading": "Bow decorations",
		"description": "The original launch bow without a figurehead.",
		"badge": "BOW", "color": Color("bd8555"), "price": 0, "default": true,
	},
	{
		"id": "bow_fish", "kind": "bow", "title": "Toy fish",
		"heading": "Bow decorations",
		"description": "An original golden toy fish. It never changes the voice or judges.",
		"badge": "FISH", "color": Color("f4b941"), "price": 12,
	},
	{
		"id": "bow_star", "kind": "bow", "title": "Bow star",
		"heading": "Bow decorations",
		"description": "A solid five-point toy star on the launch's bow.",
		"badge": "STAR", "color": Color("f4b941"), "price": 14,
	},
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

const GALLERY_EXHIBITS: Array[Dictionary] = [
	{
		"id": "launch", "title": "P1 practice launch", "badge": "P1",
		"heading": "The launches", "framing_yaw": 2.65, "framing_pitch": 0.35,
		"description": "The original blue launch used by the first singer.",
		"facts": ["Plain toy crew, not a named or recorded captain.",
			"The same hull, cabin, fenders and crew mesh used in a duel."],
	},
	{
		"id": "skiff", "title": "Synthetic practice skiff", "badge": "CPU",
		"heading": "The launches", "framing_yaw": -2.65, "framing_pitch": 0.35,
		"description": "The red launch that carries the explicitly synthetic practice rival.",
		"facts": ["No salomero recording or production rival crew.",
			"The exhibits play no voices or duel scoring cues."],
	},
	{
		"id": "hot_seat", "title": "Two-human launches", "badge": "DUO",
		"heading": "The launches", "framing_yaw": 3.14, "framing_pitch": 0.40,
		"description": "The same blue and red rigs with the real P1 and P2 seat labels.",
		"facts": ["Shared controls, separate singers in the playable hot-seat duel.",
			"This exhibit reads no voice profile or performance."],
	},
	{
		"id": "mula", "title": "Mula on rails", "badge": "RAIL",
		"heading": "Lock and jungle details",
		"framing_yaw": 2.60, "framing_pitch": 0.35,
		"description": "The original yellow rail-side toy used beside both practice locks.",
		"facts": ["The same wheel, cabin and chassis builder as the chamber.",
			"A compressed toy interpretation, not an engineering model."],
	},
	{
		"id": "gate", "title": "Practice lock gate", "badge": "GATE",
		"heading": "Lock and jungle details",
		"framing_yaw": 3.45, "framing_pitch": 0.30,
		"description": "Two V-shaped leaves built from the actual practice gate geometry.",
		"facts": ["The same beams and braces used in the lock.",
			"No chamber clock or water-level simulation runs in the gallery."],
	},
	{
		"id": "howler", "title": "Canopy howler", "badge": "MONKEY",
		"heading": "Lock and jungle details",
		"framing_yaw": 0.45, "framing_pitch": 0.20,
		"description": "One of the original clay-like monkeys from the lake's canopy.",
		"facts": ["The same body, arms and curled tail builder used on the islands.",
			"An unscored scenery model, not the planned campaign interlude."],
	},
	{
		"id": "gatun", "title": "Gat\u00fan practice diorama", "badge": "GATUN",
		"heading": "Five free practice arenas",
		"description": "The current toy chamber, tropical banks, mulas and two launches.",
		"facts": ["Parked at the rising lock's initial water height.",
			"Free prototype access; no voyage unlock or authority branding."],
	},
	{
		"id": "lake", "title": "Lago Gat\u00fan diorama", "badge": "LAKE",
		"heading": "Five free practice arenas",
		"description": "The current lake islands, canopy howlers and distant ships.",
		"facts": ["The actual open-water practice meshes, with drift parked.",
			"Compressed toy scenery, not a factual geographic reconstruction."],
	},
	{
		"id": "culebra", "title": "Corte Culebra diorama", "badge": "CUT",
		"heading": "Five free practice arenas",
		"description": "The current red-earth terraces and cable-stayed toy bridge.",
		"facts": ["The same scenery used by skiff and self-echo practice.",
			"No seed, pitch track or live microphone data is used here."],
	},
	{
		"id": "pedro_miguel", "title": "Pedro Miguel diorama", "badge": "LOCK",
		"heading": "Five free practice arenas",
		"description": "The current descending-lock chamber with its small toy town.",
		"facts": ["Parked at the descending lock's initial water height.",
			"The plain spectators imply no culturally reviewed dress or characters."],
	},
	{
		"id": "pacific", "title": "Miraflores & Pacific diorama", "badge": "SEA",
		"heading": "Five free practice arenas",
		"description": "The current arched bridge, skyline, causeway and festival bunting.",
		"facts": ["The actual five-judge practice arena's original scenery.",
			"No campaign completion, recorded Maestra or cultural review is implied."],
	},
]
