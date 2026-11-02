extends Node3D

## A compressed toy Gatun chamber, not a simulator or an authority-branded model.
## Water and tow lines follow presentation state without owning any round rules.

const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")
const WATER_LOW := -0.60
const WATER_HIGH := 0.25

var water: MeshInstance3D
var tow_anchors: Array[Vector3] = []
var _tethers: MultiMeshInstance3D


func _init() -> void:
	var builder := Builder.new()
	for side: float in [-1.0, 1.0]:
		builder.rounded_box(Vector3(side * 6.05, 0.2, 0), Vector3(1.15, 3.8, 13.0),
			0.12, Style.CONCRETE)
		builder.rounded_box(Vector3(side * 6.65, 2.13, 0), Vector3(2.4, 0.26, 13.2),
			0.08, Style.CREAM)
		for rail in [6.63, 7.12]:
			builder.box(Vector3(side * rail, 2.30, 0), Vector3(0.06, 0.08, 12.6),
				Style.INK)
		for joint in 8:
			var z := -5.8 + float(joint) * 1.65
			builder.box(Vector3(side * 5.466, 0.35, z), Vector3(0.012, 3.1, 0.035),
				Style.CONCRETE.darkened(0.20))
			builder.cylinder(Vector3(side * 5.7, 2.40, z), 0.07, 0.35, Style.INK)
		builder.beam(Vector3(side * 5.7, 2.55, -5.8),
			Vector3(side * 5.7, 2.55, 5.75), 0.045, Style.INK)
		_gate(builder, Vector3(side * 5.45, 0, -5.75), Vector3(0, 0, -4.85))
		for z in [-2.5, 2.5]:
			var at := Vector3(side * 6.88, 2.40, z)
			_mula(builder, at)
			tow_anchors.append(at + Vector3(-side * 0.38, 0.05, 0))
	builder.build(self, "ChamberAndMulas", Style.material())
	var surface := Builder.new()
	surface.box(Vector3.ZERO, Vector3(10.9, 0.12, 12.5), Style.CANAL)
	for row in 9:
		var z := -5.3 + float(row) * 1.25
		var x := -3.8 + float(row % 3) * 3.2
		surface.box(Vector3(x, 0.063, z), Vector3(1.3, 0.006, 0.025),
			Style.CANAL.lightened(0.28))
	water = surface.build(self, "Water", Style.material())
	var rope := Builder.new()
	rope.cylinder(Vector3.ZERO, 0.018, 1.0, Style.INK, Vector3.ZERO, 6)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = rope.finish()
	instances.instance_count = 8
	_tethers = MultiMeshInstance3D.new()
	_tethers.name = "TowLines"
	_tethers.multimesh = instances
	_tethers.material_override = Style.material()
	add_child(_tethers)


## Essential water state is independent of every decorative-motion preference.
func set_water(chamber_fraction: float) -> float:
	var height := lerpf(WATER_LOW, WATER_HIGH, clampf(chamber_fraction, 0.0, 1.0))
	water.position.y = height
	return height


## Articulated lines stay attached as the water and the two boat rigs move.
func set_tow_points(points: Array[Vector3]) -> void:
	assert(points.size() == tow_anchors.size())
	for index in points.size():
		var start := tow_anchors[index]
		var end := points[index]
		var middle := (start + end) * 0.5 - Vector3.UP * 0.25
		for segment in 2:
			var a := start if segment == 0 else middle
			var b := middle if segment == 0 else end
			var basis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
			basis.y *= a.distance_to(b)
			_tethers.multimesh.set_instance_transform(index * 2 + segment,
				Transform3D(basis, (a + b) * 0.5))


func _gate(builder: Builder, hinge: Vector3, meeting: Vector3) -> void:
	for y in [-1.25, 0.20, 1.80]:
		builder.beam(hinge + Vector3.UP * y, meeting + Vector3.UP * y,
			0.19, Style.INK)
	for index in 6:
		var a := hinge.lerp(meeting, float(index) / 5.0)
		builder.beam(a + Vector3.DOWN * 1.25, a + Vector3.UP * 1.8,
			0.15, Style.JUNGLE.darkened(0.3))
	for index in 5:
		var a := hinge.lerp(meeting, float(index) / 5.0)
		var b := hinge.lerp(meeting, float(index + 1) / 5.0)
		builder.beam(a + Vector3.DOWN * 1.10, b + Vector3.UP * 1.65,
			0.08, Style.JUNGLE)


func _mula(builder: Builder, at: Vector3) -> void:
	builder.rounded_box(at + Vector3.UP * 0.28, Vector3(0.83, 0.59, 1.65),
		0.10, Style.SUN)
	builder.rounded_box(at + Vector3(0, 0.81, 0.25), Vector3(0.72, 0.60, 0.74),
		0.07, Style.CREAM)
	builder.box(at + Vector3(0, 1.15, 0.25), Vector3(0.88, 0.12, 0.9), Style.RED)
	for side: float in [-1.0, 1.0]:
		builder.box(at + Vector3(side * 0.366, 0.86, 0.25),
			Vector3(0.012, 0.29, 0.47), Style.INK)
		for z in [-0.48, 0.48]:
			builder.cylinder(at + Vector3(side * 0.43, -0.03, z), 0.18, 0.10,
				Style.INK, Vector3(0, 0, PI / 2), 10)
	builder.box(at + Vector3(0, 0.86, -0.126), Vector3(0.5, 0.29, 0.012), Style.INK)
