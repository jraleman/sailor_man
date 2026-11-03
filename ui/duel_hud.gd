extends PanelContainer

## Game-owned turn, judge and input presentation under the shared round shell.
## Narrow listening layouts give the input ribbon the space used by the canal.

signal action_requested
signal repeat_requested
signal source_requested(microphone: bool)
signal auto_source_requested
signal soundcheck_requested
signal rest_dismissed
signal rest_remo_requested
signal practice_requested
signal pause_requested

const Duel = preload("res://games/sailor_man/duel/duel_state.gd")
const Judges = preload("res://games/sailor_man/duel/judges.gd")
const Canal = preload("res://games/sailor_man/world/canal_view.gd")
const Ribbon = preload("res://games/sailor_man/ui/voice_ribbon.gd")
const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")

var lock: Canal
var primary: Button
var repeat: Button
var _margins: MarginContainer
var _frame: VBoxContainer
var _scroll: ScrollContainer
var _body: BoxContainer
var _info: ScrollContainer
var _input_box: MarginContainer
var _turn: Label
var _clock: Label
var _caption: Label
var _actions: HFlowContainer
var _sources: HFlowContainer
var _practice: Button
var _remo_button: Button
var _mic_button: Button
var _auto_button: Button
var _soundcheck: Button
var _source_status: Label
var _rest_offer: VBoxContainer
var _pause: Button
var _rival_ribbon: Ribbon
var _judges: Array[Label] = []
var _phase := -1
var _use_microphone := false
var _preference := 1.0
var _ui_unit := 0.0


func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("15242b")
	add_theme_stylebox_override("panel", background)
	_margins = MarginContainer.new()
	add_child(_margins)
	_frame = VBoxContainer.new()
	_margins.add_child(_frame)
	var header := HBoxContainer.new()
	_frame.add_child(header)
	_turn = _label(header, "Turn", "SAILOR MAN - PRACTICE DUEL")
	_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause = _button(header, "PauseDuel", "Pause", func() -> void: pause_requested.emit())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(column)
	_clock = _label(column, "DuelClock", "")
	_caption = _label(column, "DuelCaption", "")
	_caption.accessibility_live = 1
	_actions = HFlowContainer.new()
	column.add_child(_actions)
	primary = _button(_actions, "PrimaryAction", "Start duel",
		func() -> void: action_requested.emit())
	repeat = _button(_actions, "RepeatCall", "Repeat call",
		func() -> void: repeat_requested.emit())
	_practice = _button(_actions, "Practice", "Practice",
		func() -> void: practice_requested.emit())
	_soundcheck = _button(_actions, "Soundcheck", "Soundcheck",
		func() -> void: soundcheck_requested.emit())
	_sources = HFlowContainer.new()
	column.add_child(_sources)
	_auto_button = _button(_sources, "UseAuto", "Auto",
		func() -> void: auto_source_requested.emit())
	_remo_button = _button(_sources, "UseRemo", "Remo",
		func() -> void: source_requested.emit(false))
	_mic_button = _button(_sources, "UseMicrophone", "Microphone",
		func() -> void: source_requested.emit(true))
	_source_status = _label(column, "SourceStatus", "")
	_rest_offer = VBoxContainer.new()
	_rest_offer.name = "VoiceRestOffer"
	column.add_child(_rest_offer)
	_label(_rest_offer, "VoiceRestCopy",
		"Six voiced microphone turns in ten minutes. Consider some water or a rest. "
		+ "Remo is available for the next duel; the choice is yours.")
	var rest_actions := HFlowContainer.new()
	_rest_offer.add_child(rest_actions)
	_button(rest_actions, "RestNotNow", "Not now", func() -> void: rest_dismissed.emit())
	_button(rest_actions, "RestUseRemo", "Use Remo",
		func() -> void: rest_remo_requested.emit())
	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_info = ScrollContainer.new()
	_info.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_info)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_child(details)
	for judge: Dictionary in Judges.panel():
		_judges.append(_label(details, "Judge_" + str(judge["id"]), ""))
	_label(details, "CanalCaption", "Gat\u00fan practice lock - a toy canal, not a simulator.")
	lock = Canal.new()
	lock.custom_minimum_size.y = 220
	details.add_child(lock)
	_rival_ribbon = Ribbon.new()
	_rival_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_rival_ribbon)
	_label(details, "RivalDescription",
		"Practice skiff - synthetic tone and authored track, not a saloma recording.")
	_label(details, "PrototypeNotice",
		"Best of three tandas. Ties go to the answerer. The chamber clock pauses "
		+ "inside performances. No lives or progress are lost. Real voices, cultural "
		+ "review and the voyage remain pending. Soundcheck stores measurements, not audio.")
	_input_box = MarginContainer.new()
	_input_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_input_box)
	get_viewport().size_changed.connect(_fit)
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.connect("changed", _on_setting_changed)
	_fit.call_deferred()


