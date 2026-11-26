extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

func _match(los: float = 25.0) -> Match:
	var w := World.new()
	Roster.new().build(w)
	var m := Match.new(w)
	m.start(0, los)
	return m

func _far(w, keep: Array) -> void:
	for a in w.athletes:
		if not keep.has(a.id):
			a.position = Vector2(1.0 + a.id * 0.2, 2.0 if a.team == 0 else 98.0)

func test_ai_catcher_runs_upfield() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	for i in 30: w.step({}, DT)
	var wr := w.find_role(0, R.WR)
	_far(w, [wr.id])
	wr.position = Vector2(26, 40)
	w.ball.hold(wr.id)
	var ai := AI.new()
	var y0 := wr.position.y
	for i in 120:
		w.step(ai.think(w, []), DT)
	assert_true(wr.position.y > y0 + 10.0, "gained %.1f yd" % (wr.position.y - y0))

func test_carrier_protects_ball() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	for i in 30: w.step({}, DT)
	var wr := w.find_role(0, R.WR)
	var lb := w.find_role(1, R.LB)
	_far(w, [wr.id, lb.id])
	wr.position = Vector2(26, 40)
	lb.position = Vector2(26, 38.5)   # right behind
	w.ball.hold(wr.id)
	var ai := AI.new()
	var inp := ai.think(w, [lb.id])
	assert_true(not inp[wr.id]["sprint"], "no sprint with a defender close behind")

func test_man_coverage_sticks() -> void:
	var m := _match()
	var w := m.world
	w.call_play("Verticals")
	w.call_defense("cover_1")
	w.snap()
	var ai := AI.new()
	var qb := w.find_role(0, R.QB)
	for i in 5: w.step(ai.think(w, [qb.id]), DT)
	var wr = w.receivers_in_order()[0]
	var cb_id := -1
	for d in w.athletes:
		if ai.man_of(d.id) == wr.id:
			cb_id = d.id
	assert_true(cb_id >= 0, "WR has a man defender")
	for i in 120: w.step(ai.think(w, [qb.id]), DT)
	var gap: float = w.get_athlete(cb_id).position.distance_to(wr.position)
	# Designed trail distance (reaction lag + trail) plus slack: losing the man entirely fails.
	var bound: float = T.RUN_SPEED * T.AI_COVER_REACTION + T.AI_COVER_TRAIL + 2.5
	assert_true(gap < bound, "stays within %.1f yd (%.1f)" % [bound, gap])

func test_defender_breaks_on_ball() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	for i in 30: w.step({}, DT)
	var qb := w.find_role(0, R.QB)
	var ai := AI.new()
	ai.think(w, [qb.id])   # makes man assignments
	var s = null
	for d in w.athletes:
		if d.team == 1 and d.role == R.S and ai.man_of(d.id) < 0:
			s = d   # unassigned (deep) safety: should break on the ball
	assert_true(s != null, "have an unassigned safety")
	_far(w, [qb.id, s.id])
	s.position = Vector2(30, 45)
	var target := Vector2(40, 50)
	w.throw(qb.id, target, 0.9)
	var d0: float = s.position.distance_to(target)
	for i in 30: w.step(ai.think(w, [qb.id]), DT)
	assert_true(s.position.distance_to(target) < d0 - 2.0, "safety broke on the ball")

func test_choose_play() -> void:
	for v in 6:
		assert_true(AI.choose_play(3, 15.0, v) in ["Deep Shot", "Verticals", "Flood"], "long -> downfield")
		assert_true(AI.choose_play(2, 2.0, v) in ["Slants", "Curls", "Mesh"], "short -> quick game")
	var seen := {}
	for v in 6:
		seen[AI.choose_play(1, 10.0, v)] = true
	assert_true(seen.size() >= 3, "varies across calls (%d distinct)" % seen.size())

func test_ai_offense_calls_and_snaps() -> void:
	var m := _match()
	var w := m.world
	var ai := AI.new()
	w.play_name = "?"
	for i in 200:
		ai.presnap_tick(w, [], DT, 3, 15.0)
		if w.phase == World.Phase.LIVE:
			break
	assert_true(w.play_name in ["Deep Shot", "Verticals", "Flood"], "called a play (%s)" % w.play_name)
	assert_eq(w.phase, World.Phase.LIVE, "snapped")

func test_full_bot_game() -> void:
	var m := _match()
	var w := m.world
	var ai := AI.new()
	var plays := 0
	var longest := 0.0
	var play_t := 0.0
	var dead_t := 0.0
	var start_label := m.downs.label()
	var ev := {}
	w.event.connect(func(n, _d): ev[n] = ev.get(n, 0) + 1)
	for i in int(240.0 / DT):
		m.tick(DT)
		ai.presnap_tick(w, [], DT, m.downs.down, m.downs.distance())
		w.step(ai.think(w, []), DT)
		if w.phase == World.Phase.LIVE:
			play_t += DT
			longest = maxf(longest, play_t)
		elif w.phase == World.Phase.DEAD:
			dead_t += DT
			if dead_t > 0.5:
				m.next_play()
				plays += 1
				play_t = 0.0
				dead_t = 0.0
				if m.is_final():
					break
	assert_true(plays >= 8, "plays completed: %d" % plays)
	assert_true(longest < 25.0, "no stuck play (longest %.1f s)" % longest)
	assert_true(m.downs.label() != start_label or m.score != [0, 0], "game progressed")
	var throws: int = ev.get("throw", 0)
	var comp: float = 100.0 * ev.get("catch", 0) / maxf(1, throws)
	assert_true(throws >= 8, "bots pass (%d throws)" % throws)
	assert_true(comp >= 40.0 and comp <= 95.0, "completion %% in a sane range (%.0f)" % comp)
	assert_true(ev.get("fumble", 0) <= maxi(1, ev.get("catch", 0) / 5), "fumbles rare (%d)" % ev.get("fumble", 0))
	assert_true(ev.get("breakup", 0) + ev.get("incomplete", 0) >= 1, "defense makes some plays")
	print("    bot game: %d plays, longest %.1fs, score %s, %s, comp %.0f%%, %s" % [plays, longest, str(m.score), m.downs.label(), comp, str(ev)])

func test_press_defender_does_not_walk_through_receiver() -> void:
	# Regression: trail spot put the CB behind an unreleased WR -> CB shoved the WR backwards.
	var m := _match()
	var w := m.world
	w.snap()
	var ai := AI.new()
	var qb := w.find_role(0, R.QB)
	var wr = w.receivers_in_order()[0]
	var y0: float = wr.position.y
	for i in 60:
		var inp := ai.think(w, [qb.id, wr.id])
		inp[wr.id] = {"dir": Vector2.ZERO, "sprint": false}   # receiver stands still at the line
		w.step(inp, DT)
	assert_true(wr.position.y > y0 - 0.3, "WR not shoved backwards (dy %.2f)" % (wr.position.y - y0))
