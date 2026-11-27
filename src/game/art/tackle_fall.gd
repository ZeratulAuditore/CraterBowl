extends RefCounted
## Tackled carrier goes down hugging the ball: a physics ragdoll for the legs, spine and head
## (PhysicalBoneSimulator3D), caught by the turf. The arms stay out of the physics and keep the
## athlete_pose "secure" hug, so the ball stays tucked whatever the body does. View-only (no sim
## state): every client runs its own, and replays may differ slightly.
##
## Impact: the carrier freezes for HIT_STOP on contact, then the whole body keeps its run and one
## impulse lands at the hit point, shared by the bones nearest it (each pushed at that point, so
## an off-centre hit also turns them). A low hit from the front stops the legs and he falls
## forward over it; a high one knocks the chest back; one on the hip spins him. The fall comes
## only from where and how hard he was hit, never a random push.

## Simulated bones: [bone, child (capsule end), radius, mass, bend limits (deg, lower, upper),
## side bend +- (deg), twist +- (deg)].
## Bend is about the athlete's left (+X) axis, in the rest pose: + bends the spine and head
## forward, swings a leg back, bends the knee and points the toes. Knees and ankles are hinges
## (no side bend or twist), so no joint can bend a way a body can't.
const BONES := [
	["pelvis", "spine_01", 0.13, 12.0, 0.0, 0.0, 0.0, 0.0],
	["spine_01", "spine_02", 0.12, 8.0, -10.0, 25.0, 10.0, 8.0],
	["spine_02", "spine_03", 0.13, 8.0, -10.0, 25.0, 10.0, 8.0],
	["spine_03", "neck_01", 0.15, 10.0, -10.0, 25.0, 10.0, 8.0],
	["Head", "", 0.12, 5.0, -35.0, 45.0, 25.0, 50.0],
	["thigh_l", "calf_l", 0.08, 8.0, -100.0, 20.0, 30.0, 15.0],
	["calf_l", "foot_l", 0.06, 6.0, 0.0, 115.0, 0.0, 0.0],
	["foot_l", "ball_l", 0.05, 3.0, -25.0, 40.0, 0.0, 0.0],
	["thigh_r", "calf_r", 0.08, 8.0, -100.0, 20.0, 30.0, 15.0],
	["calf_r", "foot_r", 0.06, 6.0, 0.0, 115.0, 0.0, 0.0],
	["foot_r", "ball_r", 0.05, 3.0, -25.0, 40.0, 0.0, 0.0],
]
const LAYER_BONES := 1 << 9
const LAYER_TURF := 1 << 10
const RAGDOLL_LINEAR_DAMP := 0.4
const RAGDOLL_ANGULAR_DAMP := 4.0   # high: limbs settle instead of flailing
## Speed caps (yd/s, rad/s): a bone faster than this is the solver fighting a joint limit,
## not the hit. Capping every physics tick keeps a bad contact from launching the body.
const MAX_SPEED := 12.0
const MAX_SPIN := 14.0
## Contact freeze (s): the carrier holds the frame of impact before the hit lands.
const HIT_STOP := 0.07
## How far (yd) the hit spreads through the body: a bone this far from the hit point takes
## e^-1 of the share the nearest bone takes.
const HIT_SPREAD := 0.35

var view          # player.gd
var active := false
var t := 0.0
var _sim: PhysicalBoneSimulator3D
var _turf: StaticBody3D
var _run := Vector3.ZERO
var _impulse := Vector3.ZERO
var _point := Vector3.ZERO
var _pending := false   # in the hit-stop: the ragdoll starts when it ends

func _init(v) -> void:
	view = v

## run: the carrier's velocity before the hit (yd/s); impulse: the hit (mass x yd/s, world);
## point: where it lands on him (world).
func start(run: Vector3, impulse: Vector3, point: Vector3) -> void:
	stop()
	active = true
	t = 0.0
	_run = run
	_impulse = impulse
	_point = point
	_pending = true
	view.pose.secure = true
	if view.anim:
		view.anim.speed_scale = 0.0   # hit-stop: hold the contact frame

func stop() -> void:
	if not active:
		return
	active = false
	_pending = false
	if view.get_tree().physics_frame.is_connected(_cap_speeds):
		view.get_tree().physics_frame.disconnect(_cap_speeds)
	if _sim:
		_sim.physical_bones_stop_simulation()
		_sim.queue_free()
		_sim = null
	if _turf:
		_turf.queue_free()
		_turf = null
	view.pose.secure = false
	if view.anim:
		view.anim.speed_scale = 1.0

## True during the contact freeze (player.gd keeps the clip where it is).
func holding() -> bool:
	return active and _pending

func update(delta: float) -> void:
	if not active:
		return
	t += delta
	if _pending and t >= HIT_STOP:
		_pending = false
		if view.anim:
			view.anim.speed_scale = 1.0
		_start_ragdoll()

