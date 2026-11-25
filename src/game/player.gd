extends Node3D
## View of one sim athlete: an articulated low-poly football player with
## procedural animation (run cycle, stances, carry, throw, dive, block, celebrate).
## Mirrors sim state; owns no rules. Cosmetics are view-only.
##
## Animation is driven by how the node actually moves (works for live sim,
## network interpolation and replays alike), plus a few sim flags when known.

const Cos := preload("res://src/sim/cosmetics.gd")
const Mats := preload("res://src/game/art/materials.gd")

const SKIN_TONES := [Color(0.98, 0.80, 0.66), Color(0.87, 0.65, 0.48), Color(0.72, 0.50, 0.34),
	Color(0.55, 0.36, 0.23), Color(0.40, 0.26, 0.17), Color(0.30, 0.20, 0.13)]
## Role -> [width, height] build. Linemen are wide, skill players lean.
const BUILDS := {"OL": [1.22, 1.02], "DL": [1.2, 1.02], "C": [1.2, 1.0], "LB": [1.08, 1.0],
	"QB": [1.0, 1.02], "RB": [1.02, 0.96], "WR": [0.92, 1.03], "CB": [0.92, 1.0], "S": [0.96, 1.0]}
const ROLE_NAMES := ["QB", "C", "WR", "RB", "LB", "CB", "S", "OL", "DL"]
const LINEMEN := ["OL", "DL", "C"]

var athlete  # sim athlete
var color := Color(0.9, 0.75, 0.2)
var pants_color := Color(0.15, 0.15, 0.2)
var world = null           # optional: sim world (stances, ball carry)
var throw_pose := 0.0      # 0..1, set by main while the controlled QB charges a throw

# Public parts (kept for tests/cosmetics)
var body: Node3D           # hip pivot; whole body tilts from here
var trim_band: MeshInstance3D
var helmet: MeshInstance3D
var stripe: MeshInstance3D
var number_front: Label3D
var number_back: Label3D
var number_text := ""
var trim_color := Color.WHITE
var look := {}
var celebrate_kind := "none"
var celebrate_t := 0.0

# Rig
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hand_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var trim_parts: Array = []
var jersey_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D

# Animation state
var _last_pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _stride := 0.0
var _down := 0.0           # 0 standing .. 1 laid out
var _stance := 0.0
var _carry := 0.0
var _block := 0.0
var _throw := 0.0
var _time := 0.0
var _role := ""
var _hit_t := 0.0

func setup(a, c: Color, w = null) -> void:
	athlete = a
	color = c
	world = w
	# Contrasting pants per team keep silhouettes readable.
	pants_color = Color(0.16, 0.17, 0.22) if a.team == 0 else Color(0.93, 0.93, 0.95)

