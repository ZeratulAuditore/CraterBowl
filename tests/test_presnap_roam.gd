extends "res://tests/test_case.gd"
## C08d: defense lines up stance-locked; Space (snap action) breaks stance for
## non-DL; neutral-zone clamp shared by host step and client prediction.

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const P := preload("res://src/net/protocol.gd")
const Predictor := preload("res://src/net/client_predictor.gd")
const T := preload("res://src/sim/tuning.gd")
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

func _run(w, inputs: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		w.step(inputs, DT)

func test_defense_lines_up_locked_offense_free() -> void:
	var w := _match().world
	for a in w.athletes:
		assert_eq(a.set_lock, a.team != w.offense_team, "athlete %d lock matches side" % a.id)

func test_locked_defender_holds_spot_but_turns() -> void:
	var w := _match().world
	var lb := w.find_role(1, R.LB)
	var start := lb.position
	_run(w, {lb.id: {"dir": Vector2(1, 0), "sprint": true}}, 1.0)
	assert_true(lb.position.distance_to(start) < 0.01, "locked LB didn't move")
	assert_near(lb.facing.x, 1.0, 0.001, "but faces the input")

func test_offense_still_moves_presnap() -> void:
	var w := _match().world
	var wr := w.find_role(0, R.WR)
	var start := wr.position
	_run(w, {wr.id: {"dir": Vector2(1, 0)}}, 1.0)
	assert_true(wr.position.x - start.x > 2.0, "offense unaffected by stance lock")

func test_break_stance_rules() -> void:
	var w := _match().world
	for role in [R.LB, R.CB, R.S]:
		var a := w.find_role(1, role)
		assert_true(w.break_stance(a.id), "%s can break stance" % role)
		assert_true(not a.set_lock, "unlocked")
		assert_true(not w.break_stance(a.id), "already unlocked -> false")
	var dl := w.find_role(1, R.DL)
	assert_true(not w.break_stance(dl.id), "DL holds stance")
	assert_true(dl.set_lock, "DL still locked")
	assert_true(not w.break_stance(w.find_role(0, R.WR).id), "offense can't break stance")

func test_break_stance_only_presnap() -> void:
	var m := _match()
	var w := m.world
	var cb := w.find_role(1, R.CB)
	assert_true(w.snap(), "snap")
	assert_true(not w.break_stance(cb.id), "no break_stance in LIVE")

func test_roaming_defender_moves_but_stops_at_line() -> void:
	var w := _match().world
	var lb := w.find_role(1, R.LB)
	w.break_stance(lb.id)
	var x0 := lb.position.x
	_run(w, {lb.id: {"dir": Vector2(1, 0)}}, 0.5)
	assert_true(lb.position.x - x0 > 1.0, "unlocked LB roams")
	for i in 120:
		w.step({lb.id: {"dir": Vector2(0, -1), "sprint": true}}, DT)
		assert_true(lb.position.y >= w.los_y + T.NEUTRAL_ZONE_HALF - 0.0001, "never past neutral zone")
	assert_near(lb.position.y, w.los_y + T.NEUTRAL_ZONE_HALF, 0.001, "pressed against the line")

func test_enforce_reports_contact() -> void:
	var w := _match().world
	var lb := w.find_role(1, R.LB)
	lb.position.y = w.los_y
	lb.velocity = Vector2(0, -3)
	assert_true(w.enforce_neutral_zone(lb), "pushing into the line is a contact")
	assert_true(not w.enforce_neutral_zone(lb), "standing at the line is not")

func test_snap_clears_and_next_play_relocks() -> void:
	var m := _match()
	var w := m.world
	w.snap()
	for a in w.athletes:
		assert_true(not a.set_lock, "LIVE: no locks")
	w.setup_formation(30.0)
	assert_true(w.find_role(1, R.CB).set_lock, "next play re-locks the defense")

func test_protocol_snap_routes_by_side() -> void:
	var m := _match()
	var w := m.world
	var s := w.find_role(1, R.S)
	assert_true(P.apply_action(m, s.id, {"a": "snap"}), "defense Space -> break stance")
	assert_eq(w.phase, World.Phase.PRESNAP, "ball not snapped")
	assert_true(not s.set_lock, "S roaming")
	assert_true(P.apply_action(m, w.find_role(0, R.QB).id, {"a": "snap"}), "offense Space -> snap")
	assert_eq(w.phase, World.Phase.LIVE, "snapped")

func test_snapshot_carries_lock() -> void:
	var a := _match()
	a.world.break_stance(a.world.find_role(1, R.CB).id)
	var b := _match()
	for ath in b.world.athletes:
		ath.set_lock = not ath.set_lock   # scramble so the decode must set it
	P.apply_snapshot(b, bytes_to_var(var_to_bytes(P.encode_snapshot(a, 1))))
	for i in a.world.athletes.size():
		assert_eq(b.world.athletes[i].set_lock, a.world.athletes[i].set_lock, "lock %d" % i)

func test_prediction_obeys_lock_and_clamp() -> void:
	var w := _match().world
	var lb := w.find_role(1, R.LB)
	var start := lb.position
	var pred := Predictor.new()
	for i in 30:
		pred.record(Vector2(0, -1), true, DT)
		w.predict_step(lb, Vector2(0, -1), true, DT)
	assert_true(lb.position.distance_to(start) < 0.01, "predicted locked LB stays put")
	w.break_stance(lb.id)
	for i in 120:
		pred.record(Vector2(0, -1), true, DT)
		w.predict_step(lb, Vector2(0, -1), true, DT)
	assert_true(lb.position.y >= w.los_y + T.NEUTRAL_ZONE_HALF - 0.0001, "prediction clamps")
	# Reconcile from an old authoritative spot: replays must clamp too.
	lb.position = start
	lb.velocity = Vector2.ZERO
	pred.reconcile(lb, 10, w)
	assert_true(lb.position.y >= w.los_y + T.NEUTRAL_ZONE_HALF - 0.0001, "reconcile replay clamps")
