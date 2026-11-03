extends Node3D

## One original launch rig for both seats, previews and injected cosmetics.
## Plain toy crew imply no named captain, traditional dress or recorded voice.

const Builder = preload("res://games/sailor_man/world/mesh_builder.gd")
const Style = preload("res://games/sailor_man/world/canal_style.gd")
const Identity = preload("res://scripts/player_identity.gd")
const Outfit = preload("res://games/sailor_man/world/launch_outfit.gd")
const OUTLINE := [
	Vector2(-0.7, 1.5), Vector2(0.7, 1.5), Vector2(1.0, 1.05),
	Vector2(1.04, -0.7), Vector2(0.72, -1.42), Vector2(0, -1.9),
	Vector2(-0.72, -1.42), Vector2(-1.04, -0.7), Vector2(-1.0, 1.05),
]

var mouth: Marker3D
var hat_slot: Marker3D
var bow_slot: Marker3D
var plaque: Label3D
var body: MeshInstance3D
var outfit := Outfit.complete({})
var _seat := 0


func _init(seat := 0, seat_label := "P1") -> void:
	_seat = seat
	body = MeshInstance3D.new()
	body.name = "BoatMesh"
	body.mesh = _build_body()
	body.material_override = Style.material()
	add_child(body)
	mouth = _anchor("Mouth", Vector3(0.21 if seat == 0 else -0.21, 1.13, -0.79))
	hat_slot = _anchor("HatSlot", Vector3(0, 1.40, -0.79))
	bow_slot = _anchor("BowSlot", Vector3(0, 0.33, -1.72))
	plaque = Label3D.new()
	plaque.name = "SeatPlaque"
	plaque.text = seat_label
	plaque.font_size = 64
	plaque.pixel_size = 0.010
	plaque.modulate = Style.CREAM
	plaque.outline_modulate = Style.INK
	plaque.outline_size = 12
	plaque.position = Vector3(0, 1.61, 0.56)
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plaque.no_depth_test = true
	add_child(plaque)


## Rebuild only the batched surface, preserving mouths, plaques and live ribbons.
func set_outfit(selected: Dictionary) -> bool:
	var error := Outfit.validate(selected)
	if not error.is_empty():
		push_error("Sailor launch: " + error)
		return false
	var next := Outfit.complete(selected)
	if next != outfit:
		outfit = next
		body.mesh = _build_body()
	return true


func _build_body() -> ArrayMesh:
	var seat := _seat
	var paint := Identity.color(seat)
	var builder := Builder.new()
	_hull(builder, paint, str(outfit["paint"]))
	builder.rounded_box(Vector3(0, 0.67, 0.52), Vector3(1.35, 0.83, 1.3),
		0.10, Style.CREAM)
	builder.rounded_box(Vector3(0, 1.13, 0.52), Vector3(1.52, 0.14, 1.46),
		0.06, paint.lightened(0.15))
	for side: float in [-1.0, 1.0]:
		builder.box(Vector3(side * 0.681, 0.77, 0.50),
			Vector3(0.016, 0.35, 0.85), Style.INK)
		builder.beam(Vector3(side * 0.72, 0.32, 1.12),
			Vector3(side * 0.72, 1.1, 1.12), 0.055, Style.WOOD)
		for z in [-0.62, 0.65]:
			builder.torus(Vector3(side * 1.02, 0.02, z), 0.10, 0.23, Style.INK)
	builder.box(Vector3(0, 0.77, 1.179), Vector3(0.9, 0.35, 0.016), Style.INK)
	builder.box(Vector3(0, 0.77, -0.139), Vector3(0.9, 0.35, 0.016), Style.INK)
	builder.cylinder(Vector3(-0.83, 1.30, 0.95), 0.035, 2.15, Style.WOOD)
	builder.triangle(Vector3(-0.80, 2.32, 0.95), Vector3(-0.80, 1.91, 0.95),
		Vector3(-0.06, 2.18, 0.95), paint)
	builder.triangle(Vector3(-0.80, 2.32, 0.949), Vector3(-0.06, 2.18, 0.949),
		Vector3(-0.80, 1.91, 0.949), paint)
	Outfit.pennant(builder, str(outfit["pennant"]), paint)
	_crew(builder, 1.0 if seat == 0 else -1.0, paint,
		Color("b8784e") if seat == 0 else Color("d59a67"))
	Outfit.decorate(builder, outfit, 1.0 if seat == 0 else -1.0, paint)
	return builder.finish()


