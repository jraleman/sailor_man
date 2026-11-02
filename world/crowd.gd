extends Node3D

## Plain clay spectators share two batches. Their optional waves never encode
## a score or stand in for reviewed festival characters or traditional dress.

const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")

var _arms: MultiMeshInstance3D
var _shoulders: Array[Vector3] = []
var _motion := true


func _init() -> void:
	var builder := Builder.new()
	var colors := [Style.CREAM, Style.SUN, Style.RED, Style.CANAL]
	for side: float in [-1.0, 1.0]:
		for index in 6:
			var at := Vector3(side * 7.65, 2.28, -4.6 + float(index) * 1.8)
			var skin := Color("b8784e").lerp(Color("e5b583"), float(index % 3) * 0.5)
			builder.cylinder(at + Vector3.UP * 0.32, 0.18, 0.48,
				colors[index % colors.size()], Vector3.ZERO, 8, 0.78)
			builder.ellipsoid(at + Vector3.UP * 0.72, Vector3(0.31, 0.35, 0.31), skin)
			builder.ellipsoid(at + Vector3.UP * 0.86,
				Vector3(0.29, 0.12, 0.30), Style.INK)
			_shoulders.append(at + Vector3(-side * 0.16, 0.51, 0))
	builder.build(self, "Spectators", Style.material())
	var arm := Builder.new()
	arm.cylinder(Vector3.ZERO, 0.055, 1.0, Style.CREAM, Vector3.ZERO, 6)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = arm.finish()
	instances.instance_count = _shoulders.size()
	_arms = MultiMeshInstance3D.new()
	_arms.name = "WavingArms"
	_arms.multimesh = instances
	_arms.material_override = Style.material()
	add_child(_arms)
	pose(0.0)


## Toggling reduced motion parks every arm immediately at its resting pose.
func set_motion(enabled: bool) -> void:
	_motion = enabled
	if not enabled:
		pose(0.0)


## The view clock animates decoration; no game state is read or changed.
func pose(time: float) -> void:
	for index in _shoulders.size():
		var shoulder := _shoulders[index]
		var side := -signf(shoulder.x)
		var wave := sin(time * 1.8 + float(index)) * 0.18 if _motion else 0.0
		var hand := shoulder + Vector3(side * (0.25 + wave), 0.23, 0.02)
		var basis := Basis(Quaternion(Vector3.UP, (hand - shoulder).normalized()))
		basis.y *= shoulder.distance_to(hand)
		_arms.multimesh.set_instance_transform(index,
			Transform3D(basis, (shoulder + hand) * 0.5))
