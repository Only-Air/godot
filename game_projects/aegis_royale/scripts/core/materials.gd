class_name MatLib
extends RefCounted

## Shared material factory. Keeps draw state consistent across the whole game
## so the procedural geometry reads as one coherent art style.

static var _flat_cache: Dictionary = {}
static var _alpha_cache: Dictionary = {}

static func flat(color: Color, emission: float = 0.0, rough: float = 0.82) -> StandardMaterial3D:
	var key: String = "%d_%d_%d_%d_%d" % [
		int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0),
		int(emission * 20.0), int(rough * 20.0)
	]
	if _flat_cache.has(key):
		return _flat_cache[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color * emission
	_flat_cache[key] = m
	return m

static func glow(color: Color, strength: float = 1.4) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color * strength
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func alpha(color: Color, rough: float = 0.6, unshaded: bool = false) -> StandardMaterial3D:
	var key: String = "%d_%d_%d_%d_%d_%d" % [
		int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0),
		int(color.a * 100.0), int(rough * 20.0), 1 if unshaded else 0
	]
	if _alpha_cache.has(key):
		return _alpha_cache[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_alpha_cache[key] = m
	return m

static func metal(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.75
	m.roughness = 0.32
	return m

static func foliage(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
