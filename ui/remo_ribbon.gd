extends "res://games/sailor_man/ui/voice_ribbon.gd"

## The scorer's existing contour becomes a drawing lane, not a second minigame.
## Capture each finger independently, including a separate Break-button contact.

signal turn_requested

const Source = preload("res://games/sailor_man/voice/touch_voice_source.gd")
const MOUSE_CONTACT := -2

var source: Source
var break_button: Button
var enabled := true
var _captured: Dictionary[int, bool] = {}


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Clearing the view's captures never fabricates a release in a cancelled track.
func clear_contacts() -> void:
	_captured.clear()


func _input(event: InputEvent) -> void:
	if not enabled or source == null or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			_press_contact(touch.index, touch.position)
		elif _captured.has(touch.index):
			_captured.erase(touch.index)
			source.release_contact(touch.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move_contact(drag.index, drag.position, drag.velocity)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.device == InputEvent.DEVICE_ID_EMULATION:
			if _hit(self, mouse.position) or _hit(break_button, mouse.position):
				get_viewport().set_input_as_handled()
			return
		if mouse.pressed and _hit(self, mouse.position):
			_press_contact(MOUSE_CONTACT, mouse.position)
		elif not mouse.pressed and _captured.has(MOUSE_CONTACT):
			_captured.erase(MOUSE_CONTACT)
			source.release_contact(MOUSE_CONTACT)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mouse := event as InputEventMouseMotion
		if mouse.device != InputEvent.DEVICE_ID_EMULATION:
			_move_contact(MOUSE_CONTACT, mouse.position, mouse.velocity)


func _press_contact(index: int, position: Vector2) -> void:
	var on_break := (
		is_instance_valid(break_button) and not break_button.disabled
		and _hit(break_button, position)
	)
	if _captured.has(index) or (not _hit(self, position) and not on_break):
		return
	if not source.is_active():
		turn_requested.emit()
	if not source.is_active():
		return
	_captured[index] = true
	grab_focus()
	source.press_contact(
		index, get_global_transform_with_canvas().affine_inverse() * position,
		maxf(size.y - 2.0 * PADDING * _unit, 1.0), on_break
	)
	get_viewport().set_input_as_handled()


func _move_contact(index: int, position: Vector2, velocity: Vector2) -> void:
	if not _captured.has(index):
		return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	source.move_contact(index, inverse * position, inverse.basis_xform(velocity))
	get_viewport().set_input_as_handled()


func _hit(control: Control, position: Vector2) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	var ancestor := control
	while ancestor != null:
		if ancestor == control or ancestor.clip_contents:
			var local := ancestor.get_global_transform_with_canvas().affine_inverse() * position
			if not Rect2(Vector2.ZERO, ancestor.size).has_point(local):
				return false
		ancestor = ancestor.get_parent_control()
	return true


func _draw() -> void:
	super._draw()
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))