func _ready() -> void:
	var skin: Color = SKIN_TONES[(athlete.id * 7 + athlete.team * 3) % SKIN_TONES.size()]
	jersey_mat = Mats.cloth(color)
	trim_mat = Mats.cloth(Color.WHITE)
	var pants_mat := Mats.cloth(pants_color)
	var skin_mat := Mats.skin(skin)
	var dark := Mats.cloth(Color(0.07, 0.07, 0.09))
	var sock_mat := Mats.cloth(color.darkened(0.25))

	body = Node3D.new()
	body.name = "Body"
	body.position.y = 1.0
	add_child(body)

	# Pelvis + legs
	_part(body, _capsule(0.2, 0.5), pants_mat, Vector3(0, -0.02, 0), Vector3(0, 0, PI / 2)).scale = Vector3(1, 1.25, 0.95)
	leg_l = _pivot(body, Vector3(-0.15, -0.08, 0))
	leg_r = _pivot(body, Vector3(0.15, -0.08, 0))
	for side in [[leg_l, -1.0], [leg_r, 1.0]]:
		var leg: Node3D = side[0]
		_part(leg, _capsule(0.12, 0.52), pants_mat, Vector3(0, -0.22, 0))
		var knee := _pivot(leg, Vector3(0, -0.44, 0))
		_part(knee, _capsule(0.085, 0.5), sock_mat, Vector3(0, -0.22, 0))
		trim_parts.append(_part(knee, _cyl(0.092, 0.06), trim_mat, Vector3(0, -0.06, 0)))
		var cleat := _part(knee, _box(Vector3(0.15, 0.09, 0.3)), dark, Vector3(0, -0.5, 0.06))
		cleat.name = "Cleat"
		if side[1] < 0.0:
			knee_l = knee
		else:
			knee_r = knee

	# Torso (spine pivot at the waist)
	torso = _pivot(body, Vector3(0, 0.08, 0))
	var chest := _part(torso, _tapered(0.27, 0.36, 0.62), jersey_mat, Vector3(0, 0.33, 0))
	chest.scale = Vector3(1, 1, 0.66)
	chest.name = "Jersey"
	trim_band = _part(torso, _tapered(0.285, 0.295, 0.07), trim_mat, Vector3(0, 0.04, 0))
	trim_band.scale = Vector3(1, 1, 0.68)
	trim_band.name = "TrimBand"
	# Shoulder pads: a wide rounded yoke + caps.
	var pads := _part(torso, SphereMesh.new(), jersey_mat, Vector3(0, 0.6, -0.01))
	pads.scale = Vector3(0.84, 0.3, 0.52)
	for sx in [-1.0, 1.0]:
		var cap := _part(torso, SphereMesh.new(), jersey_mat, Vector3(0.36 * sx, 0.6, 0))
		cap.scale = Vector3(0.3, 0.26, 0.34)
		trim_parts.append(_part(torso, _cyl(0.13, 0.05), trim_mat, Vector3(0.43 * sx, 0.5, 0), Vector3(0, 0, PI / 2 * sx)))
	_part(torso, _cyl(0.08, 0.12), skin_mat, Vector3(0, 0.74, 0))   # neck

	# Head + helmet
	head = _pivot(torso, Vector3(0, 0.8, 0))
	_part(head, SphereMesh.new(), skin_mat, Vector3(0, 0.12, 0.02)).scale = Vector3(0.3, 0.33, 0.3)
	helmet = _part(head, SphereMesh.new(), Mats.glossy(color.darkened(0.2)), Vector3(0, 0.17, -0.02))
	helmet.scale = Vector3(0.36, 0.36, 0.4)
	helmet.name = "Helmet"
	stripe = MeshInstance3D.new()
	stripe.mesh = _box(Vector3(0.2, 0.06, 1.0))
	stripe.position = Vector3(0, 0.49, -0.04)
	helmet.add_child(stripe)
	var mask_mat := Mats.metal(Color(0.85, 0.86, 0.9))
	for i in 3:   # facemask bars
		var y := 0.09 - i * 0.075
		var bar := _part(head, _cyl(0.014, 0.3), mask_mat, Vector3(0, y, 0.22), Vector3(0, 0, PI / 2))
		bar.name = "Facemask%d" % i
	for sx in [-1.0, 1.0]:
		_part(head, _cyl(0.014, 0.2), mask_mat, Vector3(0.13 * sx, 0.04, 0.17), Vector3(PI / 2, 0, 0))
	_part(head, _cyl(0.014, 0.17), mask_mat, Vector3(0, 0.03, 0.235))
	var visor := _part(head, SphereMesh.new(), Mats.visor(), Vector3(0, 0.15, 0.14))
	visor.scale = Vector3(0.29, 0.1, 0.18)

	# Arms (shoulder pivots)
	arm_l = _pivot(torso, Vector3(-0.38, 0.55, 0))
	arm_r = _pivot(torso, Vector3(0.38, 0.55, 0))
	for side in [[arm_l, -1.0], [arm_r, 1.0]]:
		var arm: Node3D = side[0]
		_part(arm, _capsule(0.1, 0.3), jersey_mat, Vector3(0, -0.1, 0))    # sleeve
		_part(arm, _capsule(0.08, 0.34), skin_mat, Vector3(0, -0.2, 0))
		var elbow := _pivot(arm, Vector3(0, -0.36, 0))
		_part(elbow, _capsule(0.07, 0.34), skin_mat, Vector3(0, -0.15, 0))
		var hand := _pivot(elbow, Vector3(0, -0.34, 0))
		_part(hand, SphereMesh.new(), dark, Vector3.ZERO).scale = Vector3(0.11, 0.12, 0.11)
		if side[1] < 0.0:
			elbow_l = elbow
		else:
			elbow_r = elbow
			hand_r = hand

	number_front = _number_label(0.2)
	number_back = _number_label(-0.2)
	add_child(_blob_shadow())
	apply_look(Cos.DEFAULT_LOOK.merged({"number": (athlete.id % 90) + 10}, true))
	_last_pos = Vector3(athlete.position.x, 0, -athlete.position.y)
	sync()

# --- mesh helpers -----------------------------------------------------------

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n

func _part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 10
	m.rings = 4
	return m

static func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	return m

