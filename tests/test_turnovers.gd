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

# --- #99 fumble variety: hit speed, angle, fatigue ---

func test_fresh_carrier_can_fumble_from_a_big_hit() -> void:
	var full := T.DIVE_SPEED + T.SPRINT_SPEED
	assert_true(World.fumble_risk(full, 1.0) > 0.0, "fresh carrier has a base chance")
	assert_true(World.fumble_risk(full, 1.0) <= T.FUMBLE_HIT_RISK + 0.0001, "fresh base stays small")
	assert_eq(World.fumble_risk(0.0, 1.0), 0.0, "no closing speed, no fumble")

func test_fumble_risk_sweeps_with_impact_speed() -> void:
	var prev := -1.0
	for s in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 20.5]:
		var r := World.fumble_risk(s, 1.0)
		assert_true(r > prev or (s == 0.0 and r == 0.0), "fresh risk rises with impact at %.1f (%.4f)" % [s, r])
		prev = r
	assert_near(World.fumble_risk(40.0, 1.0), World.fumble_risk(T.DIVE_SPEED + T.SPRINT_SPEED, 1.0), 0.0001, "force saturates")

func test_fatigue_multiplies_fumble_risk() -> void:
	var s := 15.0
	var fresh := World.fumble_risk(s, 1.0)
	assert_near(World.fumble_risk(s, T.FUMBLE_FRESH_STAMINA), fresh, 0.0001, "no fatigue above the threshold")
	assert_true(World.fumble_risk(s, 0.5) > fresh, "tired > fresh")
	assert_near(World.fumble_risk(s, 0.0), fresh * (1.0 + T.FUMBLE_FATIGUE_GAIN), 0.0001, "exhausted = x(1+gain)")

func test_fumble_risk_sweeps_with_hit_angle() -> void:
	var s := 8.0
	# Facing dot: -1 head-on, 0 from the side, 1 squarely from behind.
	var head_on := World.fumble_risk(s, 1.0, -1.0)
	assert_near(World.fumble_risk(s, 1.0, 0.0), head_on, 0.0001, "side hit: no rear bonus")
	assert_near(World.fumble_risk(s, 1.0, T.FUMBLE_BEHIND_DOT), head_on, 0.0001, "rear bonus starts past FUMBLE_BEHIND_DOT")
	var prev := head_on
	for d in [0.6, 0.7, 0.8, 0.9, 1.0]:
		var r := World.fumble_risk(s, 1.0, d)
		assert_true(r > prev, "more behind = riskier at dot %.1f" % d)
		prev = r
	assert_true(World.fumble_risk(s, 1.0, 1.0, true) > World.fumble_risk(s, 1.0, 1.0, false), "sprinting carrier riskier from behind")
	assert_true(World.fumble_risk(s, 1.0, 0.75, true) < T.FUMBLE_REAR_SPRINT, "oblique rear hit is scaled, not flat")
	assert_true(World.fumble_risk(s, 1.0, 1.0, false) > 0.2, "jogging carrier can be stripped from behind")
	assert_true(World.fumble_risk(99.0, 0.0, 1.0, true) <= T.FUMBLE_MAX_RISK, "capped")

func test_rear_strip_is_deterministic_and_hits_fresh_joggers() -> void:
	# Same hit replayed on fresh matches gives the same result (rolls are seeded by the play situation).
	var results := []
	var strips := 0
	for trial in 2:
		for k in 12:
			var m := _match()
			var w := m.world
			_snap(w)
			var qb = w.find_role(0, R.QB)
			var lb = w.find_role(1, R.LB)
			_clear_field(w, [qb.id, lb.id])
			qb.position = Vector2(26, 40)
			qb.stamina = 1.0
			var inp := {qb.id: {"dir": Vector2(0, 1)}}   # jogging, not sprinting
			_run(w, 0.3 + k * DT, inp)
			lb.position = qb.position - Vector2(0, 1.2)
			lb.facing = Vector2(0, 1)
			w.tackle(lb.id)
			for i in 30:
				w.step(inp, DT)
				if events.has("fumble") or events.has("tackle"):
					break
			var fumbled := events.has("fumble")
			assert_true(fumbled or events.has("tackle"), "hit resolved: %s" % str(events))
			if trial == 0:
				results.append(fumbled)
				if fumbled:
					strips += 1
			else:
				assert_eq(fumbled, results[k], "deterministic replay %d" % k)
	assert_true(strips > 0, "a fresh jogging carrier hit from behind fumbles sometimes (%d/12)" % strips)
	assert_true(strips < 12, "...but not always (%d/12)" % strips)
