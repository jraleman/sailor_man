extends RefCounted

## Original batched tropical banks for the practice chamber, not the later
## lake, cut, bridge or Pacific arenas.

const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")


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