static func _tapered(bottom: float, top: float, h: float) -> CylinderMesh:
	var m := _cyl(bottom, h)
	m.top_radius = top
	m.radial_segments = 12
	return m

static func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m

func _blob_shadow() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = Mats.blob_shadow()
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _number_label(z: float) -> Label3D:
	var l := Label3D.new()
	l.font_size = 72
	l.outline_size = 14
	l.pixel_size = 0.0042
	l.font = Mats.number_font()
	l.position = Vector3(0, 0.36, z)
	l.double_sided = false
	if z < 0.0:
		l.rotation.y = PI
	torso.add_child(l)
	return l

## Apply a (sanitized) look. Purely visual.
func apply_look(lk: Dictionary) -> void:
	look = Cos.sanitize_look(lk)
	trim_color = Cos.color_of("trim", look["trim"])
	trim_mat.albedo_color = trim_color
	trim_band.material_override = trim_mat
	var hc: Color = Cos.color_of("helmet", look["helmet"])
	stripe.material_override = Mats.metal(hc) if look["helmet"] == "chrome" else Mats.glossy(hc)
	number_text = str(int(look["number"]))
	for l in [number_front, number_back]:
		l.text = number_text
		l.modulate = trim_color
		l.outline_modulate = color.darkened(0.55) if trim_color.get_luminance() > 0.5 else Color(0.95, 0.95, 0.95)

func celebrate(kind: String) -> void:
	if kind != "none":
		celebrate_kind = kind
		celebrate_t = 1.5

func is_celebrating() -> bool:
	return celebrate_t > 0.0

## Kick off a short hit reaction (tackle impact).
func hit() -> void:
	_hit_t = 0.35

## Where the ball sits when this athlete carries it (world space).
func hand_position() -> Vector3:
	return hand_r.global_position if hand_r and hand_r.is_inside_tree() else global_position + Vector3(0, 1.1, 0)

func _role_name() -> String:
	var r := int(athlete.role)
	return ROLE_NAMES[r] if r >= 0 and r < ROLE_NAMES.size() else "WR"

## Mirror the sim position/facing. Animation runs in _process.
func sync() -> void:
	position = Vector3(athlete.position.x, 0, -athlete.position.y)
	if athlete.speed() > 0.1:
		rotation.y = atan2(-athlete.velocity.x, athlete.velocity.y)
	elif athlete.facing.length() > 0.1 and _stance > 0.5:
		rotation.y = atan2(-athlete.facing.x, athlete.facing.y)
	var rn := _role_name()
	if rn != _role:
		_role = rn
		var b: Array = BUILDS.get(rn, [1.0, 1.0])
		scale = Vector3(b[0], b[1], (b[0] + 1.0) * 0.5)
	if celebrate_t > 0.0:
		celebrate_t = maxf(0.0, celebrate_t - 1.0 / 60.0)

func _process(delta: float) -> void:
	if delta <= 0.0 or body == null:
		return
	_time += delta
	# Velocity from the node's real motion (sim, interpolation or replay).
	var v := (position - _last_pos) / delta
	_last_pos = position
	if v.length() > 30.0:   # teleport (new play / replay seek)
		v = Vector3.ZERO
	_vel = _vel.lerp(v, clampf(delta * 12.0, 0.0, 1.0))
	var spd := Vector2(_vel.x, _vel.z).length()
	if spd > 0.4 and not (athlete.is_diving() or athlete.is_grounded()):
		rotation.y = lerp_angle(rotation.y, atan2(-_vel.x, -_vel.z), clampf(delta * 14.0, 0.0, 1.0))
	_animate(delta, spd)

