extends RefCounted

## Remo's authored voice uses the same relative-pitch frames as the microphone.
## Input events are explicit; this model never polls hardware or an autoload.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const GLIDE_CENTS_PER_SECOND := 1800.0
const BREAK_CENTS := 700.0
const BREAK_SECONDS := 0.04
const MIN_CENTS := -300.0
const MAX_CENTS := 1300.0
const RELEASE_SECONDS := 0.12
const STICK_DEADZONE := 0.25
const TRIGGER_THRESHOLD := 0.35
const PAD_ACTIONS: Dictionary[int, StringName] = {
	JOY_BUTTON_A: &"voice",
	JOY_BUTTON_DPAD_UP: &"pitch_up",
	JOY_BUTTON_DPAD_DOWN: &"pitch_down",
	JOY_BUTTON_X: &"quiebre",
	JOY_BUTTON_RIGHT_SHOULDER: &"quiebre",
	JOY_BUTTON_B: &"remate",
}

var pitch_cents := 0.0

var _active := false
var _clock := 0.0
var _frame_index := 0
var _bindings: Dictionary[StringName, int] = {}
var _keys: Dictionary[int, bool] = {}
var _buttons: Dictionary[int, Dictionary] = {}
var _axes: Dictionary[int, Dictionary] = {}
var _manual_voice := false
var _target_pitch := NAN
var _break_elapsed := BREAK_SECONDS
var _break_from := 0.0
var _break_to := 0.0
var _finishing := false
var _release_frames := 0


## This band is authored for buttons, never a claim about a measured human voice.
static func profile() -> Dictionary:
	return Frame.profile(Frame.DEFAULT_CHEST_HZ, true)


## Every listening window starts at chest centre on a fresh 100 Hz clock.
func begin() -> void:
	clear_input()
	pitch_cents = 0.0
	_clock = 0.0
	_frame_index = 0
	_finishing = false
	_release_frames = 0
	_active = true


## Ending a window does not invent a successful Remate at its boundary.
func finish() -> void:
	_active = false
	clear_input()


## Pause, focus loss and rebinding must not leave a virtual voice held down.
func clear_input() -> void:
	_keys.clear()
	_buttons.clear()
	_axes.clear()
	_manual_voice = false
	_target_pitch = NAN
	_break_elapsed = BREAK_SECONDS


## Disconnecting one pad must not release another pad or the keyboard.
func forget_device(device: int) -> void:
	_buttons.erase(device)
	_axes.erase(device)


## A touch source can share this clock without impersonating keyboard events.
func set_voice(held: bool) -> void:
	_manual_voice = held


## Touch drags approach a pitch at the same bounded speed as a held pitch key.
func set_target_pitch(cents: float) -> void:
	assert(is_finite(cents), "Remo pitch targets must be finite.")
	_target_pitch = clampf(cents, MIN_CENTS, MAX_CENTS)


## Each fresh press snaps registers once; key repeat cannot generate breaks.
func quiebre() -> bool:
	if not is_voiced() or _break_elapsed < BREAK_SECONDS:
		return false
	_break_from = pitch_cents
	var target := pitch_cents - BREAK_CENTS
	if pitch_cents < Frame.DEFAULT_FALSETTO_LOW:
		target = maxf(pitch_cents + BREAK_CENTS, Frame.DEFAULT_FALSETTO_LOW)
	_break_to = clampf(target, MIN_CENTS, MAX_CENTS)
	_break_elapsed = 0.0
	_target_pitch = NAN
	return true


## An intentional finish leaves real unvoiced frames for the scorer's cut-off.
func remate() -> void:
	if not _active or _finishing:
		return
	_finishing = true
	_release_frames = 0
	_break_elapsed = BREAK_SECONDS
	_target_pitch = NAN


