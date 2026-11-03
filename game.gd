extends RefCounted

## Free toy-canal practice arenas, without advertising the unfinished voyage.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")


## Register entirely through data, without teaching the shell this game's name.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Sailor Man"
	game.tagline = "Duel a practice skiff, or challenge your own echo in Culebra."
	game.menu_order = 10
	game.gameplay_scene_path = "res://games/sailor_man/gameplay.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.uses_shell_round_rules = false
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.levels = Arenas.levels()
	game.stats_url = "https://deskcansaw.com"
	game.tutorial_video_path = "res://games/sailor_man/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/sailor_man/assets/video/tutorial_poster.webp"
	game.copy = {
		"level_label": "Practice arena",
		"instructions_headline": "Win two tandas by voice or Remo",
		"instructions_rules": (
			"Free practice arenas with one explicitly synthetic rival, not a recorded "
			+ "salomero. Listen to its call, press Ready and wait for YA! "
			+ "Answer with Remo or an explicitly enabled microphone. The player calls "
			+ "tanda two. Win two tandas; ties go to the answerer. Locks have a chamber "
			+ "clock that pauses inside performances; open water is untimed between turns. "
			+ "Retry costs no lives. Culebra also offers Challenge your echo: make a fresh, "
			+ "unscored seed, then face its fixed contour in best-of-three. It returns after "
			+ "600 ms as a neutral tone, never recorded/live mic audio. Campaign is pending."
		),
		"instructions_solo_summary": (
			"Three judges (five in the Pacific) show numbered paddles and their tastes. "
			+ "Calls omit Eco. Repeat the rival's call once before answering; "
			+ "open-water Repeat costs no clock time. "
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
		"single_player_description": (
			"Duel a synthetic practice skiff. Culebra also offers a seeded self-echo challenge."
		),
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