## The real practice/input scene is reused, rather than a second input/scorer path.
func mount_input(input: Control) -> void:
	input.reparent(_input_box)
	input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit()


## Reuse the shell's caption below the scroller, not inside its hidden HUD.
func mount_audio_caption(caption: Control) -> void:
	caption.reparent(_frame)
	caption.custom_minimum_size = Vector2.ZERO
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_unit = 0.0
	_fit()


## A cancelled or completed modal returns keyboard/controller focus to the duel.
func focus_ready_action() -> void:
	if not is_visible_in_tree():
		return
	if not primary.disabled:
		primary.grab_focus()
	elif _soundcheck.is_visible_in_tree():
		_soundcheck.grab_focus()


## Spectators see the same contour that Eco will use, including during repeats.
func show_track(
	frames: Array[Dictionary], reference: Array[Dictionary], evidence: Dictionary,
	duration: float, profile: Dictionary = {}, singer := Duel.Singer.RIVAL
) -> void:
	if not profile.is_empty():
		_rival_ribbon.set_profile(profile)
	_rival_ribbon.show_tracks(frames, reference, evidence, duration)
	lock.show_track(singer, frames, evidence, duration,
		profile if not profile.is_empty() else Frame.profile())


## Live player geometry does not replace the input lane's reference contour.
func show_live_track(frames: Array[Dictionary], duration: float, profile: Dictionary) -> void:
	lock.show_track(Duel.Singer.PLAYER, frames, {}, duration, profile)


## Replay parks the camera and drops every previous performance's geometry.
func reset_view() -> void:
	lock.reset()


## The shell's preference reaches decorative motion inside the isolated world.
func set_reduced_motion(enabled: bool) -> void:
	lock.set_reduced_motion(enabled)


## A quiet effects setting keeps the contour but removes review spark markers.
func set_intense_effects(enabled: bool) -> void:
	lock.set_intense_effects(enabled)


