extends SceneTree

## The prototype icon must stay reproducible from the original launch and
## synthetic Remo geometry, without a person's voice or a silent CLI failure.

const Capture = preload("res://games/sailor_man/tools/capture_art.gd")
const Manifest = preload("res://games/sailor_man/game.gd")
const Options = preload("res://games/sailor_man/sailor_man_options.gd")
const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const ICON := "res://games/sailor_man/assets/game-icon.png"

var _failures := PackedStringArray()
var _capture_directory := ""
var _maximum_draws := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sailor-icon-capture-dir="):
			_capture_directory = argument.trim_prefix("--sailor-icon-capture-dir=")
	if not _capture_directory.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_capture_directory) == OK,
			"Requested icon captures need a writable directory.")
	var texture := load(ICON) as Texture2D
	var icon := texture.get_image() if texture != null else null
	_expect(icon != null and not icon.is_empty(), "The declared icon must be a real PNG.")
	if icon == null or icon.is_empty():
		quit(1)
		return
	_expect(icon.get_size() == Vector2i.ONE * Capture.ICON_SIZE and icon.is_invisible() == false,
		"The model icon must be square, full-resolution and nonempty.")
	_assert_alpha(icon)
	_test_capture_failures()
	if DisplayServer.get_name() != "headless":
		_test_cli_outputs()
		await _test_model_capture(icon)
		await _test_branding()
	if _failures.is_empty():
		print("Sailor art capture tests passed (%s, maximum %d icon draws)." % [
			DisplayServer.get_name(), _maximum_draws,
		])
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_capture_failures() -> void:
	var output: Array = []
	var arguments := PackedStringArray([
		"--headless", "--audio-driver", "Dummy",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://games/sailor_man/tools/capture_art.gd",
		"--", "--game=all", "--only=icon",
	])
	var code := OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code != 0 and "\n".join(output).contains("real Compatibility graphics window"),
		"Headless capture must explicitly fail, not write a blank success-shaped icon.")
	output.clear()
	arguments[arguments.size() - 1] = "--only=unknown"
	code = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code != 0 and "\n".join(output).contains("Unknown art selection"),
		"A misspelled art selector must not silently skip capture or regenerate everything.")
	output.clear()
	arguments[arguments.size() - 1] = "--only="
	code = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code != 0 and "\n".join(output).contains("Unknown art selection"),
		"An explicit empty art selector must fail rather than overwrite every image.")
	output.clear()
	arguments[arguments.size() - 1] = "--only=icon"
	arguments.append("--output-dir=")
	code = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code != 0 and "\n".join(output).contains("nonempty output directory"),
		"An empty output path must not silently become the project directory.")


func _test_cli_outputs() -> void:
	var directory := "user://sailor_art_capture_test_%d" % OS.get_process_id()
	var icon_path := directory.path_join("game-icon.png")
	_run_capture(["--only=icon", "--output-dir=" + directory])
	_expect(FileAccess.file_exists(icon_path)
		and not DirAccess.dir_exists_absolute(directory.path_join("levels")),
		"--only=icon must capture just the model icon.")
	var icon_hash := FileAccess.get_sha256(icon_path)
	_run_capture(["--only=levels", "--output-dir=" + directory])
	_expect(FileAccess.get_sha256(icon_path) == icon_hash,
		"--only=levels must leave an existing icon untouched.")
	_assert_level_outputs(directory)
	_remove_outputs(directory)
	_run_capture(["--output-dir=" + directory])
	_expect(FileAccess.get_sha256(icon_path) == icon_hash,
		"Default capture must reproduce the icon as well as the five level stills.")
	_assert_level_outputs(directory)
	_remove_outputs(directory)


func _run_capture(extra: Array[String]) -> void:
	var arguments := PackedStringArray([
		"--audio-driver", "Dummy", "--windowed", "--resolution", "640x360",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://games/sailor_man/tools/capture_art.gd",
		"--", "--game=all",
	])
	arguments.append_array(PackedStringArray(extra))
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(code == 0 and not "\n".join(output).contains("SCRIPT ERROR"),
		"Real capture must exit successfully: " + "\n".join(output))


