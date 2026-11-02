extends RefCounted

## Adapted locally from Cube Trials: original details share a few lit surfaces,
## with real bevels and exterior normals on the Compatibility renderer.

var _surface := SurfaceTool.new()
var _vertex_count := 0


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


## Godot's front-facing index order is clockwise, while normals point outside.
func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	_vertex(a, normal, color)
	_vertex(c, normal, color)
	_vertex(b, normal, color)


## Flat panels and palm leaves remain ordinary geometry, not renderer effects.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	triangle(a, b, c, color)
	triangle(a, c, d, color)


## Native primitives retain their exterior normals when rotated.
func box(at: Vector3, dimensions: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var primitive := BoxMesh.new()
	primitive.size = dimensions
	_append(primitive, Transform3D(Basis.from_euler(rotation), at), color)


## Small bevels catch the warm key light without a post-processing dependency.
func rounded_box(
	at: Vector3, dimensions: Vector3, radius: float, color: Color,
	rotation := Vector3.ZERO
) -> void:
	var half := dimensions * 0.5
	var cut := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.9)
	var core := half - Vector3.ONE * cut
	var transform := Transform3D(Basis.from_euler(rotation), at)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var us: Array[float] = [-half[u], -core[u], core[u], half[u]]
		var vs: Array[float] = [-half[v], -core[v], core[v], half[v]]
		for sign_value: float in [-1.0, 1.0]:
			for row in 3:
				for column in 3:
					var points: Array[Vector3] = []
					var normals: Array[Vector3] = []
					for corner in [Vector2i(0, 0), Vector2i(1, 0),
						Vector2i(1, 1), Vector2i(0, 1)]:
						var raw := Vector3.ZERO
						raw[axis] = half[axis] * sign_value
						raw[u] = us[column + corner.x]
						raw[v] = vs[row + corner.y]
						var inner := raw.clamp(-core, core)
						var normal := (raw - inner).normalized()
						points.append(transform * (inner + normal * cut))
						normals.append(transform.basis * normal)
					for indices in [Vector3i(0, 1, 2), Vector3i(0, 2, 3)]:
						var a: int = indices.x
						var b: int = indices.y
						var c: int = indices.z
						var outward := (points[b] - points[a]).cross(points[c] - points[a])
						if outward.dot(normals[a] + normals[b] + normals[c]) < 0.0:
							var swap := b
							b = c
							c = swap
						for index in [a, c, b]:
							_vertex(points[index], normals[index], color)


## Endpoint-authored beams keep rails, tow lines and miter leaves aligned.
func beam(a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var primitive := BoxMesh.new()
	primitive.size = Vector3(thickness, a.distance_to(b), thickness)
	var basis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	_append(primitive, Transform3D(basis, (a + b) * 0.5), color)


## Wheels and bollards are low-poly solids with correctly lit end caps.
func cylinder(
	at: Vector3, radius: float, height: float, color: Color,
	rotation := Vector3.ZERO, segments := 12, top_ratio := 1.0
) -> void:
	var primitive := CylinderMesh.new()
	primitive.top_radius = radius * top_ratio
	primitive.bottom_radius = radius
	primitive.height = height
	primitive.radial_segments = segments
	primitive.rings = 1
	_append(primitive, Transform3D(Basis.from_euler(rotation), at), color)


## Rounded toy figures and banks do not need imported models or textures.
func ellipsoid(at: Vector3, dimensions: Vector3, color: Color, segments := 10) -> void:
	var primitive := SphereMesh.new()
	primitive.radius = 0.5
	primitive.height = 1.0
	primitive.radial_segments = segments
	primitive.rings = maxi(4, segments / 2)
	_append(primitive, Transform3D(Basis.from_scale(dimensions), at), color)


## Fender holes remain visible geometry, including in an orthographic shot.
func torus(at: Vector3, inner: float, outer: float, color: Color) -> void:
	var primitive := TorusMesh.new()
	primitive.inner_radius = inner
	primitive.outer_radius = outer
	primitive.rings = 12
	primitive.ring_segments = 6
	_append(primitive, Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), at), color)


## Static scenery indexes once; frequently rebuilt ribbons can omit that work.
func finish(indexed := true) -> ArrayMesh:
	assert(_vertex_count > 0, "A Sailor Man mesh must contain geometry.")
	if indexed:
		_surface.index()
	return _surface.commit()


## Each authored batch becomes one surface instead of one draw per fitting.
func build(parent: Node3D, node_name: String, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = finish()
	node.material_override = material
	parent.add_child(node)
	return node


func _append(primitive: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := primitive.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for index in indices:
		_vertex(transform * vertices[index], (normal_basis * normals[index]).normalized(), color)


func _vertex(point: Vector3, normal: Vector3, color: Color) -> void:
	_surface.set_color(color)
	_surface.set_normal(normal)
	_surface.add_vertex(point)
	_vertex_count += 1
