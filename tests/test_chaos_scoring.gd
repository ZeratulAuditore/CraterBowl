extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const P := preload("res://src/net/protocol.gd")
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

func _pass(w, from_a, to_a) -> void:
	w.throw(from_a.id, to_a.position, 0.4)
	for i in 600:
		w.step({}, DT)
		if not (w.ball.state == w.ball.State.IN_FLIGHT):
			break

func test_streak_counts_teammate_catches_only() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	var wr := w.find_role(0, R.WR)
	_far(w, [qb.id, wr.id])
	wr.position = qb.position + Vector2(0, 10)
	_pass(w, qb, wr)
	assert_eq(w.streak, 1, "teammate catch +1")
	qb.position = wr.position + Vector2(6, 6)
	_pass(w, wr, qb)
	assert_eq(w.streak, 2, "+1 again")
	# self-catch via lob doesn't count
	var target: Vector2 = qb.position + Vector2(0, 6)
	w.throw(qb.id, target, 0.3, true)
	for i in 1200:
		var to: Vector2 = target - qb.position
		w.step({qb.id: {"dir": to.normalized() if to.length() > 0.2 else Vector2.ZERO, "sprint": true}}, DT)
		if w.ball.is_held_by(qb.id):
			break
	assert_true(w.ball.is_held_by(qb.id), "self catch")
	assert_eq(w.streak, 2, "self-catch doesn't farm streak")

func test_interception_resets_streak() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	w.streak = 4
	var qb := w.find_role(0, R.QB)
	var cb := w.find_role(1, R.CB)
	_far(w, [qb.id, cb.id])
	cb.position = qb.position + Vector2(0, 10)
	_pass(w, qb, cb)
	assert_true(events.has("interception"))
	assert_eq(w.streak, 0)

func test_td_value() -> void:
	var m := _match()
	var w := m.world
	w.streak = 0
	assert_eq(w.streak_points(), 2)
	w.streak = 3
	assert_eq(w.streak_points(), 5)
	w.streak = 9
	assert_eq(w.streak_points(), 7, "cap 7")
	w.snap()
	w.streak = 3
	w.carrier().position = Vector2(15, 61)
	w.step({}, DT)
	m.next_play()
	assert_eq(m.score[0], 5, "TD worth the streak value")

func test_pass_clock_explodes_and_turns_over() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	_far(w, [qb.id])
	for i in int((T.PASS_CLOCK + 0.1) / DT):
		w.step({}, DT)
		if w.phase == World.Phase.DEAD:
			break
	assert_true(events.has("explode"), "exploded: %s" % str(events))
	assert_eq(w.phase, World.Phase.DEAD)
	var out := m.next_play()
	assert_eq(out["outcome"], "turnover")
	assert_eq(w.offense_team, 1, "other team gets it")

func test_catch_resets_pass_clock() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	var wr := w.find_role(0, R.WR)
	_far(w, [qb.id, wr.id])
	for i in int(3.5 / DT): w.step({}, DT)
	wr.position = qb.position + Vector2(0, 10)
	_pass(w, qb, wr)
	assert_true(w.hold_t < 1.5, "clock reset on catch (%.2f)" % w.hold_t)
	assert_true(not events.has("explode"))

func test_classic_never_explodes() -> void:
	var m := _match(false)
	var w := m.world
	w.snap()
	_far(w, [w.find_role(0, R.QB).id])
	for i in int(8.0 / DT): w.step({}, DT)
	assert_true(not events.has("explode"))

func test_ai_passes_before_clock() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	var qb := w.find_role(0, R.QB)
	var wr := w.find_role(0, R.WR)
	_far(w, [qb.id, wr.id])
	qb.position.y = w.los_y + 2.0   # past LOS: chaos carrier logic, no pressure anywhere
	wr.position = qb.position + Vector2(6, 8)
	var ai := AI.new()
	ai.defense_enabled = false
	for i in int((T.PASS_CLOCK + 0.5) * 60):
		w.step(ai.think(w, []), 1.0 / 60)
		if events.has("throw"):
			break
	assert_true(events.has("throw") and not events.has("explode"), "passed before the clock: %s" % str(events))

func test_snapshot_carries_streak() -> void:
	var a := _match()
	a.world.streak = 3
	a.world.hold_t = 2.5
	var b := _match()
	P.apply_snapshot(b, bytes_to_var(var_to_bytes(P.encode_snapshot(a, 1))))
	assert_eq(b.world.streak, 3)
	assert_near(b.world.hold_t, 2.5, 0.001)
