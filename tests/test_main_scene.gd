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