func _animate(delta: float, spd: float) -> void:
	var k := clampf(delta * 10.0, 0.0, 1.0)
	var down_target := 1.0 if (athlete.is_diving() or athlete.is_grounded()) else 0.0
	_down = move_toward(_down, down_target, delta * (7.0 if down_target > _down else 2.5))
	var presnap: bool = world != null and int(world.phase) == 0
	var stance_target := 1.0 if (presnap and _role in LINEMEN and spd < 0.5) else (0.55 if presnap and spd < 0.5 and _role in ["LB", "CB", "S", "WR", "RB"] else 0.0)
	_stance = lerpf(_stance, stance_target, k)
	var carrying: bool = world != null and int(world.ball.state) == 0 and world.ball.holder_id == athlete.id
	_carry = lerpf(_carry, 1.0 if carrying and throw_pose <= 0.0 else 0.0, k)
	_block = lerpf(_block, 1.0 if athlete.engaged_with >= 0 else 0.0, k)
	_throw = lerpf(_throw, throw_pose, clampf(delta * 18.0, 0.0, 1.0))
	_hit_t = maxf(0.0, _hit_t - delta)

	# Run cycle: stride advances with distance covered.
	var run := clampf(spd / 7.0, 0.0, 1.0)
	_stride += spd * delta * 1.35
	var s := sin(_stride)
	var c := cos(_stride)
	var swing := 0.95 * run
	var breathe := sin(_time * 2.2) * 0.02

	# Legs
	leg_l.rotation.x = s * swing - _stance * 0.9
	leg_r.rotation.x = -s * swing - _stance * 0.55
	knee_l.rotation.x = (maxf(0.0, -c) * 1.4 * run) + _stance * 1.3
	knee_r.rotation.x = (maxf(0.0, c) * 1.4 * run) + _stance * 1.0
	leg_l.rotation.z = -_stance * 0.18 - _block * 0.12
	leg_r.rotation.z = _stance * 0.18 + _block * 0.12

	# Torso lean (sprint, stance, block), slight twist with the stride.
	torso.rotation.x = -(run * 0.32 + _stance * 0.85 + _block * 0.45) + breathe
	torso.rotation.y = s * 0.18 * run - _throw * 0.6
	head.rotation.x = run * 0.2 + _stance * 0.6 + _block * 0.3

	# Arms: pump opposite the legs, then overlay carry / block / throw / stance poses.
	var pump := 0.9 * run
	var al := Vector3(-s * pump, 0, -0.18)
	var ar := Vector3(s * pump, 0, 0.18)
	var el := -0.4 - run * 0.9
	var er := -0.4 - run * 0.9
	if _stance > 0.01:   # down hand in the dirt for linemen, hands on knees otherwise
		ar = ar.lerp(Vector3(0.9 if _role in LINEMEN else 0.5, 0, 0.05), _stance)
		al = al.lerp(Vector3(0.5, 0, -0.35), _stance)
		el = lerpf(el, -0.3, _stance)
		er = lerpf(er, -0.1, _stance)
	if _block > 0.01:    # hands punched forward
		al = al.lerp(Vector3(-1.35, 0, -0.15), _block)
		ar = ar.lerp(Vector3(-1.35, 0, 0.15), _block)
		el = lerpf(el, -0.25, _block)
		er = lerpf(er, -0.25, _block)
	if _carry > 0.01:    # ball tucked high and tight
		ar = ar.lerp(Vector3(-0.35, 0.3, 0.35), _carry)
		er = lerpf(er, -1.9, _carry)
	if _throw > 0.01:    # cocked behind the ear
		ar = ar.lerp(Vector3(-2.6 + 0.4 * _throw, 0, 0.9), _throw)
		er = lerpf(er, -1.6, _throw)
		al = al.lerp(Vector3(-1.2, 0, -0.3), _throw)
	if _down > 0.01:     # superman dive: arms out ahead
		al = al.lerp(Vector3(-2.9, 0, -0.2), _down)
		ar = ar.lerp(Vector3(-2.9, 0, 0.2), _down)
		el = lerpf(el, -0.1, _down)
		er = lerpf(er, -0.1, _down)
	arm_l.rotation = al
	arm_r.rotation = ar
	elbow_l.rotation.x = el
	elbow_r.rotation.x = er

	# Whole-body pose from the hips.
	var bob := absf(sin(_stride)) * 0.07 * run
	var hip_y := 1.0 + bob - _stance * 0.36 - _block * 0.1 + breathe * 0.5
	body.rotation = Vector3(lerpf(0.0, -PI / 2.0 + 0.12, _down), 0, 0)
	body.position = Vector3(0, lerpf(hip_y, 0.32, _down), lerpf(0.0, 0.25, _down))
	if _hit_t > 0.0:
		body.rotation.z = sin(_hit_t * 40.0) * _hit_t * 0.5

	if celebrate_t > 0.0:
		var t := 1.5 - celebrate_t
		arm_l.rotation = Vector3(-2.9, 0, -0.35)
		arm_r.rotation = Vector3(-2.9, 0, 0.35)
		elbow_l.rotation.x = -0.2
		elbow_r.rotation.x = -0.2
		match celebrate_kind:
			"spin": body.rotation.y = t * TAU * 2.0
			"hop": body.position.y = 1.0 + absf(sin(t * 6.0)) * 0.9
			"flip":
				body.rotation.x = t * TAU / 1.5
				body.position.y = 1.0 + sin(t / 1.5 * PI) * 1.2
