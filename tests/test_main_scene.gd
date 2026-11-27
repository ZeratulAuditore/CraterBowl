extends "res://tests/test_case.gd"

func test_main_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert_true(packed != null, "main scene loads")
	var inst = packed.instantiate()
	assert_true(inst.has_method("_build_field"), "main script attached")
	inst.free()

## #74: the host's rules (menu "mode" / --mode) must reach _host_game as "game".
func test_host_options_forward_the_rules() -> void:
	var inst = load("res://scenes/main.tscn").instantiate()
	var chaos: Dictionary = inst.host_options({"host": true, "mode": "chaosball", "size": "7", "advertise": "127.0.0.1"})
	assert_eq(chaos.get("game"), "chaosball", "menu Chaosball pick -> host lobby rules")
	assert_eq(chaos.get("advertise"), "127.0.0.1", "advertise forwarded")
	assert_eq(inst.host_options({"host": true, "mode": "classic"}).get("game"), "classic", "classic stays classic")
	assert_eq(inst.host_options({"host": true}).get("game"), "classic", "no mode -> classic")
	var cli: Dictionary = inst.host_options({"host": true, "no-lobby": true, "start-when-ready": true, "playclock": "4"})
	assert_true(cli["no_lobby"] and cli["start_when_ready"] and cli["playclock"] == 4.0, "CLI host flags still forwarded")
	inst.free()

## #128: the follow camera never puts the controlled player's ring below FRAME_FEET_MAX of
## the screen, for any camera distance (#140 zoom scales the offset), FOV, aim range or
## follow lag, and leaves an already-framed look alone. Projects the ring's outer edge.
func test_follow_camera_keeps_the_ring_above_the_hud() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	var feet := Vector3(20, 0, -40)
	var limit: float = 2.0 * m.FRAME_FEET_MAX - 1.0   # NDC, + = down
	var worst := -INF
	for scale in [0.6, 1.0, 1.6]:
		for lag in [-1.5, 0.0, 1.5]:   # camera behind / ahead of its rest spot (yd)
			for yaw in [0.0, PI, 0.7]:
				var rot := Basis(Vector3.UP, yaw)
				var cam: Vector3 = feet + rot * (m.FOLLOW_CAM_OFFSET * scale + Vector3(0, 0, lag))
				for fov in [m.CAMERA_FOV, m.AIM_ZOOM_FOV]:
					for aim in [2.0, 22.0, 65.0]:
						var raw: Vector3 = feet + rot * Vector3(0, 0, -aim)
						var look: Vector3 = m._framed_look(cam, raw, feet, fov)
						var y := _lowest_ring_ndc(cam, look, feet, m.FRAME_RING_R, fov)
						worst = maxf(worst, y)
						assert_true(y <= limit + 0.002, "ring %.3f <= %.3f NDC (scale %.1f lag %.1f fov %.0f aim %.0f)" % [y, limit, scale, lag, fov, aim])
	assert_true(worst > limit - 0.01, "the clamp is what holds the line (worst %.3f)" % worst)
	var rest: Vector3 = feet + m.FOLLOW_CAM_OFFSET
	var close: Vector3 = feet + Vector3(0, 0, -2)
	assert_true(m._framed_look(rest, close, feet, m.CAMERA_FOV).is_equal_approx(close), "a look that already frames the ring is unchanged")
	var plain := _lowest_ring_ndc(rest, feet + Vector3(0, 0, -22), feet, m.FRAME_RING_R, m.CAMERA_FOV)
	assert_true(plain > limit, "without the clamp the default follow look puts the ring at %.3f NDC, below the line" % plain)
	m.free()

func _lowest_ring_ndc(cam: Vector3, look: Vector3, feet: Vector3, r: float, fov: float) -> float:
	var inv := Transform3D(Basis(), cam).looking_at(look, Vector3.UP).affine_inverse()
	var lowest := -INF
	for i in 32:
		var t := TAU * i / 32.0
		var p: Vector3 = inv * (feet + Vector3(cos(t), 0, sin(t)) * r)
		lowest = maxf(lowest, (-p.y / -p.z) / tan(deg_to_rad(fov) * 0.5))
	return lowest

## #109 aim-zoom: the FOV eases back to the default frame-rate independently
## (one 0.1 s frame == two 0.05 s frames), and a replay cut snaps it.
func test_aim_zoom_fov_easing_is_frame_rate_independent() -> void:
	var a = load("res://scenes/main.tscn").instantiate()
	var b = load("res://scenes/main.tscn").instantiate()
	for m in [a, b]:
		m.camera = Camera3D.new()
		m.camera.fov = m.AIM_ZOOM_FOV
		m._replay_cam_cut = false
	assert_eq(a.aim_zoom_fov(), a.CAMERA_FOV, "not charging -> default FOV")
	a._update_fov(0.1)
	b._update_fov(0.05)
	b._update_fov(0.05)
	assert_true(a.camera.fov > a.AIM_ZOOM_FOV and a.camera.fov < a.CAMERA_FOV, "eases, doesn't snap (%.2f)" % a.camera.fov)
	assert_true(absf(a.camera.fov - b.camera.fov) < 0.001, "same FOV at 10 or 20 fps (%.3f vs %.3f)" % [a.camera.fov, b.camera.fov])
	a._replay_cam_cut = true
	a._update_fov(0.001)
	assert_eq(a.camera.fov, a.CAMERA_FOV, "replay cut snaps the FOV")
	for m in [a, b]:
		m.camera.free()
		m.free()
