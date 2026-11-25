extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")
const AI := preload("res://src/sim/ai.gd")
const Passing := preload("res://src/sim/passing.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 120.0
const R := Athlete.Role

var events: Array = []

func _match(chaos: bool = true) -> Match:
	events.clear()
	var w := World.new()
	Roster.new().build(w, 3)
	if chaos:
		w.set_ruleset("chaosball")
	var m := Match.new(w)
	m.start(0)
	w.event.connect(func(n, _d): events.append(n))
	return m

func _far(w, keep: Array) -> void:
	for a in w.athletes:
		if not keep.has(a.id):
			a.position = Vector2(1.0 + a.id * 0.3, 1.0 if a.team == 0 else 58.0)

func _run(w, s: float, inputs := {}) -> void:
	for i in int(round(s / DT)):
		w.step(inputs, DT)
		if w.phase == World.Phase.DEAD:
			return

func _crossing(w) -> Vector2:
	var prev: Vector3 = w.ball.position
	for i in 4000:
		w.step({}, DT)
		var p: Vector3 = w.ball.position
		if w.ball.velocity.z < 0 and p.z <= T.CATCH_HEIGHT and prev.z > T.CATCH_HEIGHT:
			return Vector2(p.x, p.y)
		prev = p
	return Vector2.INF

func test_low_gravity_still_hits_aim() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	_far(w, [qb.id])
	var target := qb.position + Vector2(5, 20)
	# Same launch velocity hangs longer under low gravity.
	var v0 := Vector3(0, 10, 6)
	var t_low := Passing.time_to_height(v0, T.RELEASE_HEIGHT, T.CATCH_HEIGHT, w.gravity())
	var t_norm := Passing.time_to_height(v0, T.RELEASE_HEIGHT, T.CATCH_HEIGHT)
	assert_true(t_low > t_norm * 1.5, "floatier (%.2f vs %.2f)" % [t_low, t_norm])
	w.throw(qb.id, target, 0.4)
	var hit := _crossing(w)
	assert_true(hit.distance_to(target) < 0.6, "aim exact in low gravity (%s)" % str(hit))

func test_throw_past_los_and_second_pass() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	var wr := w.find_role(0, R.WR)
	_far(w, [qb.id, wr.id])
	qb.position.y = w.los_y + 8.0
	wr.position = qb.position + Vector2(0, 10)
	assert_true(w.throw(qb.id, wr.position, 0.5), "throw past LOS")
	_run(w, 3.0)
	assert_true(w.ball.is_held_by(wr.id), "caught")
	qb.position = wr.position + Vector2(4, 8)
	assert_true(w.throw(wr.id, qb.position, 0.5), "second pass same play")

func test_self_catch() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	_far(w, [qb.id])
	var target := qb.position + Vector2(0, 8)
	assert_true(w.throw(qb.id, target, 0.3, true), "lob")
	for i in 1200:   # thrower runs under his own lob
		var to: Vector2 = target - qb.position
		w.step({qb.id: {"dir": to.normalized() if to.length() > 0.2 else Vector2.ZERO, "sprint": true}}, DT)
		if events.has("catch"):
			break
	assert_true(w.ball.is_held_by(qb.id), "caught own pass: %s" % str(events))

func test_bounces_then_incomplete() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	_far(w, [qb.id])
	w.throw(qb.id, qb.position + Vector2(3, 14), 0.4)
	_run(w, 12.0)
	assert_eq(events.count("bounce"), T.CHAOS_MAX_BOUNCES, "3 bounces: %s" % str(events))
	assert_true(events.has("incomplete"), "then incomplete")

func test_catch_after_a_bounce() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	var wr := w.find_role(0, R.WR)
	_far(w, [qb.id, wr.id])
	var target := qb.position + Vector2(0, 12)
	wr.position = target + Vector2(0, 30)   # far away at first
	w.throw(qb.id, target, 0.3)
	var bounced := false
	for i in 2400:
		if events.has("bounce") and not bounced:
			bounced = true
			wr.position = Vector2(w.ball.position.x, w.ball.position.y) + Vector2(w.ball.velocity.x, w.ball.velocity.y).normalized() * 3.0
		var bp := Vector2(w.ball.position.x, w.ball.position.y)
		w.step({wr.id: {"dir": (bp - wr.position).normalized() if bounced else Vector2.ZERO, "sprint": true}}, DT)
		if events.has("catch") or w.phase == World.Phase.DEAD:
			break
	assert_true(bounced and events.has("catch"), "caught off a bounce: %s" % str(events))

func test_wall_bounce_keeps_ball_in() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	_far(w, [qb.id])
	w.throw(qb.id, Vector2(w.field.width + 25.0, qb.position.y + 10.0), 1.0)
	var max_x := 0.0
	for i in 1200:
		w.step({}, DT)
		max_x = maxf(max_x, w.ball.position.x)
		if w.phase == World.Phase.DEAD:
			break
	assert_true(max_x <= w.field.width + 0.01, "never leaves the arena (max x %.2f)" % max_x)
	assert_true(events.has("bounce"), "hit the wall")

func test_opponent_catch_swings_possession() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	var cb := w.find_role(1, R.CB)
	_far(w, [qb.id, cb.id])
	cb.position = qb.position + Vector2(0, 12)
	w.throw(qb.id, cb.position, 0.4)
	_run(w, 3.0)
	assert_true(events.has("interception"), "picked")
	assert_eq(w.phase, World.Phase.LIVE, "still live")
	assert_eq(w.possession_team(), 1)

func test_match_turnovers_and_td() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	m.last_result = {"type": "incomplete", "team": 0, "spot": 20.0}
	w.phase = World.Phase.DEAD
	var out := m.next_play()
	assert_eq(out["outcome"], "turnover")
	assert_eq(w.offense_team, 1, "incomplete -> other team")
	assert_near(w.los_y, 40.0, 0.001, "mirrored (60 - 20)")
	w.snap()
	m.last_result = {"type": "touchdown", "team": 1}
	w.phase = World.Phase.DEAD
	out = m.next_play()
	assert_eq(m.score[1], 6)
	assert_eq(out["outcome"], "kickoff")
	assert_eq(w.offense_team, 0)

func test_classic_unchanged() -> void:
	var m := _match(false)
	assert_true(not m.world.is_chaos())
	assert_near(m.world.gravity(), T.GRAVITY)

func test_chaos_bot_game() -> void:
	var m := _match()
	var w := m.world
	var ai := AI.new()
	var plays := 0
	var longest := 0.0
	var play_t := 0.0
	var dead_t := 0.0
	for i in int(120.0 * 60):
		var dt := 1.0 / 60.0
		m.tick(dt)
		ai.presnap_tick(w, [], dt, m.downs.down, m.downs.distance())
		w.step(ai.think(w, []), dt)
		if w.phase == World.Phase.LIVE:
			play_t += dt
			longest = maxf(longest, play_t)
		elif w.phase == World.Phase.DEAD:
			dead_t += dt
			if dead_t > 0.5:
				m.next_play()
				plays += 1
				play_t = 0.0
				dead_t = 0.0
	assert_true(plays >= 8, "plays %d" % plays)
	assert_true(longest < 30.0, "no stuck play (%.1f s)" % longest)
	print("    chaos bots: %d plays, longest %.1fs, score %s, events: throws %d bounces %d swings %d" % [plays, longest, str(m.score), events.count("throw"), events.count("bounce"), events.count("interception")])
