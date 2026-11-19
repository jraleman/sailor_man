extends RefCounted

## Original plain practice launches only: no production captains or recorded crews.
const Helpers = preload("res://tools/cover_art_helpers.gd")
const Boat = preload("res://games/sailor_man/world/boat_rig.gd")


## Nautical printing keeps the practice scope explicit.
static func design() -> Dictionary:
	return {
		"paper": Color("183e4e"), "ink": Color("fff0cd"), "accent": Color("4dbbb2"),
		"motif": "waves", "camera": Vector3(148, 23, 7),
		"photo": Rect2(-15, 330, 1054, 610),
		"lettering": [
			{"text": "SAILOR", "at": Vector2(54, 198), "size": 207},
			{"text": "MAN", "at": Vector2(58, 363), "size": 185, "color": Color("f8d376")},
			{"text": "CANAL PRACTICE", "at": Vector2(64, 979), "size": 42, "font": "mono"},
		],
	}


## These display-only rigs never open audio, microphone or profile data.
static func build(parent: Node) -> Node:
	var root := Helpers.group(parent)
	Helpers.place(root, Boat.new(0, "P1"), Vector3(-0.3, 0, 0))
	Helpers.place(root, Boat.new(1, "P2"), Vector3(-2.7, -0.2, -1.8),
		Vector3(0, -15, 0), 0.55)
	return root
