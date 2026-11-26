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

func test_hands_on_the_ball_open_from_the_fist() -> void:
	var v = _view(Athlete.Role.QB)
	var sk := _skel(v)
	var clip: Animation = v.anim.get_animation("Idle")
	_pose(sk, clip, 0.5)
	var fist := _curl(sk, "_r")
	v.pose.weight = 1.0
	v.pose.apply(sk)
	var tuck := _curl(sk, "_r")
	assert_true(fist > 0.5, "the clip holds a fist (finger curl %.2f rad)" % fist)
	assert_true(tuck < fist * 0.5, "carrying hand opens: curl %.2f -> %.2f rad" % [fist, tuck])
	assert_true(tuck > 0.0, "fingers keep a slight curl to wrap the ball")
	assert_true(_curl(sk, "_l") > fist * 0.9, "one-arm tuck leaves the free hand alone")
	_pose(sk, clip, 0.5)
	v.pose.two_hand = true
	v.pose.apply(sk)
	assert_true(_curl(sk, "_l") < fist * 0.5 and _curl(sk, "_r") < fist * 0.5, "two-hand hold opens both hands")
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

# --- #245 head look -------------------------------------------------------------

const Pose := preload("res://src/game/art/athlete_pose.gd")

func test_look_angles_clamp_to_neck_limits() -> void:
	var cases := [   # direction in the chest frame (+Z fwd, +X left, +Y up) -> expected (yaw, pitch) deg
		[Vector3(0, 0, 1), Vector2(0, 0), "straight ahead"],
		[Vector3(1, 0, 1), Vector2(45, 0), "45 deg left"],
		[Vector3(-1, 0, 1), Vector2(-45, 0), "45 deg right"],
		[Vector3(1, 0, 0), Vector2(60, 0), "90 deg left: clamped to 80, a quarter faded"],
		[Vector3(0, 0, -1), Vector2(0, 0), "directly behind: neutral, no wrap"],
		[Vector3(0.1, 0, -1), Vector2(0, 0), "behind, slightly left: neutral"],
		[Vector3(0, 5, 1), Vector2(0, 40), "steep up: clamped to 40"],
		[Vector3(0, -5, 1), Vector2(0, -30), "steep down: clamped to -30"],
	]
	for c in cases:
		var a := Pose.look_angles(c[0])
		assert_near(rad_to_deg(a.x), c[1].x, 0.5, "%s yaw" % c[2])
		assert_near(rad_to_deg(a.y), c[1].y, 0.5, "%s pitch" % c[2])

func test_head_turns_toward_the_target() -> void:
	var v = _view(Athlete.Role.CB)
	var sk := _skel(v)
	var clip: Animation = v.anim.get_animation("Idle")
	_pose(sk, clip, 0.5)
	var before := _head_angles(sk)
	var head := _bone_pos(sk, "Head")
	var chest := sk.get_bone_global_pose(sk.find_bone("spine_03")).basis
	v.pose.look_target = head + chest * Vector3(1, 0.3, 1) * 5.0   # 45 deg left, a little up
	v.pose.look_weight = 1.0
	v.pose.apply(sk)
	sk.force_update_all_bone_transforms()
	var turn := _head_angles(sk) - before
	assert_near(turn.x, 45.0, 4.0, "head yaw turn toward a target 45 deg left")
	assert_true(turn.y > 5.0 and turn.y < 25.0, "head pitches up toward it: %.1f deg" % turn.y)
	v.free()

func test_head_stays_within_limits_for_every_direction() -> void:
	var v = _view(Athlete.Role.S)
	var sk := _skel(v)
	var clip: Animation = v.anim.get_animation("Idle")
	var worst_yaw := 0.0
	var worst_up := 0.0
	var worst_down := 0.0
	for i in 24:
		for el in [-80.0, -20.0, 0.0, 30.0, 80.0]:
			_pose(sk, clip, 0.5)
			var before := _head_angles(sk)
			var chest := sk.get_bone_global_pose(sk.find_bone("spine_03")).basis
			var az := deg_to_rad(i * 15.0)
			var e := deg_to_rad(el)
			var d := Vector3(sin(az) * cos(e), sin(e), cos(az) * cos(e))
			v.pose.look_target = _bone_pos(sk, "Head") + chest * d * 6.0
			v.pose.look_weight = 1.0
			v.pose.apply(sk)
			sk.force_update_all_bone_transforms()
			var turn := _head_angles(sk) - before
			worst_yaw = maxf(worst_yaw, absf(turn.x))
			worst_up = maxf(worst_up, turn.y)
			worst_down = minf(worst_down, turn.y)
	# +5: measured on the final head, so steep pitch combined with the clip's own head tilt adds a few degrees.
	assert_true(worst_yaw <= 85.0, "head yaw turn never past 80 deg (+5 measurement slack): worst %.1f" % worst_yaw)
	assert_true(worst_up <= 41.0 and worst_down >= -31.0, "pitch within -30..40: %.1f..%.1f" % [worst_down, worst_up])
	v.free()

func test_no_look_weight_leaves_the_head_alone() -> void:
	var v = _view(Athlete.Role.LB)
	var sk := _skel(v)
	_pose(sk, v.anim.get_animation("Idle"), 0.5)
	var q: Quaternion = sk.get_bone_pose_rotation(sk.find_bone("Head"))
	v.pose.look_target = Vector3(5, 1.5, 5)
	v.pose.look_weight = 0.0
	v.pose.apply(sk)
	assert_eq(sk.get_bone_pose_rotation(sk.find_bone("Head")), q, "weight 0: head bone")
	v.free()

func test_heads_far_from_the_camera_do_not_look() -> void:
	assert_true(PlayerNode.head_visible(20.0, 65.0), "follow camera (65 deg): 20 yd away turns")
	assert_true(not PlayerNode.head_visible(30.0, 65.0), "follow camera: 30 yd away is too small to see")
	assert_true(PlayerNode.head_visible(45.0, 34.0), "zoomed broadcast replay (34 deg): 45 yd still turns")
	assert_true(not PlayerNode.head_visible(60.0, 34.0), "broadcast replay: 60 yd doesn't")

# --- helpers ------------------------------------------------------------------

## Head facing (Head bone +Z) as (yaw, pitch) degrees in the chest's frame.
func _head_angles(sk: Skeleton3D) -> Vector2:
	var chest := sk.get_bone_global_pose(sk.find_bone("spine_03")).basis
	var f := chest.inverse() * sk.get_bone_global_pose(sk.find_bone("Head")).basis.z
	return Vector2(rad_to_deg(atan2(f.x, f.z)), rad_to_deg(atan2(f.y, Vector2(f.x, f.z).length())))

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

## Mean angle (rad) of the middle finger's joints away from the open rest pose.
func _curl(sk: Skeleton3D, side: String) -> float:
	var total := 0.0
	for j in ["01", "02", "03"]:
		var b := sk.find_bone("middle_%s%s" % [j, side])
		total += sk.get_bone_pose_rotation(b).angle_to(sk.get_bone_rest(b).basis.get_rotation_quaternion())
	return total / 3.0

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
