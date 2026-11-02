extends SceneTree

## Synthetic controls exercise the real frame/scorer path, not a second judge.
## These parity cases do not substitute for authentic saloma validation.

const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Keys = preload("res://games/sailor_man/voice/key_voice_source.gd")
const Touch = preload("res://games/sailor_man/voice/touch_voice_source.gd")
const Scorer = preload("res://games/sailor_man/duel/saloma_scorer.gd")
const Fixture = preload("res://games/sailor_man/tests/voice_track_fixture.gd")
const BINDINGS: Dictionary[StringName, int] = {
	&"voice": KEY_SPACE, &"pitch_up": KEY_W, &"pitch_down": KEY_S,
	&"quiebre": KEY_J, &"remate": KEY_K,
}

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_keyboard()
	_test_gamepad()
	_test_clock()
	_test_touch()
	_test_flicks()
	_test_parity()
	if _failures.is_empty():
		print("Remo source tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_keyboard() -> void:
	var source := Keys.new()
	source.begin()
	source.handle_event(_key(KEY_SPACE), BINDINGS)
	var frames := source.advance(0.5)
	_expect(
		frames.size() == 50 and bool(frames[0]["voiced"]) and source.is_voiced(),
		"Holding Voice must produce consecutive voiced samples without microphone input."
	)
	source.handle_event(_key(KEY_J), BINDINGS)
	frames = source.advance(0.04)
	_expect(
		is_equal_approx(float(frames[0]["cents"]), 175.0)
		and is_equal_approx(float(frames[-1]["cents"]), 700.0),
		"A fresh Quiebre must land 700 cents above chest over four 100 Hz frames."
	)
	var repeated := _key(KEY_J)
	repeated.echo = true
	source.handle_event(repeated, BINDINGS)
	frames = source.advance(0.2)
	_expect(
		is_equal_approx(float(frames[-1]["cents"]), 700.0),
		"Operating-system key repeat must not repeatedly toggle registers."
	)
	source.handle_event(_key(KEY_J), BINDINGS)
	source.advance(0.1)
	_expect(
		is_equal_approx(source.pitch_cents, 700.0),
		"A duplicate down event without a release must not manufacture another break."
	)
	source.handle_event(_key(KEY_J, false), BINDINGS)
	source.handle_event(_key(KEY_J), BINDINGS)
	frames = source.advance(0.04)
	_expect(
		is_zero_approx(float(frames[-1]["cents"])),
		"A second deliberate Quiebre must return from falsetto to chest."
	)
	source.handle_event(_key(KEY_W), BINDINGS)
	frames = source.advance(0.2)
	_expect(
		is_equal_approx(float(frames[-1]["cents"]), 360.0),
		"Pitch keys must glide continuously at 1800 cents per second."
	)
	source.handle_event(_key(KEY_S), BINDINGS)
	frames = source.advance(0.1)
	_expect(
		is_equal_approx(float(frames[-1]["cents"]), 360.0),
		"Opposite held pitch keys must cancel rather than favouring event order."
	)
	source.handle_event(_key(KEY_W, false), BINDINGS)
	source.advance(1.0)
	_expect(source.pitch_cents == -300.0, "Pitch must stop at the reachable lower bound.")
	source.handle_event(_key(KEY_S, false), BINDINGS)
	source.handle_event(_key(KEY_J, false), BINDINGS)
	source.handle_event(_key(KEY_J), BINDINGS)
	source.advance(0.04)
	_expect(
		source.pitch_cents == 700.0,
		"A break from below chest must still land in the authored falsetto band."
	)
	source.handle_event(_key(KEY_K), BINDINGS)
	frames = source.advance(0.12)
	_expect(
		source.is_finished() and frames.size() == 12 and not bool(frames[0]["voiced"]),
		"Remate must release even a held Voice and retain a real silent cut-off."
	)
	source.finish()
	source.begin()
	var rebound := BINDINGS.duplicate()
	rebound[&"voice"] = KEY_Z
	_expect(
		not source.handle_event(_key(KEY_SPACE), rebound),
		"The old Voice key must stop working when the action is rebound."
	)
	source.handle_event(_key(KEY_Z), rebound)
	source.handle_event(_key(KEY_UP), rebound)
	frames = source.advance(0.1)
	_expect(
		bool(frames[-1]["voiced"]) and is_equal_approx(source.pitch_cents, 180.0),
		"The rebound Voice key and fixed arrow-key pitch extra must work together."
	)
	source.clear_input()
	_expect(not source.is_voiced(), "Clearing input must release all keyboard holds.")


func _test_gamepad() -> void:
	var source := Keys.new()
	source.begin()
	source.handle_event(_button(JOY_BUTTON_A, true, 2), BINDINGS)
	source.handle_event(_motion(JOY_AXIS_LEFT_Y, -0.1, 2), BINDINGS)
	source.advance(0.2)
	_expect(
		source.is_voiced() and is_zero_approx(source.pitch_cents),
		"A holds Voice; stick noise inside the deadzone must not change pitch."
	)
	source.handle_event(_motion(JOY_AXIS_LEFT_Y, -1.0, 2), BINDINGS)
	source.advance(0.2)
	_expect(
		is_equal_approx(source.pitch_cents, 360.0),
		"The full gamepad stick must share the keyboard glide speed."
	)
	source.handle_event(_motion(JOY_AXIS_LEFT_Y, 0.0, 2), BINDINGS)
	source.handle_event(_button(JOY_BUTTON_X, true, 2), BINDINGS)
	source.advance(0.04)
	_expect(
		is_equal_approx(source.pitch_cents, 1060.0),
		"The pad Break button must use the same register transition."
	)
	source.handle_event(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.8, 3), BINDINGS)
	source.handle_event(_button(JOY_BUTTON_A, false, 2), BINDINGS)
	source.forget_device(2)
	_expect(source.is_voiced(), "Disconnecting one pad must preserve another pad's held trigger.")
	source.handle_event(_key(KEY_SPACE), BINDINGS)
	source.handle_event(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0, 3), BINDINGS)
	_expect(source.is_voiced(), "Releasing a trigger must not release a held keyboard Voice.")
	source.handle_event(_button(JOY_BUTTON_DPAD_DOWN, true, 3), BINDINGS)
	source.advance(0.1)
	_expect(
		is_equal_approx(source.pitch_cents, 880.0),
		"D-pad pitch must work independently of the stick."
	)
	source.handle_event(_button(JOY_BUTTON_B, true, 3), BINDINGS)
	source.advance(0.12)
	_expect(source.is_finished(), "The pad Finish button must end the same virtual performance.")