func _assert_level_outputs(directory: String) -> void:
	for arena: Dictionary in Arenas.ENTRIES:
		var path := directory.path_join("levels/%s.png" % arena["id"])
		_expect(FileAccess.file_exists(path), "Capture must retain the %s level still." % arena["id"])
		if not FileAccess.file_exists(path):
			continue
		var actual := Image.load_from_file(path)
		var texture := load("res://games/sailor_man/assets/levels/%s.png" % arena["id"]) as Texture2D
		_expect(actual.get_size() == Capture.LEVEL_SIZE
			and _image_error(actual, texture.get_image()) < 0.01,
			"Art-tool changes must preserve the real %s level framing and colours." % arena["id"])


func _remove_outputs(directory: String) -> void:
	var paths: Array[String] = [directory.path_join("game-icon.png")]
	for arena: Dictionary in Arenas.ENTRIES:
		paths.append(directory.path_join("levels/%s.png" % arena["id"]))
	for path in paths:
		if FileAccess.file_exists(path):
			_expect(DirAccess.remove_absolute(path) == OK, "Could not remove test art " + path)
	if DirAccess.dir_exists_absolute(directory.path_join("levels")):
		_expect(DirAccess.remove_absolute(directory.path_join("levels")) == OK,
			"Could not remove the test's level-art directory.")
	if DirAccess.dir_exists_absolute(directory):
		_expect(DirAccess.remove_absolute(directory) == OK,
			"Could not remove the test's art directory.")


func _test_model_capture(icon: Image) -> void:
	var buses := AudioServer.bus_count
	var viewport := Capture.icon_viewport(get_root())
	await _settle()
	_expect(viewport.find_world_3d() != get_root().find_world_3d(),
		"The icon's lighting and camera must be isolated from the host UI.")
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		_expect(viewport.find_children("*", type, true, false).is_empty(),
			"Art capture must never create a microphone, tone or other audio player.")
	_expect(AudioServer.bus_count == buses, "An illustrative contour must not open a capture bus.")
	var image := viewport.get_texture().get_image()
	image.resize(Capture.ICON_SIZE, Capture.ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	_expect(_image_error(image, icon) < 0.01,
		"The checked-in icon must match the actual capture, allowing rasterizer edge differences.")
	var camera := viewport.get_node("IconModels/IconCamera") as Camera3D
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-2.0)
	for node: MeshInstance3D in viewport.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := node.global_transform * vertex
				_expect(not camera.is_position_behind(point)
					and bounds.has_point(camera.unproject_position(point)),
					"The icon must retain the real bow, crew, pennant and complete contour.")
	var ribbon := viewport.get_node("IconModels/IllustrativeRemo") as Node3D
	ribbon.hide()
	await _settle()
	var without_ribbon := viewport.get_texture().get_image()
	without_ribbon.resize(Capture.ICON_SIZE, Capture.ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	for size in [512, 64, 32]:
		var before := image.duplicate() as Image
		var after := without_ribbon.duplicate() as Image
		before.resize(size, size, Image.INTERPOLATE_LANCZOS)
		after.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var gold := _gold_changes(before, after)
		_expect(gold >= (100 if size == 512 else 5 if size == 64 else 2),
			"The actual gold contour must survive at %d pixels, not hide its coloured face." % size)
		_expect(_blue_pixels(before) >= (500 if size == 512 else 12 if size == 64 else 3),
			"The original blue launch must remain recognizable at %d pixels." % size)
		_capture(before, "icon-%d.png" % size)
	ribbon.show()
	await _settle()
	_maximum_draws = viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_expect(_maximum_draws > 0 and _maximum_draws < 10,
		"The static original icon should not require an unbatched scene.")
	viewport.queue_free()
	await _settle()


func _test_branding() -> void:
	var settings := get_root().get_node("Settings")
	var original: Dictionary = settings.get("_values").duplicate(true)
	var values := original.duplicate(true)
	values[Settings.REDUCED_MOTION_KEY] = true
	values["ui/scale"] = 1.0
	settings.set("_values", values)
	var old_size := get_root().size
	var old_minimum := get_root().min_size
	get_root().min_size = Vector2i.ZERO
	get_root().size = Vector2i(1280, 720)
	settings.call("_update_content_scale")
	var manifest := Manifest.manifest()
	var logo := manifest.theme.logo_texture()
	GameCatalog.restrict_to(Options.GAME_ID)
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await _settle()
	var face := menu.get_node("%Face") as Sprite3D
	_expect(face.texture == logo and face.modulate == Color.WHITE,
		"The standalone title must use the model PNG without recolouring its blue paint.")
	var title_image := get_root().get_texture().get_image()
	_capture(title_image, "icon-title.png")
	face.hide()
	await _settle()
	_expect(_pixel_changes(title_image, get_root().get_texture().get_image()) > 12,
		"The model icon must actually render on the title's 3D cartridge.")
	menu.queue_free()
	await _settle()
	GameCatalog.clear_restriction()
	GameCatalog.select(Options.GAME_ID)
	var picker := (load("res://scenes/menus/game_select.tscn") as PackedScene).instantiate()
	get_root().add_child(picker)
	await _settle()
	var found := false
	for node in picker.get_node("%Track").get_children():
		if node.has_method("game_id") and str(node.call("game_id")) == Options.GAME_ID:
			found = true
			_expect(node.get("_logo") == logo and node.get("_logo_color") == Color.WHITE,
				"The collection cartridge must use the same full-colour model icon.")
	_expect(found, "The collection must retain the actual Sailor cartridge.")
	_capture(get_root().get_texture().get_image(), "icon-picker.png")
	picker.call("_browse", -1)
	await _settle()
	for node in picker.get_node("%Track").get_children():
		if node.has_method("game_id") and str(node.call("game_id")) == Options.GAME_ID:
			var standing := get_root().get_texture().get_image()
			_capture(standing, "icon-picker-standing.png")
			node.set("_logo", null)
			node.call("_redraw_all")
			await _settle()
			_expect(_pixel_changes(standing, get_root().get_texture().get_image()) > 12,
				"The standing cartridge must actually draw the new logo, not only store it.")
	picker.queue_free()
	await _settle()
	var card := (load("res://ui/components/share_card.tscn") as PackedScene).instantiate()
	get_root().add_child(card)
	card.call("configure", {"game_id": Options.GAME_ID, "player_count": 1})
	await _settle()
	var shared_logo: TextureRect = card.get("_logo")
	_expect(shared_logo.texture == logo and shared_logo.modulate == Color.WHITE,
		"Shared cards must use the same icon, not the old SVG or studio fallback.")
	card.queue_free()
	await _settle()
	settings.set("_values", original)
	get_root().min_size = old_minimum
	get_root().size = old_size
	settings.call("_update_content_scale")


func _assert_alpha(image: Image) -> void:
	var visible := 0
	var clear := 0
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			visible += int(alpha > 0.5)
			clear += int(alpha < 0.01)
	_expect(visible > 20000 and clear > 20000,
		"The icon must have a real opaque model and transparent surround, not an opaque tile.")
	for point in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0),
			image.get_size() - Vector2i.ONE, Vector2i(0, image.get_height() - 1)]:
		_expect(image.get_pixelv(point).a == 0.0, "Icon corners must stay transparent.")


