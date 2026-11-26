extends "res://tests/test_case.gd"
## Player moves: spin (Q/E), carrier dive (F), POV throws, taunt emotes.

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Passing := preload("res://src/sim/passing.gd")
const Emotes := preload("res://src/sim/emotes.gd")
const P := preload("res://src/net/protocol.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0

var events: Array = []
var whistle := {}

func _setup(extra: Array) -> World:
	events.clear()
	whistle = {}
	var w := World.new()
	w.add_athlete(0, Athlete.Role.C, Vector2(26, 20))
	w.add_athlete(0, Athlete.Role.QB, Vector2(26, 15))
	for e in extra:
		w.add_athlete(e[0], e[1], e[2])
	w.setup_formation(25.0)
	for i in extra.size():
		w.athletes[2 + i].position = extra[i][2]
	w.event.connect(func(n, d):
		events.append(n)
		if n == "tackle": whistle = d)
	w.snap()
	_run(w, {}, 0.5)
	return w

func _run(w, inputs: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		w.step(inputs, DT)

func _qb(w) -> Athlete:
	return w.find_role(0, Athlete.Role.QB)

func test_spin_sidesteps_toward_its_side() -> void:
	var w := _setup([])
	var qb := _qb(w)
	var up := {qb.id: {"dir": Vector2(0, 1)}}
	_run(w, up, 0.5)
	var x0 := qb.position.x
	assert_true(w.spin(qb.id, 1), "spin right starts")
	assert_true(qb.is_spinning(), "spinning")
	_run(w, up, T.SPIN_TIME)
	assert_true(qb.position.x > x0 + 0.3, "drifted right (%.2f -> %.2f)" % [x0, qb.position.x])
	_run(w, up, 0.05)
	assert_true(not qb.is_spinning(), "spin ends")
	var x1 := qb.position.x
	assert_true(w.spin(qb.id, -1), "spin left with the second charge")
	_run(w, up, T.SPIN_TIME)
	assert_true(qb.position.x < x1, "spin left drifts left")

func test_spin_keeps_forward_momentum() -> void:
	var w := _setup([])
	var qb := _qb(w)
	var up := {qb.id: {"dir": Vector2(0, 1)}}
	_run(w, up, 0.6)
	var y0 := qb.position.y
	w.spin(qb.id, 1)
	_run(w, up, T.SPIN_TIME)
	assert_true(qb.position.y - y0 > T.RUN_SPEED * T.SPIN_TIME * 0.6, "kept moving downfield (%.2f)" % (qb.position.y - y0))

func test_spin_spends_move_charges() -> void:
	var w := _setup([])
	var qb := _qb(w)
	qb.move_charge = 2.0
	assert_true(not w.spin(qb.id, 0), "side 0 rejected")
	assert_true(w.spin(qb.id, 1), "first spin")
	assert_true(not w.spin(qb.id, -1), "can't start a spin mid-spin")
	_run(w, {}, T.SPIN_TIME + 0.05)
	assert_true(w.spin(qb.id, -1), "second spin")
	_run(w, {}, T.SPIN_TIME + 0.05)
	assert_true(not w.spin(qb.id, 1), "meter empty: no third spin until you run for it")

func test_spin_makes_dive_miss() -> void:
	var w := _setup([[1, Athlete.Role.LB, Vector2(26, 22)]])
	var lb: Athlete = w.athletes[2]
	var qb := _qb(w)
	lb.facing = Vector2(0, -1)
	assert_true(w.spin(qb.id, 1), "spin")
	assert_true(w.tackle(lb.id), "dive")
	_run(w, {}, T.SPIN_TIME * 0.9)
	assert_true(not events.has("tackle"), "spun out of the tackle: %s" % str(events))
	assert_eq(w.phase, World.Phase.LIVE, "play still live")

func test_dive_without_spin_still_tackles() -> void:
	var w := _setup([[1, Athlete.Role.LB, Vector2(26, 22)]])
	var lb: Athlete = w.athletes[2]
	lb.facing = Vector2(0, -1)
	w.tackle(lb.id)
	_run(w, {}, 0.4)
	assert_true(events.has("tackle"), "tackled")

func test_carrier_dive_gains_ground_then_is_down() -> void:
	var w := _setup([])
	var qb := _qb(w)
	qb.facing = Vector2(0, 1)
	var y0 := qb.position.y
	assert_true(w.tackle(qb.id), "carrier dives")
	_run(w, {}, T.DIVE_TIME + 0.1)
	assert_eq(w.phase, World.Phase.DEAD, "down where he landed")
	assert_true(whistle.get("dive", false), "whistle marks the dive")
	assert_eq(whistle.get("by", 0), -1, "no tackler credited")
	assert_true(whistle["spot"].y > y0 + T.DIVE_SPEED * T.DIVE_TIME * 0.8, "dove forward %.2f" % (whistle["spot"].y - y0))

func test_carrier_dive_into_endzone_scores() -> void:
	var w := _setup([])
	var qb := _qb(w)
	qb.position = Vector2(26, w.field.length - 1.5)
	qb.facing = Vector2(0, 1)
	w.tackle(qb.id)
	_run(w, {}, T.DIVE_TIME)
	assert_true(events.has("touchdown"), "dive across the goal line scores: %s" % str(events))

func test_pov_throw_direction_and_angle() -> void:
	var w := _setup([])
	var qb := _qb(w)
	var dir := Vector2(0.6, 0.8)
	assert_true(w.throw_dir(qb.id, dir, 20.0, 0.8), "pov throw accepted")
	var v := Vector2(w.ball.velocity.x, w.ball.velocity.y)
	assert_true(v.normalized().dot(dir) > 0.999, "flies where the view points")
	assert_near(rad_to_deg(atan2(w.ball.velocity.z, v.length())), 20.0, 0.5, "launch angle = view pitch")

func test_pov_more_power_and_better_angle_go_farther() -> void:
	var from := Vector3(0, 0, T.RELEASE_HEIGHT)
	var d := func(ang: float, p: float) -> float:
		var v := Passing.velocity_for(Vector2(0, 1), ang, p)
		return v.y * Passing.time_to_height(v, from.z, T.CATCH_HEIGHT)
	assert_true(d.call(20.0, 1.0) > d.call(20.0, 0.3) + 10.0, "power -> distance")
	assert_true(d.call(40.0, 1.0) > d.call(5.0, 1.0), "loft -> distance (below 45)")
	var hv := Passing.velocity_for(Vector2(0, 1), 60.0, 0.5)
	var lv := Passing.velocity_for(Vector2(0, 1), 10.0, 0.5)
	assert_true(hv.z > lv.z * 3.0, "looking up throws a higher arc")
	assert_near(rad_to_deg(atan2(Passing.velocity_for(Vector2(0, 1), 999.0, 1.0).z, 1.0)), rad_to_deg(atan2(Passing.velocity_for(Vector2(0, 1), T.POV_ANGLE_MAX, 1.0).z, 1.0)), 0.01, "angle clamped")

func test_pov_throw_blocked_past_los() -> void:
	var w := _setup([])
	var qb := _qb(w)
	qb.position.y = w.los_y + 3.0
	assert_true(not w.throw_dir(qb.id, Vector2(0, 1), 20.0, 0.5), "no forward pass past the LOS")
	assert_true(not w.throw_dir(qb.id, Vector2.ZERO, 20.0, 0.5) , "zero direction rejected")

func test_protocol_sanitizes_new_actions() -> void:
	var t := P.sanitize_action({"a": "throw", "d": Vector2(3, 4), "ang": 500.0, "p": 2.0})
	assert_near(t["d"].length(), 1.0, 0.001, "dir normalized")
	assert_eq(t["ang"], T.POV_ANGLE_MAX, "angle clamped")
	assert_eq(t["p"], 1.0, "power clamped")
	assert_eq(P.sanitize_action({"a": "throw", "d": Vector2(NAN, 1), "ang": 10.0, "p": 0.5}), {}, "nan dir")
	assert_eq(P.sanitize_action({"a": "throw", "d": Vector2.ZERO, "ang": 10.0, "p": 0.5}), {}, "zero dir")
	assert_eq(P.sanitize_action({"a": "spin", "s": 1}), {"a": "spin", "s": 1}, "spin right")
	assert_eq(P.sanitize_action({"a": "spin", "s": 3}), {}, "bad spin side")
	assert_eq(P.sanitize_action({"a": "emote", "e": "nope"}), {"a": "emote", "e": "nope"}, "emote ok")
	assert_eq(P.sanitize_action({"a": "emote", "e": "<script>"}), {}, "unknown emote")
	var legacy := P.sanitize_action({"a": "throw", "t": Vector2(20, 40), "p": 0.5})
	assert_eq(legacy["t"], Vector2(20, 40), "target throws still work (AI/bots)")

func test_emote_rate_limited_and_cosmetic() -> void:
	var w := _setup([])
	var qb := _qb(w)
	var pos := qb.position
	assert_true(w.emote(qb.id, "shimmy"), "emote")
	assert_true(events.has("emote"), "broadcast as an event")
	assert_true(not w.emote(qb.id, "nope"), "rate limited")
	assert_true(not w.emote(qb.id, "nonsense"), "unknown")
	assert_eq(qb.position, pos, "no gameplay effect")
	_run(w, {}, Emotes.COOLDOWN + 0.05)
	assert_true(w.emote(qb.id, "nope"), "again after the cooldown")
	assert_eq(Emotes.id_at(-1), Emotes.LIST[-1][0], "picker wraps")

func test_spin_flag_in_snapshot() -> void:
	var w := World.new()
	var cx := w.field.width / 2.0
	for t in 2:
		w.add_two_way(t, Athlete.Role.QB, cx, Athlete.Role.LB, cx)
		w.add_two_way(t, Athlete.Role.C, cx, Athlete.Role.DL, cx)
	var a := Match.new(w)
	a.start(0, 25.0)
	a.world.snap()
	_run(a.world, {}, 0.5)
	var qb: Athlete = a.world.find_role(0, Athlete.Role.QB)
	a.world.spin(qb.id, -1)
	var snap := P.encode_snapshot(a, 1)
	var b_w := World.new()
	for t in 2:
		b_w.add_two_way(t, Athlete.Role.QB, cx, Athlete.Role.LB, cx)
		b_w.add_two_way(t, Athlete.Role.C, cx, Athlete.Role.DL, cx)
	var b := Match.new(b_w)
	b.start(0, 25.0)
	P.apply_snapshot(b, snap)
	var bq: Athlete = b.world.get_athlete(qb.id)
	assert_true(bq.is_spinning() and bq.spin_dir == -1, "client sees the spin and its side")
