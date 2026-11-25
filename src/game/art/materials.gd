extends RefCounted
## Shared material + font factory for the presentation layer (no gameplay).

static var _cache := {}

static func cloth(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.78
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m

static func skin(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m

static func glossy(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.18
	m.metallic = 0.1
	m.metallic_specular = 0.8
	m.rim_enabled = true
	m.rim = 0.35
	return m

static func metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.25
	m.metallic = 0.9
	return m

static func emissive(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

## Unshaded, alpha-blended, optionally always-on-top-ish (no depth test).
static func flat(c: Color, no_depth: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = no_depth
	return m

static func visor() -> StandardMaterial3D:
	if not _cache.has("visor"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.07, 0.1)
		m.metallic = 0.6
		m.roughness = 0.05
		_cache["visor"] = m
	return _cache["visor"]

static func shader(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m

static func blob_shadow() -> ShaderMaterial:
	if not _cache.has("blob"):
		_cache["blob"] = shader("res://src/game/art/blob_shadow.gdshader")
	return _cache["blob"]

static func number_font() -> Font:
	if not _cache.has("num"):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Oswald", "Impact", "Bebas Neue", "Arial Black", "Ubuntu Sans", "Ubuntu", "Liberation Sans", "DejaVu Sans"])
		f.font_weight = 800
		_cache["num"] = f
	return _cache["num"]

static func ui_font(weight: int = 700) -> Font:
	var key := "ui%d" % weight
	if not _cache.has(key):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Rajdhani", "Oswald", "Barlow Condensed", "Arial Narrow", "Ubuntu Sans", "Ubuntu", "Liberation Sans Narrow", "DejaVu Sans Condensed", "DejaVu Sans"])
		f.font_weight = weight
		_cache[key] = f
	return _cache[key]
