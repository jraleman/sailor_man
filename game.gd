extends RefCounted

## A playable grey-box duel, without advertising the unfinished canal voyage.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")


## Register entirely through data, without teaching the shell this game's name.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Sailor Man"
	game.tagline = "A voice / Remo duel against a synthetic practice skiff."
	game.menu_order = 10
	game.gameplay_scene_path = "res://games/sailor_man/gameplay.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.uses_shell_round_rules = false
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.stats_url = "https://deskcansaw.com"
	game.tutorial_video_path = "res://games/sailor_man/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/sailor_man/assets/video/tutorial_poster.webp"
	game.copy = {
		"instructions_headline": "Win two tandas against the practice skiff",
		"instructions_rules": (
			"Grey-box prototype with one explicitly synthetic rival, not a recorded "
			+ "salomero. Listen to its call, press Ready and wait for YA! "
			+ "Answer with Remo or an explicitly enabled microphone. The player calls "
			+ "tanda two. Win two tandas; ties go to the answerer. The chamber clock "
			+ "pauses inside performances. Retry costs no lives."
		),
		"instructions_solo_summary": (
			"Three judges prefer Quiebre, Aliento and Eco, with numbered paddles. "
			+ "Calls omit Eco. Repeat the rival's call once before answering. "
			+ "Use a comfortable voice; extra volume earns nothing. Marks are a game "
			+ "simplification, not cultural validation. Practice opens the full scorer."
		),
		"instructions_player_one_controls": (
			"After Ready and YA!, hold Voice, glide pitch, then Quiebre or Remate. "
			+ "Pad: A/RT, left stick, X/RB, B. Touch: hold/drag the ribbon, "
			+ "flick up or use Break, flick down to finish. Mic starts off."
		),
		"player_one_control_description": (
			"Remo: hold Voice, shape pitch, Break and Finish. Record uses the opt-in mic."
		),
		"single_player_description": "Best-of-three duel against one synthetic practice skiff.",
	}
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://games/sailor_man/assets/game-icon.svg"
	theme.accent = Color("f4b941")
	theme.light = Color("fbf2df")
	theme.plaque_color = Color("1f2a36")
	theme.background_top = Color("24494e")
	theme.background_bottom = Color("132329")
	game.theme = theme
	game.credits = [
		{"heading": "Game Design & Code", "lines": ["DeskCanSaw"]},
		{
			"heading": "Development status",
			"lines": [
				"Practice skiff and Remo use synthetic tones, not saloma recordings.",
				"Performer recordings and cultural review are still pending.",
			],
		},
	]
	return game
