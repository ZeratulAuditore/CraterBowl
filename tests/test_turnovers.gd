extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")
const AI := preload("res://src/sim/ai.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

var events: Array = []

func _match(los: float = 25.0) -> Match:
	events.clear()
	var w := World.new()
	Roster.new().build(w)
	var m := Match.new(w)
	m.start(0, los)
	w.event.connect(func(n, _d): events.append(n))
	return m

## Move every athlete far away so tests control who is near the action.
func _clear_field(w, keep: Array) -> void:
	for a in w.athletes:
		if not keep.has(a.id):
			a.position = Vector2(2 + a.id * 0.1, 5.0 if a.team == 0 else 95.0)

func _snap(w) -> void:
	w.snap()
	for i in 30: w.step({}, DT)

func _run(w, seconds: float, inputs := {}) -> void:
	for i in int(round(seconds / DT)):
		w.step(inputs, DT)
		if w.phase == World.Phase.DEAD:
			return

func test_lone_defender_intercepts() -> void:
	var m := _match()
	var w := m.world
	_snap(w)
	var qb := w.find_role(0, R.QB)
	var cb := w.find_role(1, R.CB)
	_clear_field(w, [qb.id, cb.id])
	cb.position = Vector2(30, 40)
	w.throw(qb.id, Vector2(30, 40), 0.8)
	_run(w, 3.0)
	assert_true(events.has("interception"), "interception: %s" % str(events))
	assert_true(w.ball.is_held_by(cb.id), "CB holds")
	assert_eq(w.phase, World.Phase.LIVE, "live return")
	assert_eq(w.possession_team(), 1, "possession flipped")

func test_contested_still_breakup() -> void:
	var m := _match()
	var w := m.world
	_snap(w)
	var qb := w.find_role(0, R.QB)
	var cb := w.find_role(1, R.CB)
	var wr := w.find_role(0, R.WR)
	_clear_field(w, [qb.id, cb.id, wr.id])
	wr.position = Vector2(30, 40)
	cb.position = Vector2(30.3, 40)
	w.throw(qb.id, Vector2(30.1, 40), 0.8)
	_run(w, 3.0)
	assert_true(events.has("breakup") and not events.has("interception"), "breakup: %s" % str(events))

func _intercept_and_hold(w: World) -> Athlete:
	_snap(w)
	var cb := w.find_role(1, R.CB)
	w.ball.hold(cb.id)
	w.last_possession = 1
	return cb

func test_int_return_tackled_is_turnover() -> void:
	var m := _match(25.0)
	var w := m.world
	var cb := _intercept_and_hold(w)
	cb.position = Vector2(26, 60)
	var wr := w.find_role(0, R.WR)
	wr.position = Vector2(26, 61)
	wr.facing = Vector2(0, -1)
	w.tackle(wr.id)
	_run(w, 0.5)
	assert_true(events.has("tackle"), "tackled")
	var out := m.next_play()
	assert_eq(out["outcome"], "turnover")
	assert_eq(w.offense_team, 1, "team 1 offense")
	assert_true(absf(w.los_y - (100.0 - cb.position.y)) < 1.5 or absf(w.los_y - 40.0) < 1.5, "mirrored spot (los %f)" % w.los_y)
	assert_eq(m.downs.down, 1)

func test_pick_six() -> void:
	var m := _match(25.0)
	var w := m.world
	var cb := _intercept_and_hold(w)
	cb.position = Vector2(26, -0.5)   # end zone A = the defense's scoring end
	w.step({}, DT)
	assert_true(events.has("touchdown"), "pick six TD")
	var out := m.next_play()
	assert_eq(m.score[1], 6, "defense +6")
	assert_eq(out["outcome"], "try")
	assert_eq(w.offense_team, 1, "defense attempts the try")

func test_int_downed_in_own_endzone_touchback() -> void:
	var m := _match(80.0)
	var w := m.world
	var cb := _intercept_and_hold(w)
	cb.position = Vector2(26, 104)
	var wr := w.find_role(0, R.WR)
	wr.position = Vector2(26, 103.1)
	wr.facing = Vector2(0, 1)
	w.tackle(wr.id)
	_run(w, 0.5)
	assert_true(events.has("tackle"), "downed in end zone")
	m.next_play()
	assert_eq(w.offense_team, 1)
	assert_near(w.los_y, 25.0, 0.001, "touchback at 25")

func _sprinting_carrier(m) -> Array:
	var w = m.world
	_snap(w)
	var qb = w.find_role(0, R.QB)
	var lb = w.find_role(1, R.LB)
	_clear_field(w, [qb.id, lb.id])
	qb.position = Vector2(26, 40)
	var inp := {qb.id: {"dir": Vector2(0, 1), "sprint": true}}
	_run(w, 0.5, inp)
	return [qb, lb, inp]

func test_strip_from_behind_fumbles() -> void:
	var m := _match()
	var w := m.world
	var s := _sprinting_carrier(m)
	var qb = s[0]
	var lb = s[1]
	lb.position = qb.position - Vector2(0, 1.2)
	lb.facing = Vector2(0, 1)   # same direction as carrier = from behind
	w.tackle(lb.id)
	for i in 30:   # carrier keeps sprinting until the diver closes
		w.step(s[2], DT)
		if events.has("fumble") or events.has("tackle"):
			break
	assert_true(events.has("fumble"), "fumble: %s" % str(events))
	assert_eq(w.ball.state, Ball.State.LOOSE, "loose")
	assert_eq(w.phase, World.Phase.LIVE, "still live")

func test_head_on_is_plain_tackle() -> void:
	var m := _match()
	var w := m.world
	var s := _sprinting_carrier(m)
	var qb = s[0]
	var lb = s[1]
	lb.position = qb.position + Vector2(0, 1.5)
	lb.facing = Vector2(0, -1)
	w.tackle(lb.id)
	_run(w, 0.3, s[2])
	assert_true(events.has("tackle") and not events.has("fumble"), "tackle: %s" % str(events))

func test_fumble_recovered_by_defense_is_turnover() -> void:
	var m := _match()
	var w := m.world
	var s := _sprinting_carrier(m)
	var qb = s[0]
	var lb = s[1]
	lb.position = qb.position - Vector2(0, 1.2)
	lb.facing = Vector2(0, 1)
	w.tackle(lb.id)
	for i in 30:   # carrier keeps sprinting until the diver closes
		w.step(s[2], DT)
		if events.has("fumble") or events.has("tackle"):
			break
	var s2 := w.find_role(1, R.S)
	s2.position = Vector2(w.ball.position.x, w.ball.position.y + 2.0)
	for i in 120:   # safety runs at the ball
		var bp := Vector2(w.ball.position.x, w.ball.position.y)
		w.step({s2.id: {"dir": (bp - s2.position).normalized()}}, DT)
		if events.has("recovery"):
			break
	assert_true(events.has("recovery"), "recovered: %s" % str(events))
	assert_eq(w.possession_team(), 1, "defense has it")

func test_loose_ball_out_of_bounds_offense_keeps() -> void:
	var m := _match()
	var w := m.world
	_snap(w)
	_clear_field(w, [])
	w.ball.state = Ball.State.LOOSE
	w.ball.holder_id = -1
	w.last_possession = 0
	w.ball.position = Vector3(1.0, 40, 0.5)
	w.ball.velocity = Vector3(-6, 0, 0)
	_run(w, 2.0)
	assert_true(events.has("out_of_bounds"), "oob")
	var out := m.next_play()
	assert_eq(w.offense_team, 0, "fumbling team keeps it")
	assert_true(out["outcome"] != "turnover", "no turnover")

func test_ai_chases_loose_ball() -> void:
	var m := _match()
	var w := m.world
	_snap(w)
	w.ball.state = Ball.State.LOOSE
	w.ball.holder_id = -1
	w.ball.position = Vector3(26, 45, 0)
	w.ball.velocity = Vector3.ZERO
	var ai := AI.new()
	for i in 600:
		w.step(ai.think(w, []), DT)
		if events.has("recovery"):
			break
	assert_true(events.has("recovery"), "AI recovered loose ball")

func test_deflection_at_reach_not_interception() -> void:
	var m := _match()
	var w := m.world
	_snap(w)
	var qb := w.find_role(0, R.QB)
	var cb := w.find_role(1, R.CB)
	_clear_field(w, [qb.id, cb.id])
	cb.position = Vector2(31.0, 40)   # ~1 yd off the ball's line: in reach, outside INT radius
	w.throw(qb.id, Vector2(30, 40), 0.8)
	_run(w, 3.0)
	assert_true(events.has("breakup") and not events.has("interception"), "deflected: %s" % str(events))

func test_no_bat_at_release() -> void:
	var m := _match()
	var w := m.world
	_snap(w)
	var qb := w.find_role(0, R.QB)
	var dl := w.find_role(1, R.DL)
	_clear_field(w, [qb.id, dl.id])
	dl.position = qb.position + Vector2(0, 1.0)   # rusher in the QB's face
	w.throw(qb.id, qb.position + Vector2(0, 25), 0.9)
	for i in 6: w.step({}, DT)
	assert_true(not events.has("breakup") and not events.has("interception"), "not batted at release: %s" % str(events))
