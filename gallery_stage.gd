extends Control

## Static original models; the shared viewer owns orbit, zoom and auto-spin.
## No scorer, input source, calibration, audio or campaign state belongs here.

const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const Boat = preload("res://games/sailor_man/world/boat_rig.gd")
const LockSet = preload("res://games/sailor_man/world/lock_set.gd")
const Scenery = preload("res://games/sailor_man/world/scenery.gd")
const Crowd = preload("res://games/sailor_man/world/crowd.gd")
const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")

var viewport: SubViewport
var camera: Camera3D
var _world: Node3D
var _models: Node3D
var _sky: Environment
var _error: Label
var _exhibit: Dictionary = {}
var _configured := false
var _points: Array[Vector3] = []
var _center := Vector3.ZERO
var _radius := 1.0
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	_world = Node3D.new()
	_world.name = "SailorMuseum"
	viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	_sky = Environment.new()
	_sky.background_mode = Environment.BG_COLOR
	_sky.background_color = Color("24494e")
	_sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_sky.ambient_light_color = Style.CREAM
	_sky.ambient_light_energy = 0.7
	environment.environment = _sky
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -32, 0)
	light.light_color = Color("ffe6be")
	light.light_energy = 1.1
	_world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.02
	camera.far = 500.0
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
	if _configured:
		_build_exhibit()
	_update_visibility()


## Only declared free prototypes can be displayed, never an arbitrary resource path.
func configure(exhibit: Dictionary) -> void:
	_configured = true
	_exhibit = {}
	for declared: Dictionary in Options.GALLERY_EXHIBITS:
		if str(declared["id"]) == str(exhibit.get("id", "")):
			_exhibit = declared.duplicate(true)
			break
	_yaw = 0.0
	_pitch = 0.0
	_zoom = 1.0
	if is_node_ready():
		_build_exhibit()


## Relative angles and magnification come from the shared gallery's input loop.
func set_view(yaw: float, pitch: float, zoom: float) -> void:
	if not is_finite(yaw) or not is_finite(pitch) or not is_finite(zoom) or zoom <= 0.0:
		push_error("Sailor gallery needs finite angles and positive magnification.")
		return
	_yaw = yaw
	_pitch = pitch
	_zoom = zoom
	if is_node_ready():
		_frame_camera()


func _build_exhibit() -> void:
	if is_instance_valid(_models):
		_world.remove_child(_models)
		_models.queue_free()
	_points.clear()
	_error.hide()
	_models = Node3D.new()
	_models.name = "ExhibitModels"
	_world.add_child(_models)
	if _exhibit.is_empty():
		_show_error("This exhibit is unavailable.")
		return
	_sky.background_color = Color("24494e")
	var id := str(_exhibit["id"])
	match id:
		"launch", "skiff":
			_add_launch(0 if id == "launch" else 1, "P1" if id == "launch" else "CPU")
		"hot_seat":
			_add_launch(0, "P1", Vector3(-2.25, 0, 0))
			_add_launch(1, "P2", Vector3(2.25, 0, 0))
		"mula":
			var builder := Builder.new()
			LockSet.mula(builder, Vector3.ZERO)
			builder.build(_models, "Mula", Style.material())
			var rail := Builder.new()
			for side: float in [-1.0, 1.0]:
				rail.box(Vector3(side * 0.245, -0.24, 0),
					Vector3(0.06, 0.08, 2.6), Style.INK)
			rail.build(_models, "Rails", Style.material())
		"gate":
			var builder := Builder.new()
			for side: float in [-1.0, 1.0]:
				LockSet.gate(builder, Vector3(side * 5.45, 0, -5.75),
					Vector3(0, 0, -4.85))
			builder.build(_models, "GateLeaves", Style.material())
		"howler":
			var builder := Builder.new()
			Scenery.howler(builder, Vector3.ZERO)
			builder.build(_models, "CanopyHowler", Style.material())
		_:
			var arena := Arenas.arena(id)
			if not arena.is_empty():
				_build_arena(arena)
	_collect_points()
	if _points.is_empty():
		_show_error("This exhibit has no model geometry.")
		return
	var bounds := AABB(_points[0], Vector3.ZERO)
	for point in _points:
		bounds = bounds.expand(point)
	_center = bounds.get_center()
	_radius = maxf(bounds.size.length() * 0.5, 1.0)
	_frame_camera()
	_update_visibility()


func _add_launch(seat: int, label: String, at := Vector3.ZERO) -> Boat:
	var boat := Boat.new(seat, label)
	boat.name = "Launch%d" % (seat + 1)
	boat.position = at
	_models.add_child(boat)
	return boat


func _build_arena(arena: Dictionary) -> void:
	_sky.background_color = arena["sky"]
	Scenery.build(_models, arena)
	var chamber := LockSet.new(bool(arena["clock"]))
	chamber.name = "LockSet"
	_models.add_child(chamber)
	var fraction := 1.0 if bool(arena["descending"]) else \
		0.0 if bool(arena["clock"]) else 0.5
	var water := chamber.set_water(fraction)
	if bool(arena["clock"]):
		var crowd := Crowd.new()
		crowd.name = "Crowd"
		_models.add_child(crowd)
		crowd.set_motion(false)
	var tow_points: Array[Vector3] = []
	for seat in 2:
		var boat := _add_launch(seat, "P1" if seat == 0 else "CPU",
			Vector3(-2.25 if seat == 0 else 2.25, water + 0.26, 0))
		if not chamber.tow_anchors.is_empty():
			for z in [-0.85, 0.85]:
				tow_points.append(boat.transform * Vector3(
					-1.0 if seat == 0 else 1.0, 0.32, z))
	chamber.set_tow_points(tow_points)


func _collect_points() -> void:
	for node in _models.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D and node.mesh != null:
			for corner in 8:
				_points.append(node.global_transform * node.get_aabb().get_endpoint(corner))
		elif node is MultiMeshInstance3D and node.multimesh != null:
			var instances: MultiMesh = node.multimesh
			var count := instances.instance_count
			if instances.visible_instance_count >= 0:
				count = mini(count, instances.visible_instance_count)
			for index in count:
				var transform: Transform3D = node.global_transform \
					* instances.get_instance_transform(index)
				for corner in 8:
					_points.append(transform * instances.mesh.get_aabb().get_endpoint(corner))


func _frame_camera() -> void:
	if camera == null or _points.is_empty():
		return
	var yaw := float(_exhibit.get("framing_yaw", 0.55)) + _yaw
	var pitch := clampf(float(_exhibit.get("framing_pitch", 0.48)) + _pitch, -1.5, 1.5)
	camera.position = _center + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * (_radius * 2.0 + 2.0)
	camera.look_at(_center)
	var inverse := camera.global_transform.affine_inverse()
	var horizontal := 0.0
	var vertical := 0.0
	for point in _points:
		var view := inverse * point
		horizontal = maxf(horizontal, absf(view.x))
		vertical = maxf(vertical, absf(view.y))
	var aspect := maxf(float(viewport.size.x), 1.0) / maxf(float(viewport.size.y), 1.0)
	camera.size = maxf(vertical * 2.0, horizontal * 2.0 / aspect) / 0.90 / _zoom


func _show_error(message: String) -> void:
	push_error("Sailor gallery: %s" % message)
	_error.text = message
	_error.show()
	_update_visibility()


func _update_visibility() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
			if is_visible_in_tree() and not _error.visible and not _points.is_empty() \
			else SubViewport.UPDATE_DISABLED
