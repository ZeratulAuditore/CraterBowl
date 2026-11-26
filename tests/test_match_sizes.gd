extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const MatchConfig := preload("res://src/sim/match_config.gd")
const Downs := preload("res://src/sim/downs.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

func _match(size: int) -> Match:
	var w := World.new()
	Roster.new().build(w, size)
	var m := Match.new(w)
	m.start(0)
	return m

func test_configs() -> void:
	assert_eq(MatchConfig.get_config(3)["slots"], 3)
	assert_eq(MatchConfig.get_config(5)["slots"], 5)
	assert_eq(MatchConfig.get_config(7)["slots"], 7)
	assert_eq(MatchConfig.normalize(9), 7, "unknown -> 7")
	assert_near(MatchConfig.get_config(5)["length"], 80.0)

func test_3v3_roster() -> void:
	var m := _match(3)
	var w := m.world
	assert_eq(w.athletes.size(), 6, "3 per team")
	assert_true(w.find_role(0, R.C) == null, "no center")
	for a in w.athletes:
		assert_true(a.home_x > 0.5 and a.home_x < w.field.width - 0.5, "inside width (x=%.1f)" % a.home_x)
	assert_near(w.field.width, 30.0)

func test_no_center_snap() -> void:
	var m := _match(3)
	var w := m.world
	var qb := w.find_role(0, R.QB)
	assert_true(w.ball.is_held_by(qb.id), "QB holds presnap")
	assert_true(w.snap(), "snap")
	assert_eq(w.phase, World.Phase.LIVE)
	assert_true(w.ball.is_held_by(qb.id), "QB still holds")
	assert_true(not w.route_paths.is_empty(), "routes computed")

func test_downs_goal_80() -> void:
	var d := Downs.new()
	d.goal = 80.0
	d.reset(0, 60.0)
	assert_eq(d.label(), "1st & 10 at OPP 20")
	d.reset(0, 72.0)
	assert_true(d.is_goal_to_go(), "& goal")
	d.reset(0, 50.0)
	for i in 3: d.apply({"type": "incomplete"})
	d.apply({"type": "tackle", "spot": 52.0})
	assert_near(d.los, 28.0, 0.001, "mirrored 80 - 52")

func test_match_on_60_field() -> void:
	var m := _match(3)
	var w := m.world
	assert_near(w.los_y, 15.0, 0.001, "kickoff at 25% of 60")
	w.snap()
	w.carrier().position = Vector2(15, 61)
	w.step({}, DT)
	var out := m.next_play()
	assert_eq(out["outcome"], "try", "TD past 60")
	assert_near(w.los_y, 45.0, 0.001, "1-pt try: PAT kick from the 15")
	assert_eq(w.kick_play, "fg", "PAT is a kick")
	assert_true(m.choose_try(2))
	assert_near(w.los_y, 50.0, 0.001, "2-pt try from the 10")

func _bot_game(size: int) -> Dictionary:
	var m := _match(size)
	var w := m.world
	var ai := AI.new()
	var plays := 0
	var longest := 0.0
	var play_t := 0.0
	var dead_t := 0.0
	for i in int(120.0 / DT):
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
	return {"plays": plays, "longest": longest, "score": m.score}

func test_3v3_bot_game() -> void:
	var r := _bot_game(3)
	assert_true(r["plays"] >= 8, "plays %d" % r["plays"])
	assert_true(r["longest"] < 25.0, "longest %.1f" % r["longest"])
	print("    3v3 bots: %s" % str(r))

func test_5v5_bot_game() -> void:
	var r := _bot_game(5)
	assert_true(r["plays"] >= 8, "plays %d" % r["plays"])
	assert_true(r["longest"] < 25.0, "longest %.1f" % r["longest"])
	print("    5v5 bots: %s" % str(r))
