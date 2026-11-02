extends RefCounted

## Discoverable development scaffold; it does not pretend the voyage is playable.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")


## Register entirely through data, without teaching the shell this game's name.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Sailor Man"
	game.tagline = "Voice / Remo scorer prototype - the voyage is still in development."
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
		"instructions_headline": "Try the shared saloma scorer",
		"instructions_rules": (
			"Development prototype, not a duel. Start a Remo call and draw with "
			+ "buttons or touch, without a microphone. Or explicitly enable a mic, "
			+ "finish the room check and record a comfortable call. Extra volume "
			+ "earns nothing. Remo previews use a labelled synthetic tone."
		),
		"instructions_solo_summary": (
			"Compare Aliento, Quiebre, Altura and Remate. Keep a call as a "
			+ "reference to test Eco on your next answer. These marks are a game "
			+ "simplification; authentic-voice validation is still pending."
		),
		"instructions_player_one_controls": (
			"Start Remo, hold Voice, glide pitch, then Quiebre or Remate. "
			+ "Gamepad and touch also work. Record is for the opt-in microphone."
		),
		"player_one_control_description": (
			"Remo: hold Voice, shape pitch, Break and Finish. Record uses the opt-in mic."
		),
		"single_player_description": "Explore the scorer and pitch ribbon; no rivals yet.",
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
				"Synthetic pitch tracks are test fixtures, not saloma recordings.",
				"Performer recordings and cultural review are still pending.",
			],
		},
	]
	return game
