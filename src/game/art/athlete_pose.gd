extends SkeletonModifier3D
## Procedural arm pose layered on top of the playing clip (#244). Godot 4.3 runs
## _process_modification() after the AnimationPlayer has posed the skeleton.
## Ball carry: two-bone IK pulls the right hand to the chest, elbow tucked at the side.
## A passer holding before the throw holds the ball in front of the chest, one hand on
## each side of it (palms in), and the ball sits there instead of in the right palm.
## Head look (#245): neck and head turn toward `look_target`, clamped to human limits.
## Catch (#246): both hands up in a ready stance, reaching to the ball as it closes in.
## View-only (no sim state). weight 0 leaves the clip pose untouched; player.gd smooths it.

## Hand targets and elbow hints in spine_03 space (rig: +Z forward, +Y up, right = -X).
const TUCK_HAND := Vector3(-0.17, 0.06, 0.13)
const TUCK_POLE := Vector3(-0.6, -1.0, -0.6)
## Two-hand hold: ball center, and each wrist beside it (ball radius 0.15 + palm, fingers forward).
const HOLD_BALL := Vector3(0.0, 0.02, 0.28)
const HOLD_WRIST_R := HOLD_BALL + Vector3(-0.17, 0.0, -0.08)
const HOLD_WRIST_L := HOLD_BALL + Vector3(0.17, 0.0, -0.08)
const HOLD_POLE_R := Vector3(-1.0, -1.0, -0.3)
const HOLD_POLE_L := Vector3(1.0, -1.0, -0.3)
## Hand orientation for the hold, in spine_03 space: fingers forward (bone +Y = +Z) and
## palms in (palm is -X of hand_r and +X of hand_l, so both map bone +X to spine -X).
const HOLD_HAND_BASIS := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))

## Catch stance (#246), spine_03 space: wrists up in front of the chest, palms forward.
const CATCH_HAND_R := Vector3(-0.14, 0.12, 0.34)
const CATCH_HAND_L := Vector3(0.14, 0.12, 0.34)
const CATCH_POLE_R := Vector3(-1.0, -0.6, -0.2)
const CATCH_POLE_L := Vector3(1.0, -0.6, -0.2)
## Palms forward, fingers up (palm = -X of hand_r, +X of hand_l).
const PALMS_FWD_R := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
const PALMS_FWD_L := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
## Reaching: each wrist sits this far behind the ball and to its side (ball radius + palm).
const REACH_BACK := 0.13
const REACH_SIDE := 0.11

## Hands on the ball open from the clip's fist toward the rig's flat rest pose by this
## much, leaving a slight curl so the fingers wrap the ball.
const HAND_OPEN := 0.7
const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]

## Head look limits (rad), in the chest's frame. Past YAW_MAX the look fades back to
## neutral over YAW_FADE, so a target behind you never twists the neck.
const YAW_MAX := deg_to_rad(80.0)
const YAW_FADE := deg_to_rad(40.0)
const PITCH_UP := deg_to_rad(40.0)
const PITCH_DOWN := deg_to_rad(30.0)
const NECK_SHARE := 0.4   # the rest of the turn is the head's

var weight := 0.0      # 0 = clip pose, 1 = full carry pose
var two_hand := false  # passer holding before the throw
var look_target := Vector3.ZERO   # skeleton space
var look_weight := 0.0            # 0 = clip's head, 1 = full look
var catch_weight := 0.0           # 0 = no catch pose, 1 = full stance/reach
var catch_target := Vector3.ZERO  # the ball, skeleton space
var catch_reach := 0.0            # 0 = ready stance, 1 = hands on the ball
var _bones := {}
var _fingers := {}     # "_r"/"_l" -> finger bone ids (joints 01-03)
var _rig_ok := false   # every bone in _bones exists (checked once: no per-frame allocation)

func _process_modification() -> void:
	apply(get_skeleton())

