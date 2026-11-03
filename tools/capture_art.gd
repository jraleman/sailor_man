extends SceneTree

## Reproducible setup icons come from the same original arena meshes as play.
## Run without --headless; this never creates a microphone or a duel.

const Arenas = preload("res://games/sailor_man/canal_arenas.gd")
const Canal = preload("res://games/sailor_man/world/canal_view.gd")
const OUTPUT := "res://games/sailor_man/assets/levels"
const SIZE := Vector2i(640, 360)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Arena art capture needs a real Compatibility graphics window.")
		quit(1)
		return
	var directory := ProjectSettings.globalize_path(OUTPUT)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		printerr("Cannot create arena art directory: %s" % error_string(error))
		quit(1)
		return
	get_root().min_size = Vector2i.ZERO
	get_root().size = SIZE
	var view := Canal.new()
	view.size = Vector2(SIZE)
	get_root().add_child(view)
	view.set_reduced_motion(true)
	var failed := false
	for entry: Dictionary in Arenas.ENTRIES:
		if not view.configure(str(entry["id"])):
			failed = true
			break
		view.present(0.5)
		for _frame in 8:
			await process_frame
		var image := view.viewport.get_texture().get_image()
		if image == null or image.is_empty() or image.get_size() != SIZE:
			printerr("Arena %s did not render a %s image (viewport %s)." % [
				entry["id"], SIZE, view.viewport.size,
			])
			failed = true
			break
		var path := directory.path_join("%s.png" % entry["id"])
		error = image.save_png(path)
		if error != OK:
			printerr("Cannot save %s: %s" % [path, error_string(error)])
			failed = true
			break
		print("Saved ", path)
	view.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
