extends "res://games/sailor_man/voice/key_voice_source.gd"

## Independent contacts share Remo's exact clock, register jumps and pitch speed.
## One ribbon finger steers; a second finger can press Break without releasing it.

const FLICK_HEIGHTS_PER_SECOND := 3.0
const FLICK_DISTANCE := 0.15
const FLICK_RESET_SPEED := 0.7
const NO_CONTACT := -1

var _contacts: Dictionary[int, Dictionary] = {}
var _voice_contact := NO_CONTACT


## Keep contact ownership from surviving pause, replay or a keyboard rebind.
func clear_input() -> void:
	super.clear_input()
	_contacts.clear()
	_voice_contact = NO_CONTACT


## Capturing contacts by id lets the ribbon and Break be used simultaneously.
func press_contact(
	index: int, position: Vector2, height: float, break_button := false
) -> void:
	assert(is_active(), "Open a Remo window before touching its controls.")
	assert(height > 0.0 and is_finite(height) and position.is_finite())
	assert(index != NO_CONTACT and not _contacts.has(index))
	_contacts[index] = {
		"position": position, "anchor": position, "pitch": pitch_cents,
		"height": height, "break": break_button, "flicked": false,
	}
	if break_button:
		quiebre()
	elif _voice_contact == NO_CONTACT:
		_voice_contact = index
		set_voice(true)


## Vertical distance sets pitch; velocity distinguishes flicks from slow glides.
func move_contact(index: int, position: Vector2, velocity: Vector2) -> void:
	assert(position.is_finite() and velocity.is_finite())
	if not _contacts.has(index):
		return
	var contact := _contacts[index]
	contact["position"] = position
	if index != _voice_contact or _finishing:
		return
	var height := float(contact["height"])
	var displacement := (position.y - (contact["anchor"] as Vector2).y) / height
	var speed := velocity.y / height
	if absf(speed) < FLICK_RESET_SPEED:
		contact["flicked"] = false
	if not bool(contact["flicked"]) and absf(displacement) >= FLICK_DISTANCE:
		if speed <= -FLICK_HEIGHTS_PER_SECOND and displacement < 0.0:
			contact["flicked"] = true
			quiebre()
			return
		if speed >= FLICK_HEIGHTS_PER_SECOND and displacement > 0.0:
			remate()
			return
	set_target_pitch(float(contact["pitch"]) - displacement * (MAX_CENTS - MIN_CENTS))


## Only the steering finger's release changes voice ownership.
func release_contact(index: int) -> void:
	if not _contacts.has(index):
		return
	_contacts.erase(index)
	if index != _voice_contact:
		return
	_voice_contact = NO_CONTACT
	for next: int in _contacts:
		var contact := _contacts[next]
		if bool(contact["break"]):
			continue
		_voice_contact = next
		contact["anchor"] = contact["position"]
		contact["pitch"] = pitch_cents
		break
	set_voice(_voice_contact != NO_CONTACT)
	_target_pitch = NAN


## The view keeps receiving drags/releases even when a finger leaves the lane.
func has_contact(index: int) -> bool:
	return _contacts.has(index)


## Re-anchor after any break so the next drag cannot undo its new register.
func quiebre() -> bool:
	var changed := super.quiebre()
	if changed and _contacts.has(_voice_contact):
		var contact := _contacts[_voice_contact]
		contact["anchor"] = contact["position"]
		contact["pitch"] = _break_to
	return changed
