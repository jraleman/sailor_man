extends Control

## A deliberately plain, isolated GL-compatible lock, not the finished canal.
## Static framing keeps both labelled boats visible with reduced motion too.

const Identity = preload("res://scripts/player_identity.gd")

var viewport: SubViewport
var camera: Camera3D
var boats: Array[Node3D] = []
var _water: MeshInstance3D


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
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("203941")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("fbf2df")
	sky.ambient_light_energy = 0.75
	environment.environment = sky
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.2
	world.add_child(light)
	_water = _box(world, Vector3(10, 0.15, 8), Vector3(0, -0.5, 0), Color("2f7f86"))
	_box(world, Vector3(1, 2, 9), Vector3(-5.3, 0, 0), Color("747e80"))
	_box(world, Vector3(1, 2, 9), Vector3(5.3, 0, 0), Color("747e80"))
	_box(world, Vector3(10, 1.4, 0.5), Vector3(0, -0.3, -4), Color("8d9695"))
	for index in 2:
		var boat := Node3D.new()
		boat.position = Vector3(-2.2 if index == 0 else 2.2, 0, 0)
		world.add_child(boat)
		boats.append(boat)
		var color := Identity.color(index)
		_box(boat, Vector3(2.2, 0.6, 3.2), Vector3.ZERO, color)
		_box(boat, Vector3(1.3, 0.8, 1.3), Vector3(0, 0.65, 0.3), Color("fbf2df"))
		_box(boat, Vector3(0.06, 1.4, 0.06), Vector3(0, 1.3, -0.8), Color("1f2a36"))
		_box(boat, Vector3(0.7, 0.45, 0.08), Vector3(0.3, 1.75, -0.8), color)
		var plaque := Label3D.new()
		plaque.text = "P1" if index == 0 else "CPU"
		plaque.font_size = 64
		plaque.pixel_size = 0.012
		plaque.position = Vector3(0, 1.6, 0.5)
		plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plaque.no_depth_test = true
		boat.add_child(plaque)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 12.5
	camera.position = Vector3(0, 9, 10)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.3, 0))
	camera.current = true
	viewport.size_changed.connect(_fit_camera)
	_fit_camera()
	visibility_changed.connect(_update_visibility)
	_update_visibility()


## Water follows the clock as an essential state change, never as ambient motion.
func present(chamber_fraction: float) -> void:
	var height := lerpf(-0.5, 0.3, chamber_fraction)
	_water.position.y = height
	for boat in boats:
		boat.position.y = height + 0.35


func _update_visibility() -> void:
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)


func _fit_camera() -> void:
	var aspect := float(viewport.size.x) / maxf(float(viewport.size.y), 1.0)
	camera.size = maxf(12.5, 6.5 * aspect)


func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	node.material_override = material
	parent.add_child(node)
	return node