## Rebindable keys arrive from the view; arrows and pad controls are fixed extras.
func handle_event(event: InputEvent, bindings: Dictionary[StringName, int]) -> bool:
	if not _active:
		return false
	_bindings = bindings
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := int(key.physical_keycode if key.physical_keycode != KEY_NONE
			else key.keycode)
		var action := _key_action(code)
		if action == &"":
			return false
		if key.echo:
			return true
		if key.pressed:
			var was_pressed := _keys.has(code)
			_keys[code] = true
			if not was_pressed:
				_press(action)
		else:
			_keys.erase(code)
		return true
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not PAD_ACTIONS.has(button.button_index):
			return false
		var held: Dictionary = _buttons.get(button.device, {})
		var was_pressed := bool(held.get(button.button_index, false))
		held[button.button_index] = button.pressed
		_buttons[button.device] = held
		if button.pressed and not was_pressed:
			_press(PAD_ACTIONS[button.button_index])
		return true
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis not in [JOY_AXIS_LEFT_Y, JOY_AXIS_TRIGGER_RIGHT]:
			return false
		var axes: Dictionary = _axes.get(motion.device, {})
		axes[motion.axis] = motion.axis_value
		_axes[motion.device] = axes
		return true
	return false


## Integer frame indices make a contour independent of render-frame chunking.
func advance(delta: float) -> Array[Dictionary]:
	assert(_active, "Open a Remo window before advancing its source.")
	assert(is_finite(delta) and delta >= 0.0, "Remo time must be finite and nonnegative.")
	_clock += delta
	var result: Array[Dictionary] = []
	while (
		float(_frame_index + 1) * Frame.STEP_SECONDS <= _clock + Frame.TIME_TOLERANCE
		and not is_finished()
	):
		_step_pitch()
		var voiced := is_voiced()
		result.append(Frame.make(
			float(_frame_index) * Frame.STEP_SECONDS, pitch_cents,
			voiced, 1.0 if voiced else 0.0
		))
		_frame_index += 1
		if _finishing:
			_release_frames += 1
	return result


## The view owns when a source may listen, including after a cancelled turn.
func is_active() -> bool:
	return _active


## A held button cannot restart the voice after an intentional finish.
func is_voiced() -> bool:
	if not _active or _finishing:
		return false
	if _manual_voice:
		return true
	for code: int in _keys:
		if _key_action(code) == &"voice":
			return true
	for held: Dictionary in _buttons.values():
		if bool(held.get(JOY_BUTTON_A, false)):
			return true
	for axes: Dictionary in _axes.values():
		if float(axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0)) > TRIGGER_THRESHOLD:
			return true
	return false


## The scorer sees the release before the view closes and judges the turn.
func is_finished() -> bool:
	return _finishing and _release_frames >= roundi(RELEASE_SECONDS * Frame.RATE_HZ)


func _key_action(code: int) -> StringName:
	for action: StringName in _bindings:
		if code == _bindings[action]:
			return action
	if code == KEY_UP:
		return &"pitch_up"
	if code == KEY_DOWN:
		return &"pitch_down"
	return &""


func _press(action: StringName) -> void:
	if action == &"quiebre":
		quiebre()
	elif action == &"remate":
		remate()


func _pitch_axis() -> float:
	var axis := 0.0
	for code: int in _keys:
		var action := _key_action(code)
		if action == &"pitch_up":
			axis += 1.0
		elif action == &"pitch_down":
			axis -= 1.0
	for held: Dictionary in _buttons.values():
		axis += float(bool(held.get(JOY_BUTTON_DPAD_UP, false)))
		axis -= float(bool(held.get(JOY_BUTTON_DPAD_DOWN, false)))
	for axes: Dictionary in _axes.values():
		var stick := -float(axes.get(JOY_AXIS_LEFT_Y, 0.0))
		if absf(stick) > STICK_DEADZONE:
			axis += signf(stick) * (absf(stick) - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
	return clampf(axis, -1.0, 1.0)


func _step_pitch() -> void:
	if _finishing:
		return
	if _break_elapsed < BREAK_SECONDS:
		_break_elapsed = minf(_break_elapsed + Frame.STEP_SECONDS, BREAK_SECONDS)
		pitch_cents = lerpf(_break_from, _break_to, _break_elapsed / BREAK_SECONDS)
		return
	var axis := _pitch_axis()
	var step := GLIDE_CENTS_PER_SECOND * Frame.STEP_SECONDS
	if not is_zero_approx(axis):
		pitch_cents = clampf(pitch_cents + axis * step, MIN_CENTS, MAX_CENTS)
		_target_pitch = NAN
	elif is_finite(_target_pitch):
		pitch_cents = move_toward(pitch_cents, _target_pitch, step)