func _test_clock() -> void:
	var whole := Keys.new()
	var split := Keys.new()
	whole.begin()
	split.begin()
	whole.handle_event(_key(KEY_SPACE), BINDINGS)
	split.handle_event(_key(KEY_SPACE), BINDINGS)
	whole.handle_event(_key(KEY_W), BINDINGS)
	split.handle_event(_key(KEY_W), BINDINGS)
	var expected := whole.advance(1.0)
	var actual: Array[Dictionary] = []
	for _index in 100:
		actual.append_array(split.advance(0.003))
		actual.append_array(split.advance(0.007))
	_expect(
		actual == expected and Frame.track_error(actual).is_empty(),
		"Sub-frame updates must produce the exact same 100 Hz contour as one larger update."
	)
	_expect(
		split.pitch_cents == 1300.0,
		"A held upward pitch must not escape the virtual profile's upper bound."
	)
	split.finish()
	split.begin()
	_expect(
		not split.is_voiced() and split.pitch_cents == 0.0
		and float(split.advance(0.01)[0]["t"]) == 0.0,
		"A new turn must reset pitch, holds and the track clock."
	)


func _test_touch() -> void:
	var source := Touch.new()
	source.begin()
	source.press_contact(4, Vector2(100, 100), 200.0)
	source.advance(0.2)
	source.move_contact(4, Vector2(100, 50), Vector2(0, -100))
	source.advance(0.25)
	_expect(
		source.is_voiced() and is_equal_approx(source.pitch_cents, 400.0),
		"A slow vertical drag must hold Voice and approach its relative-pitch target."
	)
	source.press_contact(9, Vector2.ZERO, 200.0, true)
	source.advance(0.04)
	_expect(
		is_equal_approx(source.pitch_cents, 1100.0),
		"A second finger must press Break while the ribbon finger keeps singing."
	)
	source.release_contact(9)
	source.move_contact(4, Vector2(100, 50), Vector2.ZERO)
	source.advance(0.2)
	_expect(
		source.is_voiced() and is_equal_approx(source.pitch_cents, 1100.0),
		"Releasing Break or resting the steering finger must not undo the register change."
	)
	source.press_contact(12, Vector2(200, 80), 200.0)
	source.move_contact(12, Vector2(200, 10), Vector2(0, -100))
	source.advance(0.1)
	_expect(
		is_equal_approx(source.pitch_cents, 1100.0),
		"A secondary ribbon contact must not steal pitch from its owner."
	)
	source.release_contact(4)
	_expect(source.is_voiced(), "Another held ribbon contact must retain Voice after hand-off.")
	source.move_contact(12, Vector2(200, 35), Vector2(0, 100))
	source.advance(0.2)
	_expect(
		is_equal_approx(source.pitch_cents, 900.0),
		"Hand-off must re-anchor the next finger rather than jumping to its old position."
	)
	source.release_contact(12)
	_expect(not source.is_voiced(), "Only releasing the final ribbon hold must release Voice.")
	source.finish()
	source.begin()
	_expect(
		not source.has_contact(4) and not source.has_contact(12) and not source.is_voiced(),
		"Cancelled contacts must not leak into a later turn."
	)


