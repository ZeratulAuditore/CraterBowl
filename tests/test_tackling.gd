extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0

var events: Array = []

## C, QB (holds ball after snap), plus extras placed at given positions after formation.
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
	_run(w, {}, 0.5)
	return w

func _run(w, inputs: Dictionary, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		w.step(inputs, DT)

func _qb(w) -> Athlete:
	return w.find_role(0, Athlete.Role.QB)

func test_dive_tackles_carrier() -> void:
	var w := _setup([[1, Athlete.Role.LB, Vector2(26, 22)]])  # QB at y=20
	var lb: Athlete = w.athletes[2]
	lb.facing = Vector2(0, -1)
	assert_true(w.tackle(lb.id), "dive started")
	_run(w, {}, 0.4)
	assert_true(events.has("tackle"), "tackle: %s" % str(events))
	assert_eq(w.phase, World.Phase.DEAD, "dead")
	assert_true(w.dead_ball_spot.distance_to(_qb(w).position) < 0.01, "spot at carrier")

func test_missed_dive_grounds_defender() -> void:
	var w := _setup([[1, Athlete.Role.LB, Vector2(40, 22)]])
	var lb: Athlete = w.athletes[2]
	lb.facing = Vector2(1, 0)  # dive away
	w.tackle(lb.id)
	_run(w, {}, 0.4)
	assert_true(not events.has("tackle"), "no tackle")
	assert_true(lb.is_grounded(), "on the ground")
	_run(w, {}, 0.3)  # let dive momentum slide out
	var p := lb.position
	_run(w, {lb.id: {"dir": Vector2(-1, 0)}}, 0.5)  # still within 1.0s recovery
	assert_true(lb.position.distance_to(p) < 0.05, "input ignored while grounded")
	_run(w, {lb.id: {"dir": Vector2(-1, 0)}}, 1.0)
	assert_true(lb.position.x < p.x - 1.0, "recovers and moves")

func test_offense_cannot_tackle() -> void:
	var w := _setup([[0, Athlete.Role.WR, Vector2(26, 21)]])
	var wr: Athlete = w.athletes[2]
	wr.facing = Vector2(0, -1)
	w.tackle(wr.id)
	_run(w, {}, 0.4)
	assert_true(not events.has("tackle"), "teammate dive is not a tackle")

func test_no_redive_while_diving_or_grounded() -> void:
	var w := _setup([[1, Athlete.Role.LB, Vector2(45, 22)]])
	var lb: Athlete = w.athletes[2]
	lb.facing = Vector2(1, 0)
	assert_true(w.tackle(lb.id))
	assert_true(not w.tackle(lb.id), "no re-dive while diving")
	_run(w, {}, 0.4)
	assert_true(not w.tackle(lb.id), "no dive while grounded")

func test_carrier_out_of_bounds() -> void:
	var w := _setup([])
	var qb := _qb(w)
	_run(w, {qb.id: {"dir": Vector2(-1, 0), "sprint": true}}, 4.0)
	assert_true(events.has("out_of_bounds"), "oob: %s" % str(events))
	assert_eq(w.phase, World.Phase.DEAD, "dead")

func test_sack_behind_los() -> void:
	var w := _setup([[1, Athlete.Role.DL, Vector2(26, 21.5)]])
	var dl: Athlete = w.athletes[2]
	dl.facing = Vector2(0, -1)
	w.tackle(dl.id)
	_run(w, {}, 0.4)
	assert_true(events.has("tackle"), "sack")
	assert_true(w.dead_ball_spot.y < w.los_y, "behind LOS")

func test_ai_pursues_and_tackles() -> void:
	var w := _setup([[1, Athlete.Role.LB, Vector2(10, 40)]])
	var ai := AI.new()
	var qb := _qb(w)
	for i in 600:
		w.step(ai.think(w, [qb.id]), DT)
		if w.phase == World.Phase.DEAD:
			break
	assert_true(events.has("tackle"), "AI tackled: %s" % str(events))
