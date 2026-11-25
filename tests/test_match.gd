extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

func _match() -> Match:
	var w := World.new()
	var cx := w.field.width / 2.0
	var pairs := [[R.C, 0.0, R.DL, -1.5], [R.QB, 0.0, R.LB, 0.0], [R.WR, -18.0, R.CB, -18.0], [R.WR, 18.0, R.CB, 18.0], [R.RB, 4.0, R.S, -8.0], [R.OL, -2.5, R.DL, 1.5], [R.OL, 2.5, R.S, 8.0]]
	for t in 2:
		for p in pairs:
			w.add_two_way(t, p[0], cx + p[1], p[2], cx + p[3])
	var m := Match.new(w)
	m.start(0, 25.0)
	return m

func test_tackle_sets_next_los() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	for i in 30: w.step({}, DT)
	var qb := w.find_role(0, R.QB)
	qb.position.y = 31.0
	var lb := w.find_role(1, R.LB)
	lb.position = qb.position + Vector2(0, 0.95)
	lb.facing = Vector2(0, -1)
	w.tackle(lb.id)
	for i in 30: w.step({}, DT)
	assert_eq(w.phase, World.Phase.DEAD, "tackled")
	var out := m.next_play()
	assert_eq(out["outcome"], "next_down")
	assert_eq(w.phase, World.Phase.PRESNAP, "presnap")
	assert_near(w.los_y, m.downs.los, 0.001, "world LOS = downs LOS")
	assert_true(absf(m.downs.los - 31.0) < 1.0, "spot ~31 (got %f)" % m.downs.los)

func test_turnover_swaps_roles() -> void:
	var m := _match()
	var w := m.world
	for i in 4:
		w.snap()
		m.last_result = {"type": "incomplete"}
		m.next_play()
	assert_eq(w.offense_team, 1, "team 1 on offense")
	assert_true(w.find_role(1, R.QB) != null, "team 1 has a QB")
	assert_true(w.find_role(1, R.C) != null, "team 1 has a C")
	assert_true(w.find_role(0, R.QB) == null, "team 0 has no QB now")
	assert_true(w.ball.is_held_by(w.find_role(1, R.C).id), "team 1 C holds ball")
	assert_near(w.los_y, 75.0, 0.001, "mirrored LOS")

func test_ai_qb_throws() -> void:
	var m := _match()
	var w := m.world
	var ai := AI.new()
	ai.defense_enabled = false
	w.snap()
	var t := 0.0
	while t < 4.0 and not w.forward_pass_thrown:
		w.step(ai.think(w, []), DT)
		t += DT
	assert_true(w.forward_pass_thrown, "AI QB threw")
	assert_true(t <= 2.6, "within ~2.5s (t=%f)" % t)