func _test_flicks() -> void:
	var source := Touch.new()
	source.begin()
	source.press_contact(0, Vector2(80, 120), 200.0)
	source.advance(0.3)
	source.move_contact(0, Vector2(80, 80), Vector2(0, -900))
	source.advance(0.04)
	_expect(
		is_equal_approx(source.pitch_cents, 700.0),
		"A quick upward flick must create a Quiebre, not a slow glide."
	)
	source.move_contact(0, Vector2(80, 40), Vector2(0, -900))
	source.advance(0.1)
	_expect(
		source.pitch_cents >= 700.0,
		"One continuous upward flick must not toggle the register back down."
	)
	source.move_contact(0, Vector2(80, 40), Vector2.ZERO)
	source.move_contact(0, Vector2(80, 130), Vector2(0, 900))
	var tail := source.advance(0.12)
	_expect(
		source.is_finished() and not bool(tail[0]["voiced"]),
		"A downward flick must finish and release even before the finger lifts."
	)


func _test_parity() -> void:
	var source := Keys.new()
	source.begin()
	source.handle_event(_key(KEY_SPACE), BINDINGS)
	var frames := source.advance(1.2)
	for _index in 3:
		source.handle_event(_key(KEY_J), BINDINGS)
		frames.append_array(source.advance(0.04))
		source.handle_event(_key(KEY_J, false), BINDINGS)
		frames.append_array(source.advance(1.2))
	source.handle_event(_key(KEY_K), BINDINGS)
	frames.append_array(source.advance(0.12))
	var ideal := Fixture.new()
	ideal.hold(1.2)
	ideal.glide(0.04, 0.0, 700.0)
	ideal.hold(1.2, 700.0)
	ideal.glide(0.04, 700.0, 0.0)
	ideal.hold(1.2)
	ideal.glide(0.04, 0.0, 700.0)
	ideal.hold(1.2, 700.0)
	ideal.cut_off()
	var sung: Array[Dictionary] = []
	var singer := Frame.profile(220.0, true)
	for frame: Dictionary in ideal.frames:
		sung.append(Frame.from_frequency(
			float(frame["t"]), 220.0 * pow(2.0, float(frame["cents"]) / 1200.0),
			0.08 if bool(frame["voiced"]) else 0.0, singer, bool(frame["voiced"])
		))
	var remo := Scorer.score(frames, Keys.profile())
	var voice := Scorer.score(sung, singer)
	_expect(
		Frame.track_error(frames).is_empty() and bool(remo["valid"]) and bool(voice["valid"])
		and absf(float(remo["total"]) - float(voice["total"])) <= 0.05,
		"An ideal Remo and equivalent normalized sung contour must score within 5%."
	)
	_expect(
		(remo["evidence"]["breaks"] as Array).size() == 3
		and float(remo["marks"]["remate"]) == 1.0 and not bool(remo["power_gated"]),
		"Real control inputs must produce three judged breaks and a crisp finish."
	)
	var answer := Scorer.score(frames, Keys.profile(), sung)
	_expect(
		float(answer["marks"]["eco"]) > 0.99,
		"Remo must earn Eco from the same reference contour as a sung answer."
	)
	print("Synthetic Remo/voice parity: %.4f / %.4f out of 100." % [
		float(remo["total"]) * 100.0, float(voice["total"]) * 100.0,
	])


func _key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _button(button: JoyButton, pressed: bool, device: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	event.device = device
	return event


func _motion(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = device
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
