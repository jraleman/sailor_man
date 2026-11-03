extends RefCounted

## Original tabletop landmarks, compressed for a readable toy canal rather
## than a factual reconstruction. Every detail is ordinary batched geometry.

const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")


## A location owns its scenery; the view supplies water, singers and lighting.
static func build(parent: Node3D, arena: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "ArenaScenery"
	parent.add_child(root)
	if bool(arena["clock"]):
		lock_banks(root)
		if str(arena["id"]) == Arenas.PEDRO_MIGUEL:
			_pedro_town(root)
		return root
	var plinth := Builder.new()
	plinth.rounded_box(Vector3(0, -1.72, 0), Vector3(20, 0.65, 16.8),
		0.24, Style.WOOD)
	plinth.build(root, "Tabletop", Style.material())
	match str(arena["id"]):
		Arenas.LAKE:
			_lake(root)
		Arenas.CULEBRA:
			_cut(root)
		Arenas.PACIFIC:
			_pacific(root)
	return root


## A wooden plinth and palms make the lock read as a tabletop place.
static func lock_banks(parent: Node3D) -> MeshInstance3D:
	var builder := Builder.new()
	builder.rounded_box(Vector3(0, -1.72, 0), Vector3(20, 0.65, 16.8),
		0.24, Style.WOOD)
	for side: float in [-1.0, 1.0]:
		builder.rounded_box(Vector3(side * 8.6, 0.05, 0), Vector3(3.4, 3.0, 15.0),
			0.45, Style.JUNGLE.darkened(0.12))
		for index in 4:
			var at := Vector3(side * (8.55 + float(index % 2) * 0.65),
				1.55, -5.5 + float(index) * 3.7)
			_palm(builder, at, side, float(index) * 0.7)
	for index in 5:
		var at := Vector3(-8.0 + float(index) * 4.0, 0.0, -8.0)
		builder.ellipsoid(at, Vector3(6, 4.5 + float(index % 2), 3),
			Style.JUNGLE.lightened(0.10), 10)
	return builder.build(parent, "TropicalBanks", Style.material())


static func _lake(parent: Node3D) -> void:
	var islands := Builder.new()
	var howlers := Builder.new()
	for index in 5:
		var side := -1.0 if index % 2 == 0 else 1.0
		var at := Vector3(side * (6.2 + float(index % 2)), -0.5,
			-5.7 + float(index / 2) * 4.1)
		islands.ellipsoid(at, Vector3(4.0, 1.6, 3.4), Style.JUNGLE.darkened(0.18))
		for tree in 3:
			var trunk := at + Vector3(float(tree - 1) * 0.85, 0.3,
				float(tree % 2) * 0.75 - 0.4)
			islands.beam(trunk, trunk + Vector3.UP * 2.4, 0.20, Style.WOOD)
			islands.ellipsoid(trunk + Vector3.UP * 2.65, Vector3(2.2, 1.6, 2.2),
				Style.JUNGLE.lightened(float(tree % 2) * 0.14))
			if tree == 1:
				islands.beam(trunk + Vector3.UP * 1.95,
					trunk + Vector3(0, 1.95, 0.90), 0.09, Style.WOOD)
				howler(howlers, trunk + Vector3(0, 1.45, 0.65))
	_landmark(islands, parent, "LakeIslands")
	howlers.build(parent, "HowlerCanopy", Style.material())
	var ships := Builder.new()
	for index in 2:
		var at := Vector3(-3.9 + float(index) * 7.3, -0.05, -5.8)
		ships.rounded_box(at, Vector3(1.05, 0.55, 3.1), 0.15, Style.INK)
		for row in 3:
			ships.box(at + Vector3(0, 0.5, -0.8 + float(row) * 0.72),
				Vector3(0.86, 0.6, 0.65), Style.RED if row % 2 == 0 else Style.CANAL)
		ships.box(at + Vector3(0, 0.8, 1.0), Vector3(0.90, 1.0, 0.7), Style.CREAM)
		ships.box(at + Vector3(0, 0.95, 1.36), Vector3(0.70, 0.15, 0.02), Style.INK)
	ships.build(parent, "DistantShips", Style.material())


## Gallery close-ups use the same monkey as the real lake canopy.
static func howler(builder: Builder, at: Vector3) -> void:
	var fur := Color("75452f")
	builder.ellipsoid(at, Vector3(0.40, 0.60, 0.35), fur)
	builder.ellipsoid(at + Vector3(0, 0.33, 0.05), Vector3(0.36, 0.36, 0.35), fur)
	builder.ellipsoid(at + Vector3(0, 0.28, 0.20), Vector3(0.24, 0.18, 0.12),
		fur.darkened(0.32))
	for side: float in [-1.0, 1.0]:
		builder.beam(at + Vector3(side * 0.16, 0.17, 0),
			at + Vector3(side * 0.32, 0.50, -0.05), 0.08, fur)
		builder.beam(at + Vector3(side * 0.10, -0.18, 0),
			at + Vector3(side * 0.22, -0.35, 0.13), 0.10, fur)
	builder.beam(at + Vector3(0, -0.15, -0.12),
		at + Vector3(0.30, -0.26, -0.30), 0.06, fur)
	builder.torus(at + Vector3(0.31, -0.08, -0.30), 0.10, 0.16, fur)


static func _cut(parent: Node3D) -> void:
	var terraces := Builder.new()
	for side: float in [-1.0, 1.0]:
		for step in 4:
			var at := Vector3(side * (6.7 + float(step) * 0.45),
				-0.8 + float(step) * 0.72, 0)
			terraces.rounded_box(at, Vector3(4.2 - float(step) * 0.7, 0.85, 15.0),
				0.12, Color("a85e42").lightened(float(step % 2) * 0.12))
			terraces.box(at + Vector3(0, 0.43, 0),
				Vector3(3.9 - float(step) * 0.7, 0.035, 14.8),
				Style.JUNGLE.darkened(0.10))
	terraces.build(parent, "CutTerraces", Style.material())
	var bridge := Builder.new()
	var z := -6.1
	_bridge_deck(bridge, z)
	for x: float in [-4.6, 4.6]:
		for depth: float in [-0.48, 0.48]:
			bridge.beam(Vector3(x, -0.9, z + depth),
				Vector3(x, 5.0, z + depth), 0.26, Style.CREAM)
		bridge.beam(Vector3(x, 4.8, z - 0.48), Vector3(x, 4.8, z + 0.48),
			0.22, Style.CREAM)
		for index in 9:
			var end := -8.6 + float(index) * 2.15
			if absf(end - x) < 0.5:
				continue
			for depth: float in [-0.45, 0.45]:
				bridge.beam(Vector3(x, 4.75, z + depth),
					Vector3(end, 2.23, z + depth), 0.038, Style.SUN)
	_landmark(bridge, parent, "CentennialBridge")


static func _pedro_town(parent: Node3D) -> void:
	var town := Builder.new()
	for index in 5:
		var at := Vector3(-7.2 + float(index) * 3.5, 1.85, -7.3)
		town.box(at, Vector3(1.2, 0.95, 0.85), Style.CREAM.darkened(0.12))
		town.box(at + Vector3(0, 0.55, 0), Vector3(1.4, 0.20, 1.0), Style.RED)
		town.box(at + Vector3(0, 0, 0.43), Vector3(0.30, 0.45, 0.015), Style.SUN)
	town.build(parent, "PedroMiguelTown", Style.material())


static func _pacific(parent: Node3D) -> void:
	var shore := Builder.new()
	shore.rounded_box(Vector3(7.7, -0.45, 1.0), Vector3(2.3, 0.85, 13.3),
		0.25, Style.CONCRETE)
	shore.box(Vector3(7.7, 0.01, 1.0), Vector3(1.1, 0.06, 13.0), Style.CREAM)
	for index in 4:
		_palm(shore, Vector3(8.15, 0.0, -3.4 + float(index) * 2.7), 1.0, 0.4)
	shore.build(parent, "PacificCauseway", Style.material())
	var skyline := Builder.new()
	for index in 12:
		var height := 1.4 + float((index * 7) % 5) * 0.44
		var at := Vector3(-8.1 + float(index) * 1.25, -0.8 + height * 0.5, -7.5)
		skyline.box(at, Vector3(0.8, height, 0.85),
			Color("9cb5b6").lightened(float(index % 3) * 0.07))
		skyline.box(at + Vector3(0, height * 0.26, 0.432),
			Vector3(0.65, 0.06, 0.012), Style.CREAM.darkened(0.15))
	skyline.build(parent, "PacificSkyline", Style.material())
	var bridge := Builder.new()
	var z := -4.9
	_bridge_deck(bridge, z)
	for depth: float in [-0.47, 0.47]:
		for index in 16:
			var t := float(index) / 16.0
			var next := float(index + 1) / 16.0
			var a := Vector3(lerpf(-8.7, 8.7, t), -0.5 + sin(PI * t) * 3.5, z + depth)
			var b := Vector3(lerpf(-8.7, 8.7, next),
				-0.5 + sin(PI * next) * 3.5, z + depth)
			bridge.beam(a, b, 0.17, Style.CREAM)
			bridge.beam(a, Vector3(a.x, 2.12, a.z), 0.065, Style.INK)
			bridge.beam(a, Vector3(b.x, 2.12, b.z), 0.045, Style.CREAM)
	_landmark(bridge, parent, "BridgeOfTheAmericas")
	_festival(parent)


static func _bridge_deck(builder: Builder, z: float) -> void:
	builder.box(Vector3(0, 2.1, z), Vector3(18.4, 0.22, 1.05), Style.CONCRETE)
	for depth: float in [-0.5, 0.5]:
		builder.beam(Vector3(-9.1, 2.35, z + depth),
			Vector3(9.1, 2.35, z + depth), 0.055, Style.INK)
	builder.box(Vector3(0, 2.215, z), Vector3(18.0, 0.01, 0.045), Style.SUN)


static func _festival(parent: Node3D) -> void:
	var boats := Builder.new()
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 6.0, -0.05, 2.8)
		boats.rounded_box(at, Vector3(1.1, 0.38, 2.45), 0.15, Style.CREAM)
		boats.box(at + Vector3(0, 0.33, 0), Vector3(0.87, 0.3, 1.6), Style.WOOD)
		for z: float in [-0.85, 0.85]:
			boats.beam(at + Vector3(0, 0.3, z), at + Vector3(0, 1.45, z),
				0.06, Style.INK)
		boats.beam(at + Vector3(0, 1.45, -0.85),
			at + Vector3(0, 1.45, 0.85), 0.035, Style.INK)
		for flag in 5:
			var z := -0.72 + float(flag) * 0.29
			var tip := at + Vector3(0, 1.11, z + 0.12)
			boats.triangle(at + Vector3(0, 1.44, z),
				at + Vector3(0, 1.44, z + 0.24), tip,
				Style.SUN if flag % 2 == 0 else Style.RED)
	boats.build(parent, "FestivalBoatsAndBunting", Style.material())


static func _landmark(builder: Builder, parent: Node3D, name: String) -> void:
	var mesh := builder.build(parent, name, Style.material())
	mesh.set_meta("frame_landmark", true)


static func _palm(builder: Builder, at: Vector3, side: float, phase: float) -> void:
	var middle := at + Vector3(-side * 0.18, 1.55, 0.08)
	var crown := at + Vector3(-side * 0.55, 3.1, 0.16)
	builder.beam(at, middle, 0.19, Style.WOOD)
	builder.beam(middle, crown, 0.14, Style.WOOD.lightened(0.12))
	for index in 6:
		var angle := phase + TAU * float(index) / 6.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var flank := Vector3(-direction.z, 0, direction.x) * 0.34
		var shoulder := crown + direction * 0.95 + Vector3.UP * 0.12
		var tip := crown + direction * 1.9 + Vector3.DOWN * 0.45
		var color := Style.JUNGLE.lightened(0.12 + float(index % 2) * 0.12)
		builder.triangle(crown, shoulder + flank, tip, color)
		builder.triangle(crown, tip, shoulder - flank, color)
