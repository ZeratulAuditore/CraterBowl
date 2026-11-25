extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0

var events: Array = []

func _setup(extra: Array) -> World:
	events.clear()
	var w := World.new()
	w.add_athlete(0, Athlete.Role.C, Vector2(26, 20))
	w.add_athlete(0, Athlete.Role.QB, Vector2(26, 15))
	for e in extra:
		w.add_athlete(e[0], e[1], e[2])
	w.setup_formation(25.0)
	for i in extra.size():
		w.athletes[2 + i].position = extra[i][2]
	w.event.connect(func(n, d): events.append(n))
	w.snap()
	return w

func _run(w, inputs: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		w.step(inputs, DT)

func test_bodies_separate() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(10, 30)], [1, Athlete.Role.CB, Vector2(10.2, 30)]])
	_run(w, {}, 0.1)
	assert_true(w.athletes[2].position.distance_to(w.athletes[3].position) >= 0.9 - 0.001, "separated")

func test_grounded_ignored() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(10, 30)], [1, Athlete.Role.CB, Vector2(10.2, 30)]])
	w.athletes[3].recover_t = 1.0
	_run(w, {}, 0.1)
	assert_true(w.athletes[2].position.distance_to(w.athletes[3].position) < 0.5, "no collision while grounded")

func test_ol_engages_and_slows_dl() -> void:
	# Free DL baseline
	var w1 := _setup([[1, Athlete.Role.DL, Vector2(40, 26)]])
	var free_dl: Athlete = w1.athletes[2]
	var y0 := free_dl.position.y
	_run(w1, {free_dl.id: {"dir": Vector2(0, -1), "sprint": true}}, 1.0)
	var free_gain := y0 - free_dl.position.y
	# Blocked DL
	var w2 := _setup([[0, Athlete.Role.OL, Vector2(40, 24.6)], [1, Athlete.Role.DL, Vector2(40, 25.5)]])
	var ol: Athlete = w2.athletes[2]
	var dl: Athlete = w2.athletes[3]
	ol.facing = Vector2(0, 1)
	var y1 := dl.position.y
	_run(w2, {dl.id: {"dir": Vector2(0, -1), "sprint": true}}, 1.0)
	assert_true(events.has("block"), "engaged")
	var blocked_gain := y1 - dl.position.y
	assert_true(blocked_gain < free_gain * 0.5, "blocked gain %f << free %f" % [blocked_gain, free_gain])

func test_block_sheds_then_immunity() -> void:
	var w := _setup([[0, Athlete.Role.OL, Vector2(40, 24.6)], [1, Athlete.Role.DL, Vector2(40, 25.5)]])
	var ol: Athlete = w.athletes[2]
	var dl: Athlete = w.athletes[3]
	ol.facing = Vector2(0, 1)
	_run(w, {}, 0.05)
	assert_eq(dl.engaged_with, ol.id, "engaged")
	_run(w, {}, T.BLOCK_HOLD)
	assert_true(events.has("shed"), "shed after hold")
	assert_true(dl.engaged_with < 0 or dl.engage_t < 0.2, "released")
	assert_true(dl.immune_t > 0.0 or dl.engaged_with < 0, "immune window")
	_run(w, {}, 0.05)
	assert_eq(dl.engaged_with, -1, "no instant re-engage")

func test_carrier_cannot_block() -> void:
	var w := _setup([[1, Athlete.Role.DL, Vector2(26, 20.8)]])
	_run(w, {}, 0.5)  # QB has ball at y=20, DL right in front
	var qb := w.find_role(0, Athlete.Role.QB)
	qb.facing = Vector2(0, 1)
	_run(w, {}, 0.1)
	assert_true(qb.engaged_with < 0, "carrier never engages")

func _time_to_sack(protect: bool) -> float:
	var extra := [[1, Athlete.Role.DL, Vector2(24.5, 25.5)], [1, Athlete.Role.DL, Vector2(27.5, 25.5)]]
	if protect:
		extra += [[0, Athlete.Role.OL, Vector2(23.5, 24.5)], [0, Athlete.Role.OL, Vector2(28.5, 24.5)]]
	var w := _setup(extra)
	if not protect:
		w.athletes.erase(w.find_role(0, Athlete.Role.C))  # no C either
		for i in w.athletes.size(): w.athletes[i].id = i
		w.ball.hold(w.find_role(0, Athlete.Role.QB).id)
	var ai := AI.new()
	var t := 0.0
	var qb := w.find_role(0, Athlete.Role.QB)
	while t < 10.0:
		w.step(ai.think(w, [qb.id]), DT)
		t += DT
		if events.has("tackle"):
			return t
	return t

func test_protection_delays_sack() -> void:
	var unprotected := _time_to_sack(false)
	var protected := _time_to_sack(true)
	assert_true(protected > unprotected + 0.75, "protected %f vs unprotected %f" % [protected, unprotected])

func test_beaten_blocker_cooldown() -> void:
	var w := _setup([[0, Athlete.Role.OL, Vector2(40, 24.6)], [1, Athlete.Role.DL, Vector2(40, 25.5)]])
	var ol: Athlete = w.athletes[2]
	ol.facing = Vector2(0, 1)
	_run(w, {}, T.BLOCK_HOLD + 0.1)
	assert_true(events.has("shed"), "shed")
	_run(w, {}, T.BLOCK_IMMUNITY + 0.1)  # defender immunity over, blocker still beaten
	assert_eq(ol.engaged_with, -1, "beaten blocker can't immediately re-engage")

func test_receivers_dont_block_during_pass_play() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(10, 24)], [1, Athlete.Role.CB, Vector2(10, 25.5)]])
	var wr: Athlete = w.athletes[2]
	_run(w, {wr.id: {"dir": Vector2(0, 1)}}, 0.6)  # QB holds ball behind LOS
	assert_eq(wr.engaged_with, -1, "WR on route doesn't engage")

func test_ai_route_runner_avoids_defender_in_lane() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(10, 24)], [1, Athlete.Role.CB, Vector2(10, 27)]])
	var ai := AI.new()
	ai.defense_enabled = false
	var wr: Athlete = w.athletes[2]
	for i in 120:
		w.step(ai.think(w, [w.find_role(0, Athlete.Role.QB).id]), DT)
	assert_true(wr.position.y > 32.0, "WR got past the CB (y=%f)" % wr.position.y)
