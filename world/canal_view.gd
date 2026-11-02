extends Control

## An isolated, batched toy Gatun lock. Singer framing, bobbing and crowd waves
## are presentation only; reduced motion parks them without freezing the water.

const Boat = preload("res://games/sailor_man/world/boat_rig.gd")
const LockSet = preload("res://games/sailor_man/world/lock_set.gd")
const Scenery = preload("res://games/sailor_man/world/scenery.gd")
const Crowd = preload("res://games/sailor_man/world/crowd.gd")
const Ribbon = preload("res://games/sailor_man/world/voice_ribbon.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")
const CAMERA_TARGET := Vector3(0, 1.10, 0)
const CAMERA_OFFSET := Vector3(10, 11, 17)
const BOAT_FLOAT := 0.26

var viewport: SubViewport
var camera: Camera3D
var boats: Array[Boat] = []
var chamber: LockSet
var ribbon: Ribbon
var _world: Node3D
var _crowd: Crowd
var _water_height := LockSet.WATER_LOW
var _focus := Vector3.ZERO
var _focus_goal := Vector3.ZERO
var _elapsed := 0.0
var _reduced_motion := true
var _track_singer := -1
var _track_height := 0.0


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
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	_world = Node3D.new()
	_world.name = "GatunPracticeLock"
	viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("a5cbc5")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Style.CREAM
	sky.ambient_light_energy = 0.65
	environment.environment = sky
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -32, 0)
	light.light_color = Color("ffe6be")
	light.light_energy = 1.1
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 45.0
	_world.add_child(light)
	Scenery.lock_banks(_world)
	chamber = LockSet.new()
	chamber.name = "LockSet"
	_world.add_child(chamber)
	_crowd = Crowd.new()
	_crowd.name = "Crowd"
	_world.add_child(_crowd)
	_crowd.set_motion(not _reduced_motion)
	for index in 2:
		var boat := Boat.new(index, "P1" if index == 0 else "CPU")
		boat.name = "PlayerLaunch" if index == 0 else "PracticeSkiff"
		boat.position.x = -2.25 if index == 0 else 2.25
		_world.add_child(boat)
		boats.append(boat)
	ribbon = Ribbon.new()
	ribbon.name = "VoiceRibbon"
	_world.add_child(ribbon)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	_world.add_child(camera)
	camera.current = true
	viewport.size_changed.connect(_fit_camera)
	visibility_changed.connect(_update_visibility)
	reset()
	_update_visibility()


## A replay clears presentation just as the duel clears its tracks and clock.
func reset() -> void:
	_elapsed = 0.0
	_focus = Vector3.ZERO
	_focus_goal = Vector3.ZERO
	_track_singer = -1
	ribbon.clear()
	present(0.0)
	_pose_camera()


## No model is held here: water and a currently performing seat are plain data.
func present(chamber_fraction: float, singer := -1) -> void:
	_water_height = chamber.set_water(chamber_fraction)
	_focus_goal = Vector3.ZERO if singer < 0 else \
		Vector3(-0.58 if singer == 0 else 0.58, 0, 0)
	if singer >= 0 and _track_singer >= 0 and singer != _track_singer:
		ribbon.clear()
		_track_singer = -1
	_pose_boats()


## Both source routes use their admitted frames, never volume-driven effects.
func show_track(
	singer: int, frames: Array[Dictionary], evidence: Dictionary,
	duration: float, profile: Dictionary
) -> void:
	assert(singer in [0, 1])
	_track_singer = singer
	_track_height = boats[singer].position.y
	ribbon.show_track(frames, evidence, duration, profile,
		_world.to_local(boats[singer].mouth.global_position),
		_world.to_local(boats[1 - singer].mouth.global_position))


## The fixed two-shot also applies when toggled midway through a camera ease.
func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_crowd.set_motion(not enabled)
	if enabled:
		_elapsed = 0.0
		_focus = Vector3.ZERO
		_pose_boats()
		_pose_camera()
	_update_visibility()


## Pitch steps stay visible when decorative review diamonds are suppressed.
func set_intense_effects(enabled: bool) -> void:
	ribbon.set_intense_effects(enabled)


func _process(delta: float) -> void:
	_elapsed += delta
	_focus = _focus.lerp(_focus_goal, 1.0 - exp(-delta * 3.5))
	_pose_boats()
	_crowd.pose(_elapsed)
	_pose_camera()


func _pose_boats() -> void:
	var tow_points: Array[Vector3] = []
	for index in boats.size():
		var boat := boats[index]
		var bob := sin(_elapsed * 1.4 + float(index)) * 0.035 \
			if not _reduced_motion else 0.0
		boat.position.y = _water_height + BOAT_FLOAT + bob
		boat.rotation.z = sin(_elapsed * 1.1 + float(index)) * 0.006 \
			if not _reduced_motion else 0.0
		for z in [-0.85, 0.85]:
			tow_points.append(boat.transform * Vector3(-1.0 if index == 0 else 1.0, 0.32, z))
	chamber.set_tow_points(tow_points)
	if _track_singer >= 0:
		ribbon.position.y = boats[_track_singer].position.y - _track_height


func _pose_camera() -> void:
	var target := CAMERA_TARGET + (_focus if not _reduced_motion else Vector3.ZERO)
	camera.position = target + CAMERA_OFFSET
	camera.look_at(target)
	_fit_camera()


func _fit_camera() -> void:
	if camera == null or boats.is_empty():
		return
	var inverse := camera.transform.affine_inverse()
	var horizontal := 0.0
	var vertical := 0.0
	for boat in boats:
		var bounds := boat.body.get_aabb().grow(0.10)
		for height in [LockSet.WATER_LOW, LockSet.WATER_HIGH]:
			for corner in 8:
				var point := bounds.get_endpoint(corner)
				point += Vector3(boat.position.x, float(height) + BOAT_FLOAT, 0)
				var view_point := inverse * point
				horizontal = maxf(horizontal, absf(view_point.x))
				vertical = maxf(vertical, absf(view_point.y))
	for x in [-2.75, 2.75]:
		var view_point := inverse * Vector3(x, 3.8, -0.79)
		horizontal = maxf(horizontal, absf(view_point.x))
		vertical = maxf(vertical, absf(view_point.y))
	var aspect := float(viewport.size.x) / maxf(float(viewport.size.y), 1.0)
	camera.size = maxf(13.2, maxf(horizontal * 2.0 / 0.88, vertical * 2.0 / 0.88 * aspect))


func _update_visibility() -> void:
	var shown := is_visible_in_tree()
	viewport.render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	set_process(shown and not _reduced_motion)