## This view reads the duel's decisions, never awards points or advances a turn.
func present(
	state: Duel, message: String, microphone: bool, microphone_ready: bool,
	source_preference := Options.InputSource.AUTO, source_status := "", rest_due := false
) -> void:
	var changed := _phase != state.phase
	_phase = state.phase
	_use_microphone = microphone
	var role := "CALL" if state.turn == 0 else "ANSWER"
	var actor := "P1" if state.singer == Duel.Singer.PLAYER else "CPU"
	_turn.text = "T%d %s %s" % [state.tanda, actor, role]
	if state.phase == Duel.Phase.LISTENING:
		_turn.text = "YA! T%d %s | %s | %.1f s" % [
			state.tanda, role, "Microphone" if microphone else "Remo tone",
			maxf(state.window_seconds - state.window_elapsed, 0.0),
		]
	elif state.phase == Duel.Phase.READY:
		_turn.text = "SAILOR MAN - PRACTICE DUEL"
	elif state.phase == Duel.Phase.COMPLETE:
		_turn.text = "P1 WINS" if state.winner == Duel.Singer.PLAYER else "CPU WINS"
	_clock.text = "Tandas P1 %d - %d CPU | Chamber %d:%02d" % [
		state.wins[0], state.wins[1],
		int(ceil(state.chamber_left)) / 60, int(ceil(state.chamber_left)) % 60,
	]
	_caption.text = message
	primary.disabled = state.phase in [
		Duel.Phase.RIVAL, Duel.Phase.REPEAT, Duel.Phase.GUARD, Duel.Phase.LISTENING,
	]
	primary.text = "Continue"
	primary.tooltip_text = ""
	if state.phase == Duel.Phase.READY:
		primary.text = "Start duel"
	elif state.phase == Duel.Phase.PLAYER_READY:
		primary.text = "Ready"
		primary.tooltip_text = "Start your microphone turn." if microphone \
			else "Start your Remo turn."
		primary.disabled = microphone and not microphone_ready
	elif state.phase == Duel.Phase.COMPLETE:
		primary.text = "Results / Retry"
	repeat.visible = state.phase == Duel.Phase.PLAYER_READY and state.turn == 1
	repeat.disabled = state.repeat_used
	_practice.visible = state.phase == Duel.Phase.READY
	_soundcheck.visible = state.phase in [Duel.Phase.READY, Duel.Phase.PLAYER_READY]
	_sources.visible = state.phase in [Duel.Phase.READY, Duel.Phase.PLAYER_READY]
	_auto_button.disabled = source_preference == Options.InputSource.AUTO
	_remo_button.disabled = source_preference == Options.InputSource.REMO
	_mic_button.disabled = source_preference == Options.InputSource.MICROPHONE
	_source_status.text = source_status
	_source_status.visible = _sources.visible
	_rest_offer.visible = rest_due and state.phase in [Duel.Phase.READY, Duel.Phase.COMPLETE]
	for index in _judges.size():
		var judge := Judges.panel()[index]
		var p1 := "-"
		var cpu := "-"
		var note := "Waiting for a performance."
		for record: Dictionary in state.records:
			if int(record["tanda"]) != state.tanda:
				continue
			var paddle: Dictionary = record["judgement"]["paddles"][index]
			if int(record["singer"]) == Duel.Singer.PLAYER:
				p1 = str(paddle["points"])
			else:
				cpu = str(paddle["points"])
			note = str(paddle["note"])
		_judges[index].text = "%s | %s x1.5 | P1 %s / CPU %s\n%s" % [
			judge["badge"], str(judge["taste"]).capitalize(), p1, cpu, note,
		]
	lock.present(state.chamber_fraction(), state.singer if state.phase in [
		Duel.Phase.RIVAL, Duel.Phase.REPEAT, Duel.Phase.LISTENING,
	] else -1)
	_fit()
	if changed and not primary.disabled:
		primary.grab_focus.call_deferred()


func _fit() -> void:
	if not is_node_ready():
		return
	var settings := get_node_or_null("/root/Settings")
	_preference = float(settings.call("get_value", "ui/scale", 1.0)) \
		if settings != null else 1.0
	var transform := get_window().get_final_transform() * get_global_transform_with_canvas()
	var unit := _preference / maxf(transform.get_scale().x, 0.001)
	var physical := Vector2(get_window().size) / _preference
	var wide := physical.x >= 900.0 and physical.y >= 500.0
	var listening := _phase == Duel.Phase.LISTENING
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if listening \
		else ScrollContainer.SCROLL_MODE_AUTO
	_body.vertical = not wide
	_info.visible = wide or not listening
	_info.size_flags_stretch_ratio = 1.0
	_input_box.visible = listening or (
		_use_microphone and _phase in [Duel.Phase.READY, Duel.Phase.PLAYER_READY]
	)
	_input_box.size_flags_stretch_ratio = 1.2
	if not wide and _input_box.visible:
		_info.visible = false
	_body.custom_minimum_size.y = 0.0 if listening else 220.0 * unit
	_actions.visible = not listening
	_sources.visible = _sources.visible and not listening
	_clock.visible = not listening
	_caption.visible = not listening
	lock.custom_minimum_size.y = (220.0 if wide else 150.0) * unit
	_rival_ribbon.custom_minimum_size.y = 140.0 * unit
	_rival_ribbon.fit(unit)
	if is_equal_approx(unit, _ui_unit):
		return
	_ui_unit = unit
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control is Label or control is BaseButton:
			control.add_theme_font_size_override("font_size", roundi(17.0 * unit))
		if control is BaseButton:
			control.custom_minimum_size.y = 44.0 * unit
		if control is BoxContainer:
			control.add_theme_constant_override("separation", roundi(8.0 * unit))
		if control is HFlowContainer:
			control.add_theme_constant_override("h_separation", roundi(8.0 * unit))
			control.add_theme_constant_override("v_separation", roundi(8.0 * unit))
	Responsive.set_margins(_margins, roundi(8 * unit), roundi(8 * unit),
		roundi(8 * unit), roundi(8 * unit))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "ui/scale":
		_fit()


func _label(parent: Node, name: String, text: String) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	label.owner = self
	label.unique_name_in_owner = true
	return label


func _button(parent: Node, name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	button.owner = self
	button.unique_name_in_owner = true
	return button