func apply(sk: Skeleton3D) -> void:
	if sk == null or (weight <= 0.0 and look_weight <= 0.0 and catch_weight <= 0.0):
		return
	if _bones.is_empty():
		for n in ["spine_03", "neck_01", "Head", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l"]:
			_bones[n] = sk.find_bone(n)
		for side in ["_r", "_l"]:
			_fingers[side] = []
			for f in FINGERS:
				for j in ["01", "02", "03"]:
					var b := sk.find_bone("%s_%s%s" % [f, j, side])
					if b >= 0:
						_fingers[side].append(b)
		_rig_ok = not _bones.values().has(-1)
	if not _rig_ok:
		return   # rig without these bones: keep the clip
	if look_weight > 0.0:
		_look(sk)
	# The arms do one job: the stronger of catching and carrying (they cross over at the catch).
	if catch_weight > weight:
		_catch(sk)
		return
	if weight <= 0.0:
		return
	var chest := sk.get_bone_global_pose(_bones.spine_03)
	if two_hand:
		var palms_in := chest.basis * HOLD_HAND_BASIS
		_reach(sk, "_r", chest * HOLD_WRIST_R, chest.basis * HOLD_POLE_R, weight, palms_in)
		_reach(sk, "_l", chest * HOLD_WRIST_L, chest.basis * HOLD_POLE_L, weight, palms_in)
		_open_hand(sk, "_l", weight)
	else:
		_reach(sk, "_r", chest * TUCK_HAND, chest.basis * TUCK_POLE, weight)
	_open_hand(sk, "_r", weight)

## Ready stance blended toward hands on the ball by catch_reach, palms toward the ball.
func _catch(sk: Skeleton3D) -> void:
	var chest := sk.get_bone_global_pose(_bones.spine_03)
	var toward := (catch_target - chest.origin).normalized()
	var side := toward.cross(chest.basis.y).normalized()   # the athlete's right
	var turn := Quaternion(chest.basis.z.normalized(), toward)
	var aim := Quaternion.IDENTITY.slerp(turn, catch_reach)
	for s in [["_r", CATCH_HAND_R, CATCH_POLE_R, PALMS_FWD_R, 1.0], ["_l", CATCH_HAND_L, CATCH_POLE_L, PALMS_FWD_L, -1.0]]:
		var ball_side: Vector3 = catch_target - toward * REACH_BACK + side * (REACH_SIDE * s[4])
		var wrist: Vector3 = (chest * s[1]).lerp(ball_side, catch_reach)
		_reach(sk, s[0], wrist, chest.basis * s[2], catch_weight, Basis(aim) * chest.basis * s[3])
		_open_hand(sk, s[0], catch_weight)

## Clamped look angles for a direction in the chest's frame (+Z forward, +X left, +Y up):
## Vector2(yaw, pitch) in radians, yaw + = left, pitch + = up. Beyond YAW_MAX both fade to 0.
static func look_angles(d: Vector3) -> Vector2:
	var yaw := atan2(d.x, d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var fade := clampf(1.0 - (absf(yaw) - YAW_MAX) / YAW_FADE, 0.0, 1.0)
	return Vector2(clampf(yaw, -YAW_MAX, YAW_MAX), clampf(pitch, -PITCH_DOWN, PITCH_UP)) * fade

## Turn neck and head toward look_target: NECK_SHARE of the clamped turn on the neck,
## the rest on the head, about the chest's up and left axes.
func _look(sk: Skeleton3D) -> void:
	var chest := sk.get_bone_global_pose(_bones.spine_03)
	var n: int = _bones.neck_01
	var h: int = _bones.Head
	var gn := sk.get_bone_global_pose(n)
	var gh := sk.get_bone_global_pose(h)
	var a := look_angles(chest.basis.inverse() * (look_target - gh.origin)) * look_weight
	var up := chest.basis.y.normalized()
	var left := chest.basis.x.normalized()
	var rn := Basis(up, a.x * NECK_SHARE) * Basis(left, -a.y * NECK_SHARE)
	var rh := Basis(up, a.x * (1.0 - NECK_SHARE)) * Basis(left, -a.y * (1.0 - NECK_SHARE))
	var neck := rn * gn.basis
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(n)).basis
	sk.set_bone_pose_rotation(n, (parent.inverse() * neck).orthonormalized().get_rotation_quaternion())
	sk.set_bone_pose_rotation(h, (neck.inverse() * rh * rn * gh.basis).orthonormalized().get_rotation_quaternion())

## Uncurl the clip's fist so the fingers spread around the ball.
func _open_hand(sk: Skeleton3D, side: String, w: float) -> void:
	var k := HAND_OPEN * w
	for b in _fingers[side]:
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(sk.get_bone_rest(b).basis.get_rotation_quaternion(), k))

## Two-bone IK (skeleton space): hand to `target`, elbow bent toward `pole`. The hand takes
## `hand_basis` if given, else keeps the clip's wrist angle. Blended into local rotations by w.
func _reach(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3, w: float, hand_basis = null) -> void:
	var u: int = _bones["upperarm" + side]
	var l: int = _bones["lowerarm" + side]
	var h: int = _bones["hand" + side]
	var gu := sk.get_bone_global_pose(u)
	var gl := sk.get_bone_global_pose(l)
	var gh := sk.get_bone_global_pose(h)
	var a := gu.origin.distance_to(gl.origin)
	var b := gl.origin.distance_to(gh.origin)
	var to := target - gu.origin
	var d := clampf(to.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to.normalized()
	var bend := (pole - dir * pole.dot(dir)).normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := gu.origin + dir * (a * cos_a) + bend * (a * sqrt(1.0 - cos_a * cos_a))
	var ru := Basis(Quaternion((gl.origin - gu.origin).normalized(), (elbow - gu.origin).normalized()))
	var nu := Transform3D(ru * gu.basis, gu.origin)
	var rl := Basis(Quaternion((ru * (gh.origin - gl.origin)).normalized(), (gu.origin + dir * d - elbow).normalized()))
	var nl := Transform3D(rl * ru * gl.basis, elbow)
	var nh_basis: Basis = hand_basis if hand_basis != null else nl.basis * (gl.basis.inverse() * gh.basis)
	_blend(sk, u, sk.get_bone_global_pose(sk.get_bone_parent(u)).basis.inverse() * nu.basis, w)
	_blend(sk, l, nu.basis.inverse() * nl.basis, w)
	_blend(sk, h, nl.basis.inverse() * nh_basis, w)

## Where the held ball sits, in skeleton space: in front of the chest for the two-hand hold,
## else null (the right palm's socket, player.gd). Only valid during the skeleton update.
func hold_ball(sk: Skeleton3D):
	if not two_hand or weight <= 0.0 or not _rig_ok:
		return null
	return sk.get_bone_global_pose(_bones.spine_03) * Transform3D(Basis(), HOLD_BALL)

func _blend(sk: Skeleton3D, bone: int, local: Basis, w: float) -> void:
	var q := local.orthonormalized().get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(q, w))