func _start_ragdoll() -> void:
	var sk: Skeleton3D = view._skel
	_sim = PhysicalBoneSimulator3D.new()
	sk.add_child(_sim)
	var names := []
	for b in BONES:
		if sk.find_bone(b[0]) < 0:
			continue
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + b[0]
		pb.bone_name = b[0]
		# Capsule from the bone to its child (or a head-sized one), as the editor's
		# "Create Physical Skeleton" lays it out.
		var child := sk.find_bone(b[1]) if b[1] != "" else -1
		var tip: Vector3 = sk.get_bone_rest(child).origin if child >= 0 else Vector3(0, 0.22, 0.02)
		var half := tip.length() * 0.5
		var up := Vector3.UP if not Vector3.UP.cross(tip).is_zero_approx() else Vector3.BACK
		var body_xf := Transform3D(Basis.looking_at(tip, up), Vector3.ZERO)
		body_xf.origin = body_xf.basis * Vector3(0, 0, -half)
		pb.body_offset = body_xf
		pb.joint_offset = Transform3D(Basis(), Vector3(0, 0, half))
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = b[2]
		cap.height = half * 2.0 + b[2] * 2.0
		cs.shape = cap
		cs.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # capsule Y along the body's Z
		pb.add_child(cs)
		pb.mass = b[3]
		pb.friction = 0.9
		pb.bounce = 0.0
		pb.linear_damp = RAGDOLL_LINEAR_DAMP
		pb.angular_damp = RAGDOLL_ANGULAR_DAMP
		pb.collision_layer = LAYER_BONES
		pb.collision_mask = LAYER_TURF
		if b[0] != "pelvis":
			# 6DOF joint in an anatomical frame: X = the athlete's left, Y = along the bone, Z = X x Y.
			# Joints are built in the rest pose (PhysicalBone3D resets to rest on entering the
			# tree), so limits are measured from standing straight, not from the hit frame.
			var id := sk.find_bone(b[0])
			var rest := sk.get_bone_global_rest(id)
			var y: Vector3 = ((sk.get_bone_global_rest(child).origin - rest.origin) if child >= 0 else Vector3.UP).normalized()
			var x := (Vector3.RIGHT - y * y.dot(Vector3.RIGHT)).normalized()
			var anat := Basis(x, y, x.cross(y))
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
			pb.joint_offset = Transform3D((rest.basis * body_xf.basis).inverse() * anat, pb.joint_offset.origin)
			# Godot measures the bend the other way round from the table: negate it.
			for a in [["x", -b[5], -b[4]], ["y", -b[7], b[7]], ["z", -b[6], b[6]]]:
				pb.set("joint_constraints/%s/angular_limit_enabled" % a[0], true)
				pb.set("joint_constraints/%s/angular_limit_lower" % a[0], a[1])
				pb.set("joint_constraints/%s/angular_limit_upper" % a[0], a[2])
		_sim.add_child(pb)
		names.append(StringName(b[0]))
	_turf = StaticBody3D.new()
	_turf.top_level = true
	_turf.collision_layer = LAYER_TURF
	_turf.collision_mask = 0
	var ts := CollisionShape3D.new()
	ts.shape = WorldBoundaryShape3D.new()
	_turf.add_child(ts)
	view.add_child(_turf)
	_turf.global_transform = Transform3D()
	_sim.physical_bones_start_simulation(names)
	view.get_tree().physics_frame.connect(_cap_speeds)
	# Everyone keeps running; the hit lands where it was made, on the bones nearest it. Bone
	# segments come from the contact-frame pose (the hit-stop held it).
	var parts := []
	var total := 0.0
	for b in BONES:
		var pb := _sim.get_node_or_null("PB_" + b[0]) as PhysicalBone3D
		if pb == null:
			continue
		pb.linear_velocity = _run
		var pose := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b[0]))
		var child := sk.find_bone(b[1]) if b[1] != "" else -1
		var tip: Vector3 = (sk.global_transform * sk.get_bone_global_pose(child)).origin if child >= 0 else pose * Vector3(0, 0.22, 0.02)
		var d := _point.distance_to(Geometry3D.get_closest_point_to_segment(_point, pose.origin, tip))
		var w := exp(-pow(d / HIT_SPREAD, 2.0))
		parts.append([pb, w, (pose.origin + tip) * 0.5])
		total += w
	for p in parts:
		p[0].apply_impulse(_impulse * p[1] / total, _point - p[2])

func _cap_speeds() -> void:
	if _sim == null:
		return
	for pb in _sim.get_children():
		var b := pb as PhysicalBone3D
		if b.linear_velocity.length() > MAX_SPEED:
			b.linear_velocity = b.linear_velocity.limit_length(MAX_SPEED)
		if b.angular_velocity.length() > MAX_SPIN:
			b.angular_velocity = b.angular_velocity.limit_length(MAX_SPIN)
