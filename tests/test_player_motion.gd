extends "res://tests/test_case.gd"

const PM := preload("res://src/sim/player_motion.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0

func _run(p, input: Vector2, sprint: bool, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		p.step(input, sprint, DT)

func test_reaches_run_speed_within_1s() -> void:
	var p := PM.new(Vector2(25, 50))
	_run(p, Vector2.UP, false, 1.0)
	assert_near(p.speed(), T.RUN_SPEED, 0.1, "run speed")

func test_sprint_faster_than_run() -> void:
	var p := PM.new(Vector2(25, 20))
	_run(p, Vector2(0, 1), true, 1.0)
	assert_near(p.speed(), T.SPRINT_SPEED, 0.1, "sprint speed")
	assert_true(T.SPRINT_SPEED > T.RUN_SPEED, "sprint > run")

func test_sprint_drains_and_locks_out() -> void:
	var p := PM.new(Vector2(25, -10))
	_run(p, Vector2(0, 1), true, 1.0)
	assert_true(p.stamina < 1.0, "stamina drained")
	_run(p, Vector2(0, 1), true, 4.0)  # total 5s > 1/0.25
	assert_true(p.sprint_locked, "locked at 0 stamina")
	_run(p, Vector2(0, 1), true, 0.5)
	assert_near(p.speed(), T.RUN_SPEED, 0.1, "capped at run speed while locked")

func test_lockout_releases_at_threshold() -> void:
	var p := PM.new(Vector2(25, 50))
	p.stamina = 0.0
	p.sprint_locked = true
	_run(p, Vector2.ZERO, false, 1.0)  # +0.15
	assert_true(p.sprint_locked, "still locked at 0.15")
	_run(p, Vector2.ZERO, false, 1.0)  # +0.30
	assert_true(not p.sprint_locked, "unlocked at >= 0.25")

func test_regen_caps_at_one() -> void:
	var p := PM.new(Vector2(25, 50))
	p.stamina = 0.9
	_run(p, Vector2.ZERO, false, 5.0)
	assert_near(p.stamina, 1.0, 0.0001, "capped")

func test_decelerates_to_stop() -> void:
	var p := PM.new(Vector2(25, 50))
	_run(p, Vector2(1, 0), true, 1.0)
	_run(p, Vector2.ZERO, false, 1.0)
	assert_near(p.speed(), 0.0, 0.01, "stopped")

func test_clamped_to_playable_area() -> void:
	var p := PM.new(Vector2(25, 50))
	_run(p, Vector2(-1, 0), false, 10.0)
	assert_near(p.position.x, -T.OOB_MARGIN, 0.001, "sideline clamp")

func test_diagonal_not_faster() -> void:
	var p := PM.new(Vector2(25, 50))
	_run(p, Vector2(1, 1), false, 1.0)
	assert_true(p.speed() <= T.RUN_SPEED + 0.01, "diagonal capped")
