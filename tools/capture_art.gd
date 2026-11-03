extends SceneTree

## Reproducible branding and setup stills use the same original meshes as play.
## Run without --headless; no microphone, profile, performance or duel is opened.
## `-- --only=icon` or `--only=levels` limits regeneration; `--output-dir=...`
## redirects both outputs for validation without overwriting the checked-in art.

const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const Canal = preload("res://games/sailor_man/world/canal_view.gd")
const Boat = preload("res://games/sailor_man/world/boat_rig.gd")
const Ribbon = preload("res://games/sailor_man/world/voice_ribbon.gd")
const Remo = preload("res://games/sailor_man/voice/key_voice_source.gd")
const Frame = preload("res://games/sailor_man/voice/voice_frame.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")
const OUTPUT := "res://games/sailor_man/assets"
const LEVEL_SIZE := Vector2i(640, 360)
const ICON_SIZE := 512
const ICON_SUPERSAMPLE := 2

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := "all"
	var output := OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		elif argument.begins_with("--output-dir="):
			output = argument.trim_prefix("--output-dir=")
	if only not in ["all", "icon", "levels"]:
		printerr("Unknown art selection '%s'; use --only=icon or --only=levels." % only)
		quit(1)
		return
	if output.strip_edges().is_empty():
		printerr("Art capture needs a nonempty output directory.")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("Sailor art capture needs a real Compatibility graphics window.")
		quit(1)
		return
	var directory := ProjectSettings.globalize_path(output)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		printerr("Cannot create art directory: %s" % error_string(error))
		quit(1)
		return
	if only in ["all", "icon"]:
		await _capture_icon(directory)
	if only in ["all", "levels"]:
		await _capture_levels(directory.path_join("levels"))
	quit(1 if _failed else 0)


## The icon is a synthetic illustration, never a saved human's best performance.
static func icon_viewport(parent: Node) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "SailorIconViewport"
	viewport.size = Vector2i.ONE * ICON_SIZE * ICON_SUPERSAMPLE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var world := Node3D.new()
	world.name = "IconModels"
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_CLEAR_COLOR
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Style.CREAM
	sky.ambient_light_energy = 0.7
	environment.environment = sky
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, 148, 0)
	light.light_color = Color("ffe6be")
	light.light_energy = 1.1
	world.add_child(light)
	var boat := Boat.new(0, "")
	boat.name = "BlueLaunch"
	world.add_child(boat)
	boat.plaque.hide()
	var source := Remo.new()
	source.begin()
	source.set_voice(true)
	var frames := source.advance(0.25)
	source.quiebre()
	frames.append_array(source.advance(0.18))
	source.set_target_pitch(1100.0)
	frames.append_array(source.advance(0.25))
	source.quiebre()
	frames.append_array(source.advance(0.18))
	source.remate()
	frames.append_array(source.advance(0.12))
	source.finish()
	var ribbon := Ribbon.new()
	ribbon.name = "IllustrativeRemo"
	world.add_child(ribbon)
	ribbon.set_intense_effects(false)
	ribbon.show_track(frames, {}, float(frames.size()) * Frame.STEP_SECONDS,
		Remo.profile(), Vector3.ZERO, Vector3(3.1, 0, 0))
	ribbon.position = boat.mouth.position
	# Gold faces +Z in the canal; this bow view looks from -Z.
	ribbon.rotation.y = PI
	ribbon.scale.x = -1.0
	var camera := Camera3D.new()
	camera.name = "IconCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.02
	camera.far = 50.0
	camera.current = true
	world.add_child(camera)
	var points: Array[Vector3] = []
	for node: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point in vertices:
				points.append(node.global_transform * point)
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	camera.position = center + Vector3(4.5, 3.0, -10.0)
	camera.look_at(center)
	var inverse := camera.global_transform.affine_inverse()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		var projected := inverse * point
		minimum = minimum.min(Vector2(projected.x, projected.y))
		maximum = maximum.max(Vector2(projected.x, projected.y))
	var offset := (minimum + maximum) * 0.5
	camera.position += camera.basis * Vector3(offset.x, offset.y, 0)
	camera.size = maxf(maximum.x - minimum.x, maximum.y - minimum.y) / 0.84
	return viewport


func _capture_icon(directory: String) -> void:
	var viewport := icon_viewport(get_root())
	await _settle()
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() \
		or image.get_size() != Vector2i.ONE * ICON_SIZE * ICON_SUPERSAMPLE:
		printerr("The icon did not render its complete supersampled image.")
		_failed = true
	else:
		image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
		_save(image, directory.path_join("game-icon.png"))
	viewport.queue_free()
	await process_frame
	await process_frame


func _capture_levels(directory: String) -> void:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		printerr("Cannot create arena art directory: %s" % error_string(error))
		_failed = true
		return
	get_root().min_size = Vector2i.ZERO
	get_root().size = LEVEL_SIZE
	var view := Canal.new()
	view.size = Vector2(LEVEL_SIZE)
	get_root().add_child(view)
	view.set_reduced_motion(true)
	for entry: Dictionary in Arenas.ENTRIES:
		if not view.configure(str(entry["id"])):
			_failed = true
			break
		view.present(0.5)
		await _settle()
		var image := view.viewport.get_texture().get_image()
		if image == null or image.is_empty() or image.get_size() != LEVEL_SIZE:
			printerr("Arena %s did not render a %s image (viewport %s)." % [
				entry["id"], LEVEL_SIZE, view.viewport.size,
			])
			_failed = true
			break
		_save(image, directory.path_join("%s.png" % entry["id"]))
		if _failed:
			break
	view.queue_free()
	await process_frame
	await process_frame


func _settle() -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(image: Image, path: String) -> void:
	var error := image.save_png(path)
	if error != OK:
		printerr("Cannot save %s: %s" % [path, error_string(error)])
		_failed = true
	else:
		print("Saved ", path)