func _hull(builder: Builder, paint: Color, finish: String) -> void:
	var lower := Style.CREAM if finish == "paint_cream_band" else \
		paint.darkened(0.40) if finish == "paint_deep_hull" else paint
	for index in OUTLINE.size():
		var a: Vector2 = OUTLINE[index]
		var b: Vector2 = OUTLINE[(index + 1) % OUTLINE.size()]
		var top_a := Vector3(a.x, 0.24, a.y)
		var top_b := Vector3(b.x, 0.24, b.y)
		var bottom_a := Vector3(a.x * 0.70, -0.30, a.y * 0.83)
		var bottom_b := Vector3(b.x * 0.70, -0.30, b.y * 0.83)
		if finish == "paint_identity":
			builder.quad(top_a, bottom_a, bottom_b, top_b, paint)
		else:
			var middle_a := top_a.lerp(bottom_a, 0.40)
			var middle_b := top_b.lerp(bottom_b, 0.40)
			builder.quad(top_a, middle_a, middle_b, top_b, paint)
			builder.quad(middle_a, bottom_a, bottom_b, middle_b, lower)
		builder.triangle(Vector3(0, 0.24, 0), top_a, top_b, Style.WOOD)
		builder.triangle(Vector3(0, -0.30, 0), bottom_b, bottom_a, lower.darkened(0.22))
		builder.beam(top_a + Vector3.UP * 0.035, top_b + Vector3.UP * 0.035,
			0.07, Style.CREAM)
	for row in 7:
		var z := -1.15 + float(row) * 0.35
		builder.box(Vector3(0, 0.247, z), Vector3(1.35, 0.012, 0.018),
			Style.WOOD.darkened(0.22))
	for z in [-1.2, 1.18]:
		builder.cylinder(Vector3(0.68, 0.34, z), 0.07, 0.17, Style.INK)
		builder.cylinder(Vector3(0.68, 0.43, z), 0.10, 0.035, Style.INK)


func _crew(builder: Builder, facing: float, paint: Color, skin: Color) -> void:
	var at := Vector3(0, 0.26, -0.79)
	for z: float in [-0.09, 0.09]:
		builder.box(at + Vector3(0, 0.17, z), Vector3(0.21, 0.34, 0.13), Style.INK)
	builder.rounded_box(at + Vector3(0, 0.52, 0), Vector3(0.38, 0.41, 0.34),
		0.07, Style.CREAM)
	builder.box(at + Vector3(facing * 0.195, 0.55, 0),
		Vector3(0.02, 0.16, 0.26), paint)
	for z: float in [-0.24, 0.24]:
		builder.beam(at + Vector3(0, 0.64, z), at + Vector3(facing * 0.14, 0.36, z),
			0.11, skin)
	builder.ellipsoid(at + Vector3(0, 0.92, 0), Vector3(0.36, 0.40, 0.34), skin)
	builder.ellipsoid(at + Vector3(-facing * 0.055, 1.06, 0),
		Vector3(0.31, 0.13, 0.34), Style.INK)
	for z: float in [-0.065, 0.065]:
		builder.ellipsoid(at + Vector3(facing * 0.174, 0.95, z),
			Vector3(0.035, 0.035, 0.035), Style.INK, 6)


func _anchor(anchor_name: String, at: Vector3) -> Marker3D:
	var anchor := Marker3D.new()
	anchor.name = anchor_name
	anchor.position = at
	add_child(anchor)
	return anchor
