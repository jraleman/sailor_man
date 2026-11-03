extends Control

## Parked original launches and frozen best-turn meshes, not exported voice tracks.
## Each human has their own portrait; a synthetic rival or seed never stands in.

const Boat = preload("res://games/sailor_man/world/boat_rig.gd")
const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")
const Identity = preload("res://scripts/player_identity.gd")
const Outfit = preload("res://games/sailor_man/world/launch_outfit.gd")

var portraits: Array[Dictionary] = []
var _layout: VBoxContainer
var _turns: Array = []
var _hot_seat := false
var _scorer := false
var _outfits: Array[Dictionary] = []
var _outfit_error := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout = VBoxContainer.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_theme_constant_override("separation", 8)
	add_child(_layout)
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(_update_visibility)
	_install_portraits()


## Only renderer-only meshes and score labels are retained, never frame/profile data.
func configure(data: Dictionary) -> void:
	var supplied: Variant = data.get("sailor_art", [])
	if not supplied is Array:
		push_error("Sailor share artwork needs an array of best-turn portraits.")
		_turns = []
	else:
		_turns = supplied.duplicate(true)
	_hot_seat = str(data.get("sailor_mode", "")) == "hot_seat"
	_scorer = str(data.get("sailor_mode", "")) == "scorer"
	_outfits.clear()
	_outfit_error = ""
	var supplied_outfits: Variant = data.get("sailor_outfits", [])
	if not supplied_outfits is Array:
		_outfit_error = "Share launch outfits need an array of cosmetic ids."
	else:
		for singer in 2 if _hot_seat else 1:
			var selected: Variant = supplied_outfits[singer] \
				if singer < supplied_outfits.size() else {}
			if not selected is Dictionary:
				_outfit_error = "Each share launch needs a cosmetic-id dictionary."
				break
			_outfit_error = Outfit.validate(selected)
			if not _outfit_error.is_empty():
				break
			_outfits.append(Outfit.complete(selected))
	if not _outfit_error.is_empty():
		push_error("Sailor share: " + _outfit_error)
	if is_node_ready():
		_install_portraits()


func _install_portraits() -> void:
	for portrait: Dictionary in portraits:
		var viewport: SubViewport = portrait["viewport"]
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.queue_free()
	for row in _layout.get_children():
		_layout.remove_child(row)
		row.queue_free()
	portraits.clear()
	if not _outfit_error.is_empty():
		var error := Label.new()
		error.text = "This share launch outfit is unavailable."
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_layout.add_child(error)
		return
	for singer in 2 if _hot_seat else 1:
		var turn: Dictionary = _turns[singer] if singer < _turns.size() else {}
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 0)
		_layout.add_child(row)
		var title := Label.new()
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Identity.color(singer).lightened(0.3))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var description := "NO COMPLETED TURN" if turn.is_empty() else \
			"SILENT TURN" if turn["mesh"] == null else "BEST TEST" if _scorer else "BEST TURN"
		title.text = "P%d - %s" % [singer + 1, description]
		if not turn.is_empty() and not (turn["paddles"] as PackedInt32Array).is_empty():
			var paddles := PackedStringArray()
			for paddle: int in turn["paddles"]:
				paddles.append(str(paddle))
			title.text = "P%d %s | %s" % [
				singer + 1, "SILENT" if turn["mesh"] == null else "BEST",
				"/".join(paddles),
			]
		row.add_child(title)
		var portrait := _make_portrait(singer, turn)
		var image := TextureRect.new()
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		image.texture = (portrait["viewport"] as SubViewport).get_texture()
		row.add_child(image)
		portrait["image"] = image
		portraits.append(portrait)
		image.resized.connect(_frame_portrait.bind(singer))
		_frame_portrait(singer)
	_update_visibility()


func _make_portrait(singer: int, turn: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "Singer%dShareViewport" % (singer + 1)
	viewport.size = Vector2i(512, 256)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("24494e")
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
	var boat := Boat.new(singer, "P%d" % (singer + 1))
	if singer < _outfits.size():
		boat.set_outfit(_outfits[singer])
	var side := -1.0 if singer == 0 else 1.0
	boat.position = Vector3(side, 0, 0)
	boat.rotation.y = 0.55 if singer == 0 else -0.55
	world.add_child(boat)
	var builder := Builder.new()
	builder.cylinder(Vector3(side, -0.39, 0), 1.95, 0.12, Style.CANAL,
		Vector3.ZERO, 48)
	var water := builder.build(world, "StillWater", Style.material())
	var ribbon := MeshInstance3D.new()
	ribbon.name = "FrozenBestTurn"
	ribbon.mesh = turn.get("mesh")
	var material := Style.material(true)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ribbon)
	ribbon.position = boat.mouth.global_position
	# The canal ribbon's gold face looks +Z; the bow portrait looks from -Z.
	ribbon.rotation.y = PI
	ribbon.scale.x = -1.0 if singer == 0 else 1.0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	world.add_child(camera)
	var target := Vector3(0, 1.0, 0)
	camera.position = target + Vector3(0, 3.0, -10)
	camera.look_at(target)
	return {
		"viewport": viewport, "world": world, "boat": boat, "ribbon": ribbon,
		"camera": camera, "meshes": [boat.body, water, ribbon],
	}


func _frame_portrait(singer: int) -> void:
	var portrait := portraits[singer]
	var image: TextureRect = portrait["image"]
	if image.size.x <= 0.0 or image.size.y <= 0.0:
		return
	var viewport: SubViewport = portrait["viewport"]
	viewport.size = Vector2i(maxi(1, roundi(image.size.x * 1.5)),
		maxi(1, roundi(image.size.y * 1.5)))
	var camera: Camera3D = portrait["camera"]
	var inverse := camera.global_transform.affine_inverse()
	var horizontal := 0.0
	var vertical := 0.0
	for mesh: MeshInstance3D in portrait["meshes"]:
		if mesh.mesh == null:
			continue
		for corner in 8:
			var point := inverse * (mesh.global_transform * mesh.get_aabb().get_endpoint(corner))
			horizontal = maxf(horizontal, absf(point.x))
			vertical = maxf(vertical, absf(point.y))
	var aspect := float(viewport.size.x) / float(viewport.size.y)
	camera.size = maxf(vertical * 2.0, horizontal * 2.0 / aspect) / 0.88


func _update_visibility() -> void:
	for portrait: Dictionary in portraits:
		(portrait["viewport"] as SubViewport).render_target_update_mode = \
			SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
