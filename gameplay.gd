extends GameShell

## A scorer workbench inside the real shell, keeping pause, results and replay
## exercised while the voice model is proved before campaign work.

@onready var _spike: Control = %ScorerSpike

var _calls := 0


## Keep the manifest and shell identity on the same stable key.
func game_id() -> String:
	return "sailor_man"


## Pausing disconnects capture rather than scoring audio accumulated in a menu.
func open_pause_menu() -> void:
	_spike.call("stop_capture")
	super()


func _build_playfield() -> void:
	_spike.connect("score_ready", _on_score_ready)
	_spike.connect("pause_requested", open_pause_menu)
	_spike.connect("finish_requested", _end_round)


func _set_capture_inset(bottom: float) -> void:
	_spike.offset_bottom = -maxf(bottom, 0.0)


func _reset_round_state() -> void:
	_calls = 0
	_spike.call("reset_session")


func _activate_round() -> void:
	pass


func _finish_round() -> void:
	_spike.call("stop_capture")
	_spike.hide()


func _configure_mode_ui() -> void:
	super()
	if is_instance_valid(_spike):
		_spike.visible = _round_active


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)


func _set_intense_effects_enabled(value: bool) -> void:
	super(value)


func _on_score_ready(result: Dictionary) -> void:
	_calls += 1
	_scores[PLAYER_ONE] = roundi(float(result["total"]) * 100.0)
	_update_scores()


func _round_totals() -> Dictionary:
	return {"hits": _calls, "attempts": _calls}


func _round_highlight_summary() -> String:
	return "%d test calls checked. Real-voice validation is still pending." % _calls


func _describe_round_outcome(_one: int, _two: int) -> Dictionary:
	return {
		"result": "SCORER SESSION",
		"subtitle": "Development scores only. Rivals and the voyage are not implemented yet.",
		"color": Color("f4b941"),
	}
