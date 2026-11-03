extends RefCounted

## Free prototype practice locations, not the later gated voyage levels.
## Rule data stays independent of geometry, input and the shared framework.

const GATUN := "gatun"
const LAKE := "lake"
const CULEBRA := "culebra"
const PEDRO_MIGUEL := "pedro_miguel"
const PACIFIC := "pacific"
const ENTRIES: Array[Dictionary] = [
	{
		"id": GATUN, "title": "Gat\u00fan practice lock",
		"description": "Rising chamber water and a four-minute between-turn clock. "
			+ "Three judges; one synthetic practice skiff.",
		"caption": "Gat\u00fan practice lock - a toy canal, not a simulator.",
		"clock": true, "descending": false, "judges": 3,
		"sky": Color("a5cbc5"),
	},
	{
		"id": LAKE, "title": "Lago Gat\u00fan",
		"description": "Jungle islands, distant ships and canopy howlers. "
			+ "Untimed between turns; Repeat is free. Synthetic practice rival.",
		"caption": "Lago Gat\u00fan - open-water practice; Repeat costs no clock time.",
		"clock": false, "descending": false, "judges": 3,
		"sky": Color("acd4d4"),
	},
	{
		"id": CULEBRA, "title": "Corte Culebra",
		"description": "Terraced cut and a toy cable-stayed bridge. "
			+ "Untimed skiff practice, with an optional challenge against your own seed call.",
		"caption": "Corte Culebra - skiff practice or a separate, seeded self-echo challenge.",
		"clock": false, "descending": false, "judges": 3,
		"sky": Color("c4d2c1"),
	},
	{
		"id": PEDRO_MIGUEL, "title": "Pedro Miguel",
		"description": "A descending lock chamber in cool evening colours. "
			+ "Four-minute between-turn clock, three judges and a synthetic rival.",
		"caption": "Pedro Miguel - descending toy lock; the chamber clock still applies.",
		"clock": true, "descending": true, "judges": 3,
		"sky": Color("708f9e"),
	},
	{
		"id": PACIFIC, "title": "Miraflores & the Pacific",
		"description": "Arched bridge, causeway, skyline and festival boats. "
			+ "Five judges and untimed synthetic-skiff practice.",
		"caption": "Pacific practice festival - five judges, no between-turn deadline.",
		"clock": false, "descending": false, "judges": 5,
		"sky": Color("c7d7d4"),
	},
]


## The shared selector gets only its existing data contract, without new gates.
static func levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		result.append({
			"id": entry["id"], "title": entry["title"], "description": entry["description"],
			"icon": "res://games/sailor_man/assets/levels/%s.png" % entry["id"],
		})
	return result


## A bad selection must remain an explicit error, not another plausible arena.
static func arena(id: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if str(entry["id"]) == id:
			return entry.duplicate(true)
	push_error("Sailor Man: unknown practice arena '%s'." % id)
	return {}
