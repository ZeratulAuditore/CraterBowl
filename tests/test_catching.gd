extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")
const Passing := preload("res://src/sim/passing.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0

var events: Array = []
var catches: Array = []

func _setup(extra: Array) -> World:
	events.clear()
	catches.clear()
	var w := World.new()
	w.add_athlete(0, Athlete.Role.C, Vector2(26, 20))
	w.add_athlete(0, Athlete.Role.QB, Vector2(26, 15))
	for e in extra:
		w.add_athlete(e[0], e[1], e[2])
	w.setup_formation(25.0)
	# setup_formation moves y; restore requested positions for test control
	for i in extra.size():
		w.athletes[2 + i].position = extra[i][2]
	w.event.connect(func(n, d):
		events.append(n)
		if n == "catch": catches.append(d["by"]))
	w.snap()
	_run(w, {}, 0.5)
	return w

func _run(w, inputs: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		w.step(inputs, DT)
		if w.phase == World.Phase.DEAD:
			return

func _qb(w) -> Athlete:
	return w.find_role(0, Athlete.Role.QB)

func test_lead_pass_caught_by_running_wr() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(10, 24)]])
	var wr: Athlete = w.athletes[2]
	var go := {wr.id: {"dir": Vector2(0, 1)}}
	_run(w, go, 1.0)  # WR at speed
	var qb := _qb(w)
	var from := Vector3(qb.position.x, qb.position.y, T.RELEASE_HEIGHT)
	var tgt := Passing.lead_target(from, wr.position, wr.velocity, 0.8)
	assert_true(w.throw(qb.id, tgt, 0.8), "throw")
	_run(w, go, 4.0)
	assert_true(events.has("catch"), "caught: %s" % str(events))
	assert_true(w.ball.is_held_by(wr.id), "WR holds")
	assert_eq(w.phase, World.Phase.LIVE, "play continues")

func test_uncatchable_pass_incomplete() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(5, 24)]])
	w.throw(_qb(w).id, Vector2(48, 40), 0.7)
	_run(w, {}, 5.0)
	assert_true(events.has("incomplete") and not events.has("catch"), "incomplete")

func test_thrower_cannot_catch_own_pass() -> void:
	var w := _setup([])
	var qb := _qb(w)
	w.throw(qb.id, qb.position + Vector2(0, 0.5), 0.0)
	_run(w, {}, 3.0)
	assert_true(not catches.has(qb.id), "thrower never catches own pass")

func test_high_ball_sails_over() -> void:
	# Receiver right under the midpoint of a long arc: ball is far above window there.
	var w := _setup([[0, Athlete.Role.WR, Vector2(26, 40)]])
	w.throw(_qb(w).id, Vector2(26, 62), 0.75)
	_run(w, {}, 6.0)
	assert_true(not events.has("catch"), "sailed over: %s" % str(events))

func test_contested_ball_broken_up() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(26, 40)], [1, Athlete.Role.CB, Vector2(26.3, 40)]])
	w.throw(_qb(w).id, Vector2(26.1, 40), 0.8)
	_run(w, {}, 4.0)
	assert_true(events.has("breakup"), "breakup: %s" % str(events))
	assert_true(not events.has("catch"), "no catch")
	assert_eq(w.phase, World.Phase.DEAD, "dead")

func test_out_of_bounds_catch_incomplete() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(-1.0, 40)]])
	w.throw(_qb(w).id, Vector2(-1.0, 40), 0.9)
	_run(w, {}, 4.0)
	assert_true(events.has("out_of_bounds"), "oob: %s" % str(events))
	assert_true(not events.has("catch"), "no catch")

func test_center_is_ineligible() -> void:
	var w := _setup([])
	var c := w.find_role(0, Athlete.Role.C)
	assert_true(not w.is_eligible_receiver(c), "C ineligible")
	w.throw(_qb(w).id, c.position, 0.8)
	_run(w, {}, 4.0)
	assert_true(not catches.has(c.id), "C never catches")
