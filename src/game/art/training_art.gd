extends RefCounted
## Training-ground visuals (view only): portals, throwing targets, dash lane,
## pocket marker. Reads geometry from drills.gd so sim and art agree.

const Drills := preload("res://src/sim/drills.gd")
const Mats := preload("res://src/game/art/materials.gd")
const STATION_COLORS := {"blocking": Color(1.0, 0.55, 0.2), "field": Color(0.45, 1.0, 0.55),
	"catching": Color(0.36, 0.88, 1.0), "hub": Color(0.8, 0.6, 1.0)}
const STATION_SUBS := {"blocking": "PROTECT THE QB", "field": "TARGETS · 40 YD DASH", "catching": "RACE TO 15 CATCHES",
	"hub": "BACK TO THE HUB"}
const TARGET_COLORS := [Color(0.45, 1.0, 0.55), Color(1.0, 0.86, 0.35), Color(1.0, 0.45, 0.3)]

static func to3(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, h, -p.y)

static func build(root: Node3D, drill, field) -> void:
	var art := Node3D.new()
	art.name = "TrainingArt"
	root.add_child(art)
	var cx: float = field.width / 2.0
	match drill.kind:
		"hub":
			var ps: Array = Drills.portal_positions(field)
			for i in ps.size():
				var k: String = Drills.STATIONS[i]
				portal(art, ps[i], Drills.TITLES[k], STATION_SUBS[k], STATION_COLORS[k])
		"field":
			for i in Drills.target_list(field).size():
				var t: Dictionary = Drills.target_list(field)[i]
				var c: Color = TARGET_COLORS[i % TARGET_COLORS.size()]
				_ground_ring(art, t["pos"], t["r"] * 2.0, c, 0.0, 0.8)
				_ground_ring(art, t["pos"], Drills.BULLSEYE * 2.0, Color(1, 1, 1), 0.0, 0.0)
				_sign(art, to3(t["pos"], 2.6), "%d" % t["pts"], 160, 0.02, c)
			var lane: Dictionary = Drills.dash_lane(field)
			var w: float = lane["half_w"] * 2.0
			_line(art, Vector2(lane["x"], lane["start"]), w, Color(0.45, 1.0, 0.55))
			_line(art, Vector2(lane["x"], lane["finish"]), w, Color(1.0, 0.86, 0.35))
			for sx in [-1.0, 1.0]:
				_stripe(art, Vector2(lane["x"] + sx * lane["half_w"], (lane["start"] + lane["finish"]) / 2.0), lane["finish"] - lane["start"], Color(1, 1, 1, 0.35))
			_sign(art, to3(Vector2(lane["x"], lane["start"]), 2.2), "START", 110, 0.02, Color(0.45, 1.0, 0.55))
			_sign(art, to3(Vector2(lane["x"], lane["finish"]), 2.2), "40 YD", 110, 0.02, Color(1.0, 0.86, 0.35))
		"blocking":
			var pc: Color = STATION_COLORS["blocking"]
			_ground_ring(art, Vector2(cx, Drills.LOS - 5.0), 4.0, Color(pc.r, pc.g, pc.b, 0.5), 14.0, 0.0)
			_sign(art, to3(Vector2(cx, Drills.LOS - 8.5), 0.4), "POCKET", 90, 0.02, STATION_COLORS["blocking"])
	if Drills.STATIONS.has(drill.kind):
		portal(art, Drills.EXIT_PORTAL, "TRAINING GROUND", STATION_SUBS["hub"], STATION_COLORS["hub"], Drills.EXIT_R / Drills.PORTAL_R)

## Standing glow ring + ground pad + floating name.
static func portal(root: Node3D, at: Vector2, name: String, sub: String, c: Color, scale: float = 1.0) -> Node3D:
	var p := Node3D.new()
	p.name = "Portal_" + name.replace(" ", "_")
	p.position = to3(at)
	p.scale = Vector3.ONE * scale
	root.add_child(p)
	var r := Drills.PORTAL_R
	var torus := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.22
	tm.outer_radius = r
	tm.rings = 48
	tm.ring_segments = 10
	torus.mesh = tm
	torus.rotation = Vector3(PI / 2.0, 0, 0)   # stand it up, facing the camera
	torus.position = Vector3(0, r + 0.15, 0)
	torus.material_override = Mats.emissive(c, 3.5)
	torus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(torus)
	var veil := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(r * 2.4, r * 2.4)
	veil.mesh = q
	veil.position = Vector3(0, r + 0.15, 0)
	var vm := Mats.shader("res://src/game/art/ring.gdshader")
	vm.set_shader_parameter("color", Color(c.r, c.g, c.b, 0.85))
	vm.set_shader_parameter("dashes", 0.0)
	vm.set_shader_parameter("pulse", 1.0)
	veil.material_override = vm
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(veil)
	_ground_ring(p, Vector2.ZERO, r * 2.6, c, 8.0, 1.0, true)
	_sign(p, Vector3(0, r * 2.0 + 1.3, 0), name, 120, 0.016, c)
	_sign(p, Vector3(0, r * 2.0 + 0.55, 0), sub, 64, 0.016, Color(1, 1, 1, 0.85))
	return p

static func _ground_ring(root: Node3D, at: Vector2, size: float, c: Color, dashes: float, pulse: float, local: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := Mats.shader("res://src/game/art/ring.gdshader")
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("dashes", dashes)
	m.set_shader_parameter("pulse", pulse)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.05, 0) if local else to3(at, 0.05)
	root.add_child(mi)

static func _line(root: Node3D, at: Vector2, w: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, 0.5)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := Mats.shader("res://src/game/art/line_marker.gdshader")
	m.set_shader_parameter("color", c)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = to3(at, 0.04)
	root.add_child(mi)

static func _stripe(root: Node3D, at: Vector2, length: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, length)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = Mats.flat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = to3(at, 0.035)
	root.add_child(mi)

static func _sign(root: Node3D, at: Vector3, text: String, size: int, px: float, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Mats.ui_font(700)
	l.font_size = size
	l.pixel_size = px
	l.outline_size = maxi(4, size / 10)
	l.outline_modulate = Color(0.02, 0.03, 0.08, 0.85)
	l.modulate = c
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = at
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(l)
	return l
