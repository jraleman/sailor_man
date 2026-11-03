extends RefCounted

## Canonical cosmetic ids cross view boundaries; no voice or live store state
## belongs in a rig or a frozen share portrait.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")


## A preview advertises only a declared item, ignoring injected model/colour data.
static func item(id: String) -> Dictionary:
	for declared: Dictionary in Options.STORE_ITEMS:
		if str(declared["id"]) == id:
			return declared.duplicate(true)
	return {}


## Reject unknown kinds and mismatched ids before touching any existing geometry.
static func validate(outfit: Dictionary) -> String:
	for kind: Variant in outfit:
		if not Options.DEFAULT_OUTFIT.has(kind) or not outfit[kind] is String:
			return "Launch outfits need declared kinds and string cosmetic ids."
		var declared := item(outfit[kind])
		if declared.is_empty() or str(declared["kind"]) != str(kind):
			return "Unknown %s cosmetic: %s." % [kind, outfit[kind]]
	return ""


## Empty input is the actual plain launch, not a randomly selected starter hat.
static func complete(outfit: Dictionary) -> Dictionary:
	var result := Options.DEFAULT_OUTFIT.duplicate(true)
	result.merge(outfit, true)
	return result


## Controllers pass the store explicitly; builders never resolve an autoload.
static func equipped(store: Node, seat: int) -> Dictionary:
	assert(seat in [0, 1])
	var result := Options.DEFAULT_OUTFIT.duplicate(true)
	if store != null:
		for kind: String in result:
			var id := str(store.call("equipped_id", Options.GAME_ID,
				"p%d_%s" % [seat + 1, kind]))
			if not id.is_empty():
				result[kind] = id
	return result


## Accessible words accompany the actual player's outfit and identity plaque.
static func describe(outfit: Dictionary) -> String:
	var titles := PackedStringArray()
	for kind: String in Options.DEFAULT_OUTFIT:
		titles.append(str(item(str(outfit[kind]))["title"]))
	return ", ".join(titles)


## Hats and bow ornaments join the hull's existing single lit surface.
static func decorate(builder: Builder, outfit: Dictionary, facing: float, paint: Color) -> void:
	match str(outfit["hat"]):
		"hat_deck_cap":
			builder.ellipsoid(Vector3(0, 1.44, -0.79),
				Vector3(0.44, 0.21, 0.40), Style.INK)
			builder.rounded_box(Vector3(facing * 0.18, 1.42, -0.79),
				Vector3(0.26, 0.035, 0.32), 0.012, Style.CREAM)
		"hat_sun_hat":
			builder.cylinder(Vector3(0, 1.42, -0.79), 0.37, 0.035,
				Style.WOOD.lightened(0.3))
			builder.cylinder(Vector3(0, 1.52, -0.79), 0.20, 0.18,
				Style.WOOD.lightened(0.3), Vector3.ZERO, 16, 0.7)
			builder.cylinder(Vector3(0, 1.47, -0.79), 0.205, 0.04, paint)
	match str(outfit["bow"]):
		"bow_fish":
			var at := Vector3(0, 0.55, -1.78)
			builder.ellipsoid(at, Vector3(0.28, 0.38, 0.58), Style.SUN)
			for side: float in [-1.0, 1.0]:
				builder.ellipsoid(at + Vector3(side * 0.137, 0.04, -0.14),
					Vector3(0.04, 0.04, 0.04), Style.INK, 6)
				var a := at + Vector3(side * 0.03, 0, 0.20)
				var b := at + Vector3(side * 0.03, 0.20, 0.38)
				var c := at + Vector3(side * 0.03, -0.16, 0.38)
				builder.triangle(a, b, c, Style.WOOD)
				builder.triangle(c, b, a, Style.WOOD)
		"bow_star":
			var center := Vector3(0, 0.60, -1.85)
			for index in 10:
				var a := _star_point(index)
				var b := _star_point((index + 1) % 10)
				var front := Vector3(0, 0, -0.035)
				builder.triangle(center + front, center + b + front,
					center + a + front, Style.SUN)
				builder.triangle(center - front, center + a - front,
					center + b - front, Style.SUN)
				builder.quad(center + a + front, center + b + front,
					center + b - front, center + a - front, Style.WOOD)


## Decorations leave the original blue/red pennant in place.
static func pennant(builder: Builder, id: String, paint: Color) -> void:
	if id == "pennant_stripes":
		for row in 2:
			var y := 2.04 + float(row) * 0.15
			var width := 0.27 if row == 0 else 0.48
			for side: float in [-1.0, 1.0]:
				var z := 0.95 + side * 0.004
				var a := Vector3(-0.78, y + 0.025, z)
				var b := Vector3(-0.78, y - 0.025, z)
				var c := Vector3(-0.78 + width, y - 0.025, z)
				var d := Vector3(-0.78 + width, y + 0.025, z)
				if side > 0.0:
					builder.quad(a, b, c, d, Style.CREAM)
				else:
					builder.quad(d, c, b, a, Style.CREAM)
	elif id == "pennant_bunting":
		var from := Vector3(-0.80, 2.64, 0.95)
		var to := Vector3(0.76, 2.57, 0.95)
		builder.beam(Vector3(-0.83, 2.34, 0.95), from, 0.035, Style.WOOD)
		builder.beam(Vector3(0.76, 1.19, 0.95), to, 0.028, Style.WOOD)
		builder.beam(from, to, 0.018, Style.WOOD)
		for index in 4:
			var at := from.lerp(to, float(index + 1) / 5.0)
			var color := paint if index % 2 == 0 else Style.SUN
			var a := at + Vector3(-0.10, 0, 0)
			var b := at + Vector3(0, -0.18, 0)
			var c := at + Vector3(0.10, 0, 0)
			builder.triangle(a, b, c, color)
			builder.triangle(c, b, a, color)


static func _star_point(index: int) -> Vector3:
	var angle := PI * 0.5 + float(index) * TAU / 10.0
	var radius := 0.27 if index % 2 == 0 else 0.115
	return Vector3(cos(angle), sin(angle), 0) * radius
