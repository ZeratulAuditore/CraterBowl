extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0

func _world() -> World:
	var w := World.new()
	w.add_athlete(0, Athlete.Role.C, Vector2(26, 20))
	w.add_athlete(0, Athlete.Role.QB, Vector2(26, 15))
	w.add_athlete(0, Athlete.Role.WR, Vector2(5, 20))
	w.add_athlete(1, Athlete.Role.LB, Vector2(26, 30))
	w.setup_formation(25.0)
	return w

func _run(w, inputs: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		w.step(inputs, DT)

func test_formation() -> void:
	var w := _world()
	var c := w.find_role(0, Athlete.Role.C)
	var qb := w.find_role(0, Athlete.Role.QB)
	assert_near(c.position.y, 24.5, 0.001, "C on LOS")
	assert_near(qb.position.y, 20.0, 0.001, "QB 5 behind")
	assert_eq(w.phase, World.Phase.PRESNAP, "presnap")
	assert_true(w.ball.is_held_by(c.id), "C holds ball")

func test_neutral_zone_presnap() -> void:
	var w := _world()
	var wr := w.find_role(0, Athlete.Role.WR)
	var lb := w.find_role(1, Athlete.Role.LB)
	_run(w, {wr.id: {"dir": Vector2(0, 1), "sprint": true}, lb.id: {"dir": Vector2(0, -1)}}, 3.0)
	assert_true(wr.position.y <= 24.5 + 0.0001, "offense held behind LOS")
	assert_true(lb.position.y >= 25.5 - 0.0001, "defense held behind LOS")

func test_snap_transfers_to_qb() -> void:
	var w := _world()
	var qb := w.find_role(0, Athlete.Role.QB)
	assert_true(w.snap(), "snap accepted")
	assert_eq(w.phase, World.Phase.LIVE, "live at snap")
	assert_eq(w.ball.state, Ball.State.IN_FLIGHT, "in flight")
	_run(w, {}, T.SNAP_TIME * 0.5)
	assert_eq(w.ball.state, Ball.State.IN_FLIGHT, "still in flight mid-snap")
	_run(w, {}, T.SNAP_TIME)
	assert_true(w.ball.is_held_by(qb.id), "QB holds ball")

func test_second_snap_rejected() -> void:
	var w := _world()
	assert_true(w.snap())
	assert_true(not w.snap(), "can't snap during live play")

func test_held_ball_follows_holder() -> void:
	var w := _world()
	var qb := w.find_role(0, Athlete.Role.QB)
	w.snap()
	_run(w, {}, 1.0)
	_run(w, {qb.id: {"dir": Vector2(1, 0)}}, 1.0)
	assert_near(w.ball.position.x, qb.position.x, 0.001, "ball x")
	assert_near(w.ball.position.y, qb.position.y, 0.001, "ball y")

func test_live_players_can_cross_los() -> void:
	var w := _world()
	var wr := w.find_role(0, Athlete.Role.WR)
	w.snap()
	_run(w, {wr.id: {"dir": Vector2(0, 1)}}, 2.0)
	assert_true(wr.position.y > 26.0, "WR runs past LOS after snap")
