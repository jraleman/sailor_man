extends Control

## The shared setup plinth displays the actual launch and plain crew for each
## human seat. No voice, profile, performance or gameplay source belongs here.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Boat = preload("res://games/sailor_man/world/boat_rig.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")
const Outfit = preload("res://games/sailor_man/world/launch_outfit.gd")

var viewport: SubViewport
var camera: Camera3D
var boat: Boat
var _world: Node3D
var _light: DirectionalLight3D
var _error: Label
var _points: Array[Vector3] = []
var _configured := false
var _valid := false
var _seat := -1
var _watch_equipment := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 376)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	_world = Node3D.new()
	_world.name = "SailorSetupModels"
	viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_CLEAR_COLOR
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Style.CREAM
	sky.ambient_light_energy = 0.7
	environment.environment = sky
	_world.add_child(environment)
	_light = DirectionalLight3D.new()
	_light.light_color = Color("ffe6be")
	_light.light_energy = 1.1
	_world.add_child(_light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.02
	camera.far = 50.0
	camera.current = true
	_world.add_child(camera)
	_error = Label.new()
	_error.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_font_size_override("font_size", 20)
	_error.hide()
	add_child(_error)
	_error.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.size_changed.connect(_frame_camera)
	visibility_changed.connect(_update_visibility)
	if _watch_equipment:
		var store := get_node_or_null("/root/Store")
		if store != null:
			store.connect("equipped_changed", _on_outfit_changed)
	if _configured:
		_build_launch()
	_update_visibility()


## The canonical prototype and seat choose geometry; extra fields are never stored.
func configure(character: Dictionary) -> void:
	var seat: Variant = character.get("player_index", 0)
	var valid: bool = str(character.get("id", "")) == Options.CHARACTER_ID \
		and seat is int and seat >= 0 and seat < 2
	if _configured and _valid and valid and seat == _seat \
		and (not is_node_ready() or is_instance_valid(boat)):
		return
	_configured = true
	_valid = valid
	_seat = int(seat) if valid else -1
	if is_node_ready():
		_build_launch()


func _build_launch() -> void:
	if is_instance_valid(boat):
		_world.remove_child(boat)
		boat.queue_free()
		boat = null
	_points.clear()
	_error.hide()
	if not _valid:
		_error.text = "This practice launch preview is unavailable."
		accessibility_description = _error.text
		_error.show()
		push_error("Sailor setup: " + _error.text)
		_update_visibility()
		return
	boat = Boat.new(_seat, "P%d" % (_seat + 1))
	boat.name = "PlayerLaunch"
	_world.add_child(boat)
	_light.rotation_degrees = Vector3(-52, 148 if _seat == 0 else -148, 0)
	_refresh_outfit()


func _read_outfit() -> Dictionary:
	return Outfit.equipped(get_node_or_null("/root/Store"), _seat)


func _on_outfit_changed(game_id: String, slot_id: String, _item_id: String) -> void:
	if game_id == Options.GAME_ID and slot_id.begins_with("p%d_" % (_seat + 1)):
		if _valid and not is_instance_valid(boat):
			_build_launch()
		else:
			_refresh_outfit()


func _refresh_outfit() -> void:
	if not is_instance_valid(boat):
		return
	if not boat.set_outfit(_read_outfit()):
		_world.remove_child(boat)
		boat.queue_free()
		boat = null
		_points.clear()
		_error.text = "This launch outfit is unavailable."
		accessibility_description = _error.text
		_error.show()
		_update_visibility()
		return
	_points.clear()
	for surface in boat.body.mesh.get_surface_count():
		var vertices: PackedVector3Array = boat.body.mesh.surface_get_arrays(
			surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			_points.append(boat.body.global_transform * vertex)
	accessibility_description = "P%d practice launch and plain toy crew. " % (_seat + 1) \
		+ Outfit.describe(boat.outfit) \
		+ ". Original prototype model, not a named or recorded captain."
	_frame_camera()


func _frame_camera() -> void:
	if camera == null or _points.is_empty():
		return
	var bounds := AABB(_points[0], Vector3.ZERO)
	for point in _points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	camera.position = center + Vector3(4.5 if _seat == 0 else -4.5, 2.4, -8.0)
	camera.look_at(center)
	var inverse := camera.global_transform.affine_inverse()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in _points:
		var view := inverse * point
		minimum = minimum.min(Vector2(view.x, view.y))
		maximum = maximum.max(Vector2(view.x, view.y))
	var offset := (minimum + maximum) * 0.5
	camera.position += camera.basis * Vector3(offset.x, offset.y, 0)
	var aspect := maxf(float(viewport.size.x), 1.0) / maxf(float(viewport.size.y), 1.0)
	camera.size = maxf(maximum.y - minimum.y,
		(maximum.x - minimum.x) / aspect) / 0.88
	_update_visibility()


func _update_visibility() -> void:
	if viewport != null:
		(viewport.get_parent() as SubViewportContainer).visible = \
			not _error.visible and not _points.is_empty()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
			if is_visible_in_tree() and not _error.visible and not _points.is_empty() \
			else SubViewport.UPDATE_DISABLED
