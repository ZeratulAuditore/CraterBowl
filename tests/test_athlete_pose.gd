extends "res://tests/test_case.gd"
## #244: ball carry pose. The carrier's right arm tucks the ball to the chest over the
## running clip; a passer holding before the throw uses both hands; the ball sits in the
## palm. Poses are sampled from the real rig and clips (no mixer), then the modifier runs.

const PlayerNode := preload("res://src/game/player.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const SAMPLES := 10
## Tucked: hand at the chest, not swinging at the hip (bone units, about meters).
const MAX_TUCK_DIST := 0.25
## Two-hand hold: each wrist beside the ball (radius 0.15), on opposite sides of it.
const HOLD_WRIST_TO_BALL := [0.12, 0.3]

func test_carry_tucks_right_hand_to_chest_through_the_sprint() -> void:
	var v = _view(Athlete.Role.RB)
	var sk := _skel(v)
	var clip: Animation = v.anim.get_animation("Sprint")
	var worst_clip := 0.0
	var worst_tuck := 0.0
	for i in SAMPLES:
		var t := clip.length * float(i) / SAMPLES
		_pose(sk, clip, t)
		worst_clip = maxf(worst_clip, _hand_to_chest(sk, "hand_r"))
		v.pose.weight = 1.0
		v.pose.apply(sk)
		sk.force_update_all_bone_transforms()
		worst_tuck = maxf(worst_tuck, _hand_to_chest(sk, "hand_r"))
	assert_true(worst_clip > MAX_TUCK_DIST, "the plain sprint swings the hand away from the chest (%.2f)" % worst_clip)
	assert_true(worst_tuck < MAX_TUCK_DIST, "tucked hand stays at the chest: worst %.2f m" % worst_tuck)
	v.free()

func test_no_carry_leaves_the_clip_pose_untouched() -> void:
	var v = _view(Athlete.Role.WR)
	var sk := _skel(v)
	_pose(sk, v.anim.get_animation("Sprint"), 0.3)
	var before := _arm_rotations(sk)
	v.pose.weight = 0.0
	v.pose.apply(sk)
	assert_eq(_arm_rotations(sk), before, "weight 0: arm bones")
	v.free()

func test_passer_holds_the_ball_with_both_hands() -> void:
	var v = _view(Athlete.Role.QB)
	var sk := _skel(v)
	_pose(sk, v.anim.get_animation("Idle"), 0.5)
	v.pose.weight = 1.0
	v.pose.two_hand = true
	v.pose.apply(sk)
	sk.force_update_all_bone_transforms()
	var ball: Vector3 = v.ball_local(sk).origin
	var r := _bone_pos(sk, "hand_r") - ball
	var l := _bone_pos(sk, "hand_l") - ball
	for d in [r.length(), l.length()]:
		assert_true(d > HOLD_WRIST_TO_BALL[0] and d < HOLD_WRIST_TO_BALL[1], "each hand beside the ball: %.2f m" % d)
	assert_true(r.dot(l) < 0.0, "hands on opposite sides of the ball, not stacked")
	assert_true(r.x < 0.0 and l.x > 0.0, "right hand on the ball's right (-X), left on its left")
	assert_true(ball.distance_to(_bone_pos(sk, "spine_03")) < 0.4, "ball held in front of the chest")
	v.free()

func test_throw_release_drops_the_carry_at_once() -> void:
	var v = _view(Athlete.Role.QB)
	var ball := Node3D.new()
	v.set_carry(ball, true)
	v.pose.weight = 1.0
	v.throw_release()
	assert_eq(v.pose.weight, 0.0, "pose weight right after the release")
	assert_true(v.ball_node == null, "the ball left the hand")
	ball.free()
	v.free()

## Same-frame pinning in the live scene is checked by game_flow.gd (needs the tree).
func test_ball_socket_sits_in_the_tucked_palm() -> void:
	var v = _view(Athlete.Role.RB)
	var sk := _skel(v)
	_pose(sk, v.anim.get_animation("Sprint"), 0.2)
	v.pose.weight = 1.0
	v.pose.apply(sk)
	sk.force_update_all_bone_transforms()
	var ball: Transform3D = v.ball_local(sk)
	var wrist := _bone_pos(sk, "hand_r")
	assert_true(ball.origin.distance_to(wrist) < 0.2, "ball in the hand: %.2f m from the wrist" % ball.origin.distance_to(wrist))
	assert_true(_hand_to_chest(sk, "hand_r") < MAX_TUCK_DIST, "held at the chest")
	var forearm := (wrist - _bone_pos(sk, "lowerarm_r")).normalized()
	var along := absf(ball.basis.z.normalized().dot(forearm))
	assert_true(along > 0.9, "long axis along the forearm (|cos| %.2f)" % along)
	v.free()

# --- helpers ------------------------------------------------------------------

func _view(role: int):
	var a = Athlete.new()
	a.role = role
	var v = PlayerNode.new()
	v.setup(a, Color(0.8, 0.2, 0.2))
	v._ready()   # unit tests run before the tree processes; build the rig directly
	return v

func _skel(v) -> Skeleton3D:
	return v.mesh_i.get_parent()

func _bone_pos(sk: Skeleton3D, bone: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone(bone)).origin

func _hand_to_chest(sk: Skeleton3D, hand: String) -> float:
	return _bone_pos(sk, hand).distance_to(_bone_pos(sk, "spine_03") + Vector3(0, 0, 0.12))

func _arm_rotations(sk: Skeleton3D) -> Array:
	var out := []
	for b in ["upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l"]:
		out.append(sk.get_bone_pose_rotation(sk.find_bone(b)))
	return out

## Set the skeleton to `anim` at time t from the clip's own tracks (as test_helmet_fit.gd).
func _pose(sk: Skeleton3D, anim: Animation, t: float) -> void:
	sk.reset_bone_poses()
	for tr in anim.get_track_count():
		var bone := sk.find_bone(anim.track_get_path(tr).get_concatenated_subnames())
		if bone < 0:
			continue
		match anim.track_get_type(tr):
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(bone, anim.position_track_interpolate(tr, t))
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(tr, t))
			Animation.TYPE_SCALE_3D:
				sk.set_bone_pose_scale(bone, anim.scale_track_interpolate(tr, t))
	sk.force_update_all_bone_transforms()
