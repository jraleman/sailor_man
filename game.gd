extends RefCounted

## Free toy-canal practice arenas, without advertising the unfinished voyage.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")


## Register entirely through data, without teaching the shell this game's name.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Sailor Man"
	game.tagline = "Duel a practice skiff, your Culebra echo, or a friend taking turns."
	game.menu_order = 10
	game.gameplay_scene_path = "res://games/sailor_man/gameplay.tscn"
	game.intro_scene_path = "res://games/sailor_man/intro.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.uses_shell_round_rules = false
	game.supports_multiplayer = true
	game.local_multiplayer_turns = true
	game.supports_cpu_opponent = false
	game.tunables = Options.TUNABLES
	game.control_bindings = Options.CONTROL_BINDINGS
	game.levels = Arenas.levels()
	game.characters = Options.CHARACTERS
	game.character_preview_scene_path = "res://games/sailor_man/character_preview.tscn"
	game.store_items = Options.STORE_ITEMS
	game.store_slots = Options.STORE_SLOTS
	game.store_currency = Options.STORE_CURRENCY
	game.store_preview_scene_path = "res://games/sailor_man/store_preview.tscn"
	game.gallery_exhibits = Options.GALLERY_EXHIBITS
	game.gallery_stage_scene_path = "res://games/sailor_man/gallery_stage.tscn"
	game.stats_url = "https://deskcansaw.com"
	game.share_art_scene_path = "res://games/sailor_man/share_art.tscn"
	game.tutorial_video_path = "res://games/sailor_man/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/sailor_man/assets/video/tutorial_poster.webp"
	game.copy = {
		"store_intro": "P1/P2 toy outfits. Earn Balboas in duels.",
		"gallery_intro": "Original models from free toy-canal practice. "
			+ "No voice capture, voyage gates or reviewed cultural assets.",
		"level_label": "Practice arena",
		"character_label": "Launch",
		"versus_confirm_title": "Pass the mic",
		"solo_confirm_description": (
			"All five practice arenas are free. Locks have a four-minute "
			+ "between-turn clock; open water is untimed. Use Remo or opt into "
			+ "a microphone after setup. Your Store outfit is cosmetic only. "
			+ "Production captains and campaign are pending."
		),
		"versus_confirm_description": (
			"Two humans take turns on one device. All five practice arenas are free "
			+ "and have no chamber timeout in hot seat. Choose each singer's own "
			+ "profile and input on their pass card; setup opens no microphone. "
			+ "Store outfits are separate for P1 and P2, with one shared Balboas wallet."
		),
		"instructions_headline": "Win two tandas by voice or Remo",
		"instructions_rules": (
			"Solo practice arenas have one explicitly synthetic rival, not a recorded "
			+ "salomero. Listen to its call, press Ready and wait for YA! "
			+ "Answer with Remo or an explicitly enabled microphone. The player calls "
			+ "tanda two. Win two tandas; ties go to the answerer. Locks have a chamber "
			+ "clock that pauses inside performances; open water is untimed between turns. "
			+ "Retry costs no lives. Culebra also offers Challenge your echo: make a fresh, "
			+ "unscored seed, then face its fixed contour in best-of-three. It returns after "
			+ "600 ms as a neutral tone, never recorded/live mic audio. "
			+ "Hot seat is two humans taking turns: P1 calls first, P2 calls tanda two. "
			+ "Pass the mic, choose your own profile/source, then Ready. Hot seat has no "
			+ "chamber deadline in any arena; every call still has its listening deadline. "
			+ "Campaign is pending.\n\n"
			+ "FIVE GAME MARKS\n\n"
			+ "Aliento: your longest continuous voiced span, capped at five seconds. "
			+ "Stop whenever comfortable; the cap is not a requirement.\n\n"
			+ "Quiebre: clean jumps between chest and high register. Remo's Break "
			+ "changes register; do not force your voice.\n\n"
			+ "Altura: pitch span relative to your source/profile, not absolute "
			+ "pitch in Hz. An unmeasured microphone band remains provisional.\n\n"
			+ "Remate: a falling glide or crisp finish. Grito belongs to this mark, "
			+ "not a sixth action.\n\n"
			+ "Eco: match the caller's relative pitch contour when answering. "
			+ "Calls omit Eco.\n\n"
			+ "These marks are a game simplification, not a cultural definition. "
			+ "Extra volume earns nothing. Quiet Mode removes the carrying-level gate; "
			+ "Remo lets you practise without using your voice."
		),
		"instructions_solo_summary": (
			"Three judges (five in the Pacific) show numbered paddles and their tastes. "
			+ "Calls omit Eco. Repeat the rival's call once before answering; "
			+ "open-water Repeat costs no clock time. "
			+ "Use a comfortable voice; extra volume earns nothing. Marks are a game "
			+ "simplification, not cultural validation. Practice opens the full scorer."
		),
		"instructions_versus_summary": (
			"Two humans, one device, all five free-practice arenas. P1 calls tanda one; "
			+ "P2 answers, then leads tanda two. Three judges (five in the Pacific) "
			+ "score both actual performances. Ties go to the answerer. "
			+ "Choose a separate calibration for each singer, or use Remo. "
			+ "Repeat plays the completed call's contour as a neutral tone, never recorded "
			+ "voice. No chamber timeout, live mic monitoring or saved tracks."
		),
		"instructions_player_one_controls": (
			"After Ready and YA!, hold Voice, glide pitch, then Quiebre or Remate. "
			+ "Pad: A/RT, left stick, X/RB, B. Touch: hold/drag the ribbon, "
			+ "flick up or use Break, flick down to finish. Mic starts off."
		),
		"player_one_control_description": (
			"Remo: hold Voice, shape pitch, Break and Finish. Record uses the opt-in mic."
		),
		"instructions_player_two_controls": (
			"On your Pass the mic card, choose your profile and input. After Ready and "
			+ "YA!, use the same keyboard/gamepad/touch Remo controls as P1, "
			+ "or explicitly enable the shared microphone. Only the named singer scores."
		),
		"player_two_control_description": (
			"Take your turn with the shared Remo controls or your own microphone profile."
		),
		"multiplayer_description": (
			"Two-human hot seat. Pass the mic or share Remo, with a separate profile "
			+ "for each singer. All five practice arenas; no chamber timeout."
		),
		"single_player_description": (
			"Duel a synthetic practice skiff. Culebra also offers a seeded self-echo challenge."
		),
	}
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://games/sailor_man/assets/game-icon.png"
	theme.accent = Color("f4b941")
	theme.light = Color("fbf2df")
	theme.plaque_color = Color("1f2a36")
	theme.background_top = Color("24494e")
	theme.background_bottom = Color("132329")
	theme.style_share_card = true
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
