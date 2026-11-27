extends SkeletonModifier3D
## Procedural arm pose layered on top of the playing clip (#244). Godot 4.3 runs
## _process_modification() after the AnimationPlayer has posed the skeleton.
## Ball carry: two-bone IK pulls the right hand to the chest, elbow tucked at the side.
## A passer holding before the throw holds the ball in front of the chest, one hand on
## each side of it (palms in), and the ball sits there instead of in the right palm.
## View-only (no sim state). weight 0 leaves the clip pose untouched; player.gd smooths it.

## Hand targets and elbow hints in spine_03 space (rig: +Z forward, +Y up, right = -X).
const TUCK_HAND := Vector3(-0.17, 0.06, 0.13)
const TUCK_POLE := Vector3(-0.6, -1.0, -0.6)
## Two-hand hold: ball center, and each wrist beside it (ball radius 0.13 + palm, fingers forward).
const HOLD_BALL := Vector3(0.0, 0.02, 0.28)
const HOLD_WRIST_R := HOLD_BALL + Vector3(-0.15, 0.0, -0.08)
const HOLD_WRIST_L := HOLD_BALL + Vector3(0.15, 0.0, -0.08)
const HOLD_POLE_R := Vector3(-1.0, -1.0, -0.3)
const HOLD_POLE_L := Vector3(1.0, -1.0, -0.3)
## Hand orientation for the hold, in spine_03 space: fingers forward (bone +Y = +Z) and
## palms in (palm is -X of hand_r and +X of hand_l, so both map bone +X to spine -X).
const HOLD_HAND_BASIS := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))

## Hands on the ball open from the clip's fist toward the rig's flat rest pose by this
## much, leaving a slight curl so the fingers wrap the ball.
const HAND_OPEN := 0.7
const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]

var weight := 0.0      # 0 = clip pose, 1 = full carry pose
var two_hand := false  # passer holding before the throw
var _bones := {}
var _fingers := {}     # "_r"/"_l" -> finger bone ids (joints 01-03)

func _process_modification() -> void:
	apply(get_skeleton())

func apply(sk: Skeleton3D) -> void:
	if weight <= 0.0 or sk == null:
		return
	if _bones.is_empty():
		for n in ["spine_03", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l"]:
			_bones[n] = sk.find_bone(n)
		if _bones.values().has(-1):
			return   # rig without arm bones: keep the clip
		for side in ["_r", "_l"]:
			_fingers[side] = []
			for f in FINGERS:
				for j in ["01", "02", "03"]:
					var b := sk.find_bone("%s_%s%s" % [f, j, side])
					if b >= 0:
						_fingers[side].append(b)
	var chest := sk.get_bone_global_pose(_bones.spine_03)
	if two_hand:
		var palms_in := chest.basis * HOLD_HAND_BASIS
		_reach(sk, "_r", chest * HOLD_WRIST_R, chest.basis * HOLD_POLE_R, palms_in)
		_reach(sk, "_l", chest * HOLD_WRIST_L, chest.basis * HOLD_POLE_L, palms_in)
		_open_hand(sk, "_l")
	else:
		_reach(sk, "_r", chest * TUCK_HAND, chest.basis * TUCK_POLE)
	_open_hand(sk, "_r")

## Uncurl the clip's fist so the fingers spread around the ball.
func _open_hand(sk: Skeleton3D, side: String) -> void:
	var k := HAND_OPEN * weight
	for b in _fingers.get(side, []):
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(sk.get_bone_rest(b).basis.get_rotation_quaternion(), k))

## Two-bone IK (skeleton space): hand to `target`, elbow bent toward `pole`. The hand takes
## `hand_basis` if given, else keeps the clip's wrist angle. Blended into local rotations by weight.
func _reach(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3, hand_basis = null) -> void:
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
	_blend(sk, u, sk.get_bone_global_pose(sk.get_bone_parent(u)).basis.inverse() * nu.basis)
	_blend(sk, l, nu.basis.inverse() * nl.basis)
	_blend(sk, h, nl.basis.inverse() * nh_basis)

## Where the held ball sits, in skeleton space: in front of the chest for the two-hand hold,
## else null (the right palm's socket, player.gd). Only valid during the skeleton update.
func hold_ball(sk: Skeleton3D):
	if not two_hand or weight <= 0.0 or _bones.is_empty() or _bones.values().has(-1):
		return null
	return sk.get_bone_global_pose(_bones.spine_03) * Transform3D(Basis(), HOLD_BALL)

func _blend(sk: Skeleton3D, bone: int, local: Basis) -> void:
	var q := local.orthonormalized().get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(q, weight))
