extends MenuScreen

## Player-paced practice cards reuse the original static exhibits. No voice
## source, narration, campaign state or first-run save belongs in this opening.

const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const CARDS: Array[Dictionary] = [
	{
		"title": "Free canal practice",
		"body": "Five free toy-canal arenas. Duel a synthetic practice skiff, "
			+ "challenge your own echo in Culebra, or pass the mic in two-human "
			+ "hot seat. The campaign and recorded rivals are still pending.",
		"exhibit": Arenas.GATUN,
		"description": "Original toy lock, blue P1 launch and synthetic CPU skiff.",
	},
	{
		"title": "Shape the call",
		"body": "Remo needs no microphone: hold Voice, glide pitch, use Break, "
			+ "then Finish. Press Ready and wait for YA! before your turn. "
			+ "The written Guide explains Aliento, Quiebre, Altura, Remate and Eco. "
			+ "Extra loudness earns nothing.",
		"exhibit": "launch",
		"description": "Original blue P1 practice launch and toy crew.",
	},
	{
		"title": "Take turns, stay comfortable",
		"body": "Play solo or take turns with a friend. Microphone use is optional "
			+ "and starts off; only Enable microphone opens it. Read the Guide "
			+ "before playing, and use Soundcheck if you choose voice. "
			+ "Done opens the title screen, not a match.",
		"exhibit": "hot_seat",
		"description": "Original blue P1 and red P2 launches, each with a player plaque.",
	},
]

@export_file("*.tscn") var next_scene := "res://scenes/menus/main_menu.tscn"

@onready var _margins: MarginContainer = %Margins
@onready var _layout: VBoxContainer = %Layout
@onready var _header: HBoxContainer = %Header
@onready var _title: Label = %Title
@onready var _step: Label = %Step
@onready var _body: BoxContainer = %Body
@onready var _stage: Control = %Stage
@onready var _scroll: ScrollContainer = %CopyScroll
@onready var _copy_column: VBoxContainer = %CopyColumn
@onready var _heading: Label = %Heading
@onready var _copy: Label = %Copy
@onready var _actions: HBoxContainer = %Actions
@onready var _skip: Button = %SkipButton
@onready var _next: Button = %NextButton

var _card_index := 0
var _finished := false
var _card_tween: Tween


func _ready() -> void:
	first_focus = _next
	margins = _margins
	Settings.changed.connect(_on_setting_changed)
	_show_card(0)
	super()


## Back/Escape and the controller's cancel button skip rather than close an overlay.
func go_back() -> void:
	_finish()


func _input(event: InputEvent) -> void:
	if _finished or not is_visible_in_tree() or Router.is_transitioning():
		return
	if not event is InputEventJoypadButton or not event.pressed:
		return
	match event.button_index:
		JOY_BUTTON_A:
			if get_viewport().gui_get_focus_owner() == _skip:
				_skip.pressed.emit()
			else:
				_next.pressed.emit()
		JOY_BUTTON_B:
			_skip.pressed.emit()
		JOY_BUTTON_DPAD_LEFT:
			_skip.grab_focus()
		JOY_BUTTON_DPAD_RIGHT:
			_next.grab_focus()
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			_scroll.grab_focus()
			var bar := _scroll.get_v_scroll_bar()
			bar.value += bar.page * 0.8 * (
				-1.0 if event.button_index == JOY_BUTTON_DPAD_UP else 1.0)
		_:
			return
	get_viewport().set_input_as_handled()


func _on_next_pressed() -> void:
	if _finished:
		return
	if _card_index + 1 == CARDS.size():
		_finish()
	else:
		_show_card(_card_index + 1)


func _on_skip_pressed() -> void:
	_finish()


func _show_card(index: int) -> void:
	_stop_card_fade()
	_card_index = index
	var card := CARDS[index]
	_heading.text = str(card["title"])
	_copy.text = str(card["body"])
	_step.text = "%d / %d" % [index + 1, CARDS.size()]
	_step.accessibility_name = "Practice opening, card %d of %d" % [index + 1, CARDS.size()]
	_stage.accessibility_description = str(card["description"])
	_stage.call("configure", {"id": card["exhibit"]})
	_scroll.scroll_vertical = 0
	_next.text = "Done" if index + 1 == CARDS.size() else "Next"
	_next.tooltip_text = "Open the title screen." if index + 1 == CARDS.size() \
		else "Read the next card at your own pace."
	_next.accessibility_description = _next.tooltip_text
	if not Settings.reduced_motion_enabled():
		_body.modulate.a = 0.0
		_card_tween = create_tween()
		_card_tween.tween_property(_body, "modulate:a", 1.0, 0.18)


func _stop_card_fade() -> void:
	if _card_tween != null:
		_card_tween.kill()
		_card_tween = null
	_body.modulate.a = 1.0


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_stop_card_fade()
	_next.disabled = true
	_skip.disabled = true
	_stage.hide()
	if Router.is_transitioning():
		await Router.transition_finished
	if is_inside_tree():
		Router.goto(next_scene)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "ui/scale":
		refresh_layout()
	elif key == Settings.REDUCED_MOTION_KEY and bool(value):
		_stop_card_fade()


func _on_layout_changed(size: Vector2) -> void:
	var preference := float(Settings.get_value("ui/scale", 1.0))
	var unit := size.x / maxf(get_window().size.x, 1.0) * preference
	var canvas := size / unit
	var side := roundi(maxf(12.0, (canvas.x - 1120.0) * 0.5) * unit)
	var vertical := roundi(12.0 * unit)
	Responsive.set_margins(_margins, side, vertical, side, vertical)
	for box: BoxContainer in [_layout, _header, _body, _copy_column, _actions]:
		box.add_theme_constant_override("separation", roundi(12.0 * unit))
	_body.vertical = canvas.y > canvas.x
	_stage.size_flags_stretch_ratio = 0.42 if _body.vertical else 1.0
	_scroll.size_flags_stretch_ratio = 0.58 if _body.vertical else 1.0
	_title.add_theme_font_size_override("font_size", roundi(24.0 * unit))
	_step.add_theme_font_size_override("font_size", roundi(14.0 * unit))
	_heading.add_theme_font_size_override("font_size", roundi(22.0 * unit))
	_copy.add_theme_font_size_override("font_size", roundi(16.0 * unit))
	for button: Button in [_skip, _next]:
		button.add_theme_font_size_override("font_size", roundi(18.0 * unit))
		button.custom_minimum_size.y = 44.0 * unit


func _exit_tree() -> void:
	_stop_card_fade()
