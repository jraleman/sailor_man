extends RefCounted

## Painted wood, clay and warm concrete; shared player colours stay untouched.

const INK := Color("1f2a36")
const CANAL := Color("2f7f86")
const JUNGLE := Color("3f7d3a")
const SUN := Color("f4b941")
const RED := Color("c8413b")
const CREAM := Color("fbf2df")
const WOOD := Color("bd8555")
const CONCRETE := Color("b8ad96")


## Explicit sRGB vertex colours keep the authored palette consistent in GL.
static func material(unshaded := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.88
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result
