extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Drills := preload("res://src/sim/drills.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const Passing := preload("res://src/sim/passing.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

func _drill(kind: String) -> Array:
	var w := World.new()
	var d := Drills.new()
	d.build(w, kind)
	w.event.connect(d.on_event)
	d.start_rep(w)
	return [w, d]

func test_builds() -> void:
	var p := _drill("passing")
	assert_eq(p[0].athletes.size(), 4)
	assert_eq(p[0].get_athlete(p[1].me).role, R.QB, "you are QB")
	var c := _drill("catching")
	assert_eq(c[0].get_athlete(c[1].me).role, R.WR, "you are WR")
	assert_true(c[0].find_role(1, R.CB) != null, "a CB covers you")
	var t := _drill("tackling")
	assert_eq(t[0].get_athlete(t[1].me).role, R.LB, "you are LB")

func test_passing_scoring_and_reset() -> void:
	var r := _drill("passing")
	var w: World = r[0]
	var d: Drills = r[1]
	var p0 := w.play_name
	w.snap()
	d.on_event("catch", {"by": 1})
	assert_eq(d.successes, 1)
	assert_eq(d.streak, 1)
	var reset := false
	for i in 120:
		if d.tick(w, DT):
			reset = true
			break
	assert_true(reset, "rep resets after pause")
	d.start_rep(w)
	assert_eq(w.phase, World.Phase.PRESNAP)
	assert_near(w.los_y, Drills.LOS)
	assert_true(w.play_name != p0, "next play")
	d.on_event("incomplete", {})
	assert_eq(d.streak, 0, "miss resets streak")
	assert_eq(d.best_streak, 1)
	assert_eq(d.reps, 2)

func test_tackling_starts_live_and_scores() -> void:
	var r := _drill("tackling")
	var w: World = r[0]
	var d: Drills = r[1]
	assert_eq(w.phase, World.Phase.LIVE, "live start")
	var rb := w.find_role(0, R.RB)
	assert_true(w.ball.is_held_by(rb.id), "RB carries")
	var lb := w.get_athlete(d.me)
	lb.position = rb.position + Vector2(0, 0.95)
	lb.facing = Vector2(0, -1)
	w.tackle(lb.id)
	for i in 30: w.step({}, DT)
	assert_eq(d.successes, 1, "tackle scored")

func test_tackling_timeout_misses() -> void:
	var r := _drill("tackling")
	var w: World = r[0]
	var d: Drills = r[1]
	w.get_athlete(d.me).position = Vector2(2, 90)  # nowhere near
	var rb := w.find_role(0, R.RB)
	for i in int((Drills.TACKLE_TIMEOUT + 0.2) / DT):
		w.step({rb.id: {"dir": Vector2(1, 0)}}, DT)   # runs sideways, stays in
		rb.position.x = clampf(rb.position.x, 5, 45)
		d.tick(w, DT)
	assert_eq(d.reps, 1)
	assert_eq(d.successes, 0, "timeout = miss")

func test_catching_ai_qb_throws_to_you() -> void:
	var r := _drill("catching")
	var w: World = r[0]
	var d: Drills = r[1]
	var ai := AI.new()
	w.snap()
	var t := 0.0
	var threw := [false]   # lambdas capture locals by value; mutate a container
	w.event.connect(func(n, _data): if n == "throw": threw[0] = true)
	while t < 4.0 and not w.forward_pass_thrown:
		var inp := ai.think(w, [d.me])
		inp[d.me] = {"dir": Vector2(0, 1), "sprint": false}   # you run upfield
		w.step(inp, DT)
		t += DT
	assert_true(w.forward_pass_thrown and threw[0], "QB threw within 4s (t=%.1f)" % t)
