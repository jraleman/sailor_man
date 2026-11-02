extends Control

## A literal contour/evidence display: solid current track, dashed reference,
## break ticks and the longest-breath underline. No decorative animation.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const INK := Color("17242e")
const SUN := Color("f4b941")
const CREAM := Color("fbf2df")
const GUIDE := Color("7b9b9e")
const MIN_CENTS := -300.0
const MAX_CENTS := 1600.0
const PADDING := 22.0

var _frames: Array[Dictionary] = []
var _reference: Array[Dictionary] = []
var _evidence: Dictionary = {}
var _duration := 6.0
var _unit := 1.0
var _falsetto_low := 700.0
var _falsetto_high := 1300.0
var _max_cents := MAX_CENTS


## Match physical guide labels and strokes to the surrounding responsive UI.
func fit(unit: float) -> void:
	_unit = unit
	queue_redraw()


## Guides describe the current source, not a human profile borrowed by Remo.
func set_profile(profile: Dictionary) -> void:
	assert(Frame.profile_error(profile).is_empty())
	_falsetto_low = float(profile["falsetto_low"])
	_falsetto_high = float(profile["falsetto_high"])
	_max_cents = maxf(MAX_CENTS, _falsetto_high + 300.0)
	queue_redraw()


## The view consumes evidence without making or changing any scoring decisions.
func show_tracks(
	frames: Array[Dictionary], reference: Array[Dictionary],
	evidence: Dictionary, duration: float
) -> void:
	_frames = frames
	_reference = reference
	_evidence = evidence
	_duration = maxf(duration, 0.01)
	for track: Array in [frames, reference]:
		if not track.is_empty():
			_duration = maxf(_duration, float(track[-1]["t"]) + Frame.STEP_SECONDS)
	queue_redraw()


func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var font_size := roundi(12.0 * _unit)
	var padding := PADDING * _unit
	var stagger := _point(0.0, _falsetto_low).y - _point(0.0, _falsetto_high).y \
		< font.get_height(font_size) + 2.0 * _unit
	for cents in [0.0, _falsetto_low, _falsetto_high]:
		var y := _point(0.0, cents).y
		draw_line(Vector2(padding, y), Vector2(size.x - padding, y), GUIDE, _unit)
		var label := "%d cents" % cents
		var x := padding + 4.0 * _unit
		if stagger and cents == _falsetto_low:
			x = size.x - padding - 4.0 * _unit \
				- font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(
			font, Vector2(x, y - 3.0 * _unit),
			label, 0, -1, font_size, CREAM
		)
	_draw_track(_reference, true)
	_draw_track(_frames, false)
	for evidence: Dictionary in _evidence.get("breaks", []):
		var x := _point(float(evidence["t"]), 0.0).x
		draw_line(Vector2(x, padding), Vector2(x, size.y - padding), SUN, _unit)
		draw_circle(_point(float(evidence["t"]), float(evidence["to"])), 4.0 * _unit, CREAM)
	var breath: Dictionary = _evidence.get("longest_breath", {})
	if float(breath.get("seconds", 0.0)) > 0.0:
		draw_line(
			Vector2(_point(float(breath["start"]), 0.0).x, size.y - 8.0 * _unit),
			Vector2(_point(float(breath["end"]), 0.0).x, size.y - 8.0 * _unit),
			CREAM, 3.0 * _unit
		)


func _draw_track(frames: Array[Dictionary], reference: bool) -> void:
	for index in range(1, frames.size()):
		if not bool(frames[index - 1]["voiced"]) or not bool(frames[index]["voiced"]):
			continue
		var from := _point(
			float(frames[index - 1]["t"]), float(frames[index - 1]["cents"])
		)
		var to := _point(
			float(frames[index]["t"]), float(frames[index]["cents"])
		)
		if reference:
			if index % 4 < 2:
				draw_line(from, to, CREAM, 2.0 * _unit, true)
		else:
			draw_line(from, to, SUN, 3.0 * _unit, true)


func _point(t: float, cents: float) -> Vector2:
	var padding := PADDING * _unit
	return Vector2(
		padding + clampf(t / _duration, 0.0, 1.0) * maxf(size.x - padding * 2.0, 0.0),
		size.y - padding - clampf(
			(cents - MIN_CENTS) / (_max_cents - MIN_CENTS), 0.0, 1.0
		) * maxf(size.y - padding * 2.0, 0.0)
	)


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.set_corner_radius_all(10)
	return style