func _image_error(first: Image, second: Image) -> float:
	if first.get_size() != second.get_size():
		return INF
	var error := 0.0
	for y in range(0, first.get_height(), 3):
		for x in range(0, first.get_width(), 3):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			error += absf(a.a - b.a)
			error += absf(a.r * a.a - b.r * b.a)
			error += absf(a.g * a.a - b.g * b.a)
			error += absf(a.b * a.a - b.b * b.a)
	return error / (ceilf(float(first.get_width()) / 3.0)
		* ceilf(float(first.get_height()) / 3.0) * 4.0)


func _gold_changes(first: Image, second: Image) -> int:
	var count := 0
	for y in first.get_height():
		for x in first.get_width():
			var color := first.get_pixel(x, y)
			if color != second.get_pixel(x, y) and color.a > 0.3 \
				and color.r > 0.65 and color.g > 0.40 and color.b < 0.55:
				count += 1
	return count


func _blue_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.5 and color.b > 0.5 and color.b > color.r * 1.25:
				count += 1
	return count


func _pixel_changes(first: Image, second: Image) -> int:
	if first.get_size() != second.get_size():
		return 0
	var count := 0
	for y in range(0, first.get_height(), 3):
		for x in range(0, first.get_width(), 3):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				count += 1
	return count


func _capture(image: Image, name: String) -> void:
	if not _capture_directory.is_empty():
		_expect(image.save_png(_capture_directory.path_join(name)) == OK,
			"Could not save requested icon inspection " + name)


func _settle() -> void:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
