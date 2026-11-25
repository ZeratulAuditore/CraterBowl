extends RefCounted
## Builds the playing surface: turf shader, yard numbers, end-zone names,
## midfield emblem, pylons, goalposts. Purely visual; sizes come from sim Field.

const Mats := preload("res://src/game/art/materials.gd")
const TEAM_NAMES := ["HELIOS", "NEBULA"]
const APRON := 14.0

static func build(root: Node3D, field, team_colors: Array) -> void:
	var w: float = field.width
	var L: float = field.length
	var ez: float = field.endzone_depth
	var turf := MeshInstance3D.new()
	turf.name = "Turf"
	var pm := PlaneMesh.new()
	pm.size = Vector2(w + APRON * 2.0, L + ez * 2.0 + APRON * 2.0)
	turf.mesh = pm
	turf.position = Vector3(w / 2.0, 0.0, -L / 2.0)
	var tm := Mats.shader("res://src/game/art/turf.gdshader")
	tm.set_shader_parameter("field_w", w)
	tm.set_shader_parameter("field_len", L)
	tm.set_shader_parameter("ez", ez)
	tm.set_shader_parameter("hash_inset", w * 0.438)
	tm.set_shader_parameter("home_color", team_colors[0])
	tm.set_shader_parameter("away_color", team_colors[1])
	turf.material_override = tm
	root.add_child(turf)
	_yard_numbers(root, w, L)
	_end_zone_names(root, w, L, ez, team_colors)
	_midfield_emblem(root, w, L)
	for y in [0.0, L, -ez, L + ez]:
		for x in [0.0, w]:
			_pylon(root, Vector3(x, 0, -y))
	_goalpost(root, w, -ez, 1.0)
	_goalpost(root, w, L + ez, -1.0)

static func _flat_label(root: Node3D, text: String, at: Vector3, yaw: float, size: int, px: float, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Mats.number_font()
	l.font_size = size
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = c
	l.shaded = true
	l.double_sided = false
	l.position = at
	l.rotation = Vector3(-PI / 2.0, yaw, 0)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(l)
	return l

## Numbers every 10 yards, distance to the nearest goal, readable from each sideline.
static func _yard_numbers(root: Node3D, w: float, L: float) -> void:
	var inset := clampf(w * 0.17, 5.0, 9.0)
	var px := 0.0115 * clampf(w / 53.33, 0.7, 1.0)
	for yd in range(10, int(L), 10):
		var num := mini(yd, int(L) - yd)
		var y := float(yd)
		var t := str(num)
		_flat_label(root, t, Vector3(inset, 0.012, -y), -PI / 2.0, 220, px, Color(0.96, 0.96, 0.94, 0.95)).name = "YardNum%dL" % yd
		_flat_label(root, t, Vector3(w - inset, 0.012, -y), PI / 2.0, 220, px, Color(0.96, 0.96, 0.94, 0.95)).name = "YardNum%dR" % yd

static func _end_zone_names(root: Node3D, w: float, L: float, ez: float, team_colors: Array) -> void:
	var px := 0.03 * clampf(w / 53.33, 0.55, 1.0) * clampf(ez / 10.0, 0.8, 1.0)
	for i in 2:
		var y := -ez * 0.5 if i == 0 else L + ez * 0.5
		var l := _flat_label(root, TEAM_NAMES[i], Vector3(w / 2.0, 0.014, -y), 0.0 if i == 1 else PI, 200, px, Color(0.97, 0.97, 0.97, 0.92))
		l.outline_size = 36
		l.outline_modulate = (team_colors[i] as Color).darkened(0.5)
		l.name = "EndZoneName%d" % i

static func _midfield_emblem(root: Node3D, w: float, L: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "MidfieldEmblem"
	var q := QuadMesh.new()
	var s := clampf(w * 0.26, 8.0, 14.0)
	q.size = Vector2(s, s)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = Mats.shader("res://src/game/art/emblem.gdshader")
	mi.position = Vector3(w / 2.0, 0.011, -L / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

static func _pylon(root: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.18, 0.5, 0.18)
	mi.mesh = b
	mi.material_override = Mats.emissive(Color(1.0, 0.42, 0.08), 0.6)
	mi.position = at + Vector3(0, 0.25, 0)
	mi.name = "Pylon"
	root.add_child(mi)

## Slingshot goalpost on an end line; `dir` points back toward the field.
static func _goalpost(root: Node3D, w: float, y: float, dir: float) -> void:
	var gp := Node3D.new()
	gp.name = "Goalpost"
	gp.position = Vector3(w / 2.0, 0, -(y - dir * 1.5))
	root.add_child(gp)
	var mat := Mats.glossy(Color(1.0, 0.86, 0.2))
	var span := clampf(w * 0.116, 4.5, 6.2)
	var up_h := 9.0
	var bar_h := 3.3
	_rod(gp, Vector3(0, bar_h * 0.5, 0), 0.2, bar_h, Vector3.ZERO, mat)          # gooseneck base
	_rod(gp, Vector3(0, bar_h, dir * 0.8), 0.14, 1.6, Vector3(PI / 2, 0, 0), mat) # neck to crossbar
	_rod(gp, Vector3(0, bar_h, dir * 1.6), 0.1, span, Vector3(0, 0, PI / 2), mat)
	for sx in [-0.5, 0.5]:
		_rod(gp, Vector3(span * sx, bar_h + up_h * 0.5, dir * 1.6), 0.08, up_h, Vector3.ZERO, mat)
		var flag := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.05, 0.9, 0.25)
		flag.mesh = fb
		flag.material_override = Mats.emissive(Color(1.0, 0.42, 0.08), 0.8)
		flag.position = Vector3(span * sx, bar_h + up_h - 0.2, dir * 1.6)
		gp.add_child(flag)
	var pad := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.34
	pc.bottom_radius = 0.34
	pc.height = 2.0
	pad.mesh = pc
	pad.material_override = Mats.cloth(Color(0.1, 0.12, 0.2))
	pad.position = Vector3(0, 1.0, 0)
	gp.add_child(pad)

static func _rod(parent: Node3D, at: Vector3, r: float, h: float, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
