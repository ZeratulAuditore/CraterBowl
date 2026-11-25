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

## Brushed metal with the CC0 ambientCG Metal009 maps, tinted.
static func brushed(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = load("res://assets/textures/metal/Metal009_1K-JPG_Color.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/metal/Metal009_1K-JPG_NormalGL.jpg")
	m.roughness_texture = load("res://assets/textures/metal/Metal009_1K-JPG_Roughness.jpg")
	m.metallic = 0.85
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
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
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Oswald.ttf")
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		_cache["num"] = fv
	return _cache["num"]

static func ui_font(weight: int = 700) -> Font:
	var key := "ui%d" % weight
	if not _cache.has(key):
		if weight >= 700:
			_cache[key] = load("res://assets/fonts/Rajdhani-Bold.ttf")
		else:
			var fv := FontVariation.new()
			fv.base_font = load("res://assets/fonts/Oswald.ttf")
			fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
			_cache[key] = fv
	return _cache[key]
