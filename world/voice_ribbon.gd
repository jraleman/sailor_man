extends Node3D

## The admitted track becomes a literal ribbon over the water. Geometry alone
## changes: amplitude, smoothing, marks and the canonical frames are untouched.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")

var points := PackedVector3Array()
var _mesh: MeshInstance3D
var _frames: Array[Dictionary] = []
var _evidence: Dictionary = {}
var _duration := 6.0
var _profile := Frame.profile()
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _intense := true


func _init() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "PitchContour"
	var material := Style.material(true)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## Snapshots avoid an in-progress source append changing a parked review.
func show_track(
	frames: Array[Dictionary], evidence: Dictionary, duration: float,
	profile: Dictionary, start: Vector3, end: Vector3
) -> void:
	assert(Frame.track_error(frames).is_empty() and Frame.profile_error(profile).is_empty())
	assert(duration > 0.0)
	_frames = frames.duplicate()
	_evidence = evidence.duplicate(true)
	_duration = duration
	_profile = profile.duplicate()
	_start = start
	_end = end
	position = Vector3.ZERO
	_rebuild()


## Review markers are static, but the effects preference can omit them entirely.
func set_intense_effects(enabled: bool) -> void:
	_intense = enabled
	_rebuild()


## Abandoned takes and replay must not leave a plausible scored ribbon behind.
func clear() -> void:
	_frames.clear()
	_evidence.clear()
	points.clear()
	_mesh.mesh = null
	_mesh.hide()
	position = Vector3.ZERO


func _rebuild() -> void:
	points.clear()
	var builder := Builder.new()
	var geometry := false
	for index in _frames.size():
		var point := _point(float(_frames[index]["t"]), float(_frames[index]["cents"]))
		points.append(point)
		if not bool(_frames[index]["voiced"]):
			continue
		if index > 0 and bool(_frames[index - 1]["voiced"]):
			_strip(builder, points[index - 1], point, 0.13, Style.INK)
			_strip(builder, points[index - 1] + Vector3.BACK * 0.015,
				point + Vector3.BACK * 0.015, 0.065, Style.SUN)
		else:
			_diamond(builder, point, 0.065, Style.SUN)
		geometry = true
	if geometry and _intense:
		var through := float(_frames[-1]["t"]) + Frame.STEP_SECONDS
		for mark: Dictionary in _evidence.get("breaks", []):
			if float(mark["t"]) <= through:
				_diamond(builder, _point(float(mark["t"]), float(mark["to"])),
					0.15, Style.CREAM)
	_mesh.mesh = builder.finish(false) if geometry else null
	_mesh.visible = geometry


func _point(time: float, cents: float) -> Vector3:
	var point := _start.lerp(_end, clampf(time / _duration, 0.0, 1.0))
	var range_top := float(_profile["falsetto_high"])
	point.y += 1.55 * clampf(cents / range_top, -0.22, 1.15)
	return point


func _strip(builder: Builder, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var direction := b - a
	var flank := Vector3(-direction.y, direction.x, 0).normalized() * width * 0.5
	builder.quad(a - flank, b - flank, b + flank, a + flank, color)


func _diamond(builder: Builder, at: Vector3, radius: float, color: Color) -> void:
	builder.quad(at + Vector3.UP * radius, at + Vector3.RIGHT * radius,
		at + Vector3.DOWN * radius, at + Vector3.LEFT * radius, color)
