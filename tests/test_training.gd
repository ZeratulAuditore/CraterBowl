extends "res://tests/test_case.gd"
## Training ground + stations (blocking / catching / practice field / hub portals).

const World := preload("res://src/sim/world.gd")
const Drills := preload("res://src/sim/drills.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const MatchConfig := preload("res://src/sim/match_config.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

func _drill(kind: String) -> Array:
	var w := World.new()
	MatchConfig.apply_field(w.field, 7)
	var d := Drills.new()
	d.build(w, kind)
	w.event.connect(d.on_event)
	d.start_rep(w)
	return [w, d]

## Run one rep with `policy(world, drill) -> input` for the human. Returns true if reset requested.
func _run(w: World, d: Drills, ai: AI, policy: Callable, max_frames: int = 900) -> bool:
	for i in max_frames:
		var inputs := ai.think(w, [d.me])
		d.override_inputs(w, inputs)
		inputs[d.me] = policy.call(w, d)
		w.step(inputs, DT)
		if d.tick(w, DT):
			return true
	return false

func _idle(_w, _d) -> Dictionary:
	return {"dir": Vector2.ZERO, "sprint": false}

func test_kinds_and_stations() -> void:
	for k in ["hub", "blocking", "catching", "field"]:
		assert_true(Drills.valid(k), k)
		assert_true(Drills.is_training(k), k)
	assert_true(not Drills.is_training("passing"))
	assert_eq(Drills.STATIONS.size(), 3, "three portals")

func test_blocking_build() -> void:
	var r := _drill("blocking")
	var w: World = r[0]
	var d: Drills = r[1]
	assert_eq(w.get_athlete(d.me).role, R.C, "you are the center")
	assert_true(w.find_role(0, R.QB) != null, "bot QB")
	assert_eq(w.phase, World.Phase.PRESNAP)
	assert_true(w.ball.is_held_by(d.me), "center has the ball")
	var active := 0
	for a in w.athletes:
		if a.team == 1 and absf(a.position.y - Drills.LOS) < 2.0:
			active += 1
	assert_eq(active, 1, "level 1: one rusher on the line, the rest benched")

func test_blocking_autosnap_and_sack_when_idle() -> void:
	var r := _drill("blocking")
	var w: World = r[0]
	var d: Drills = r[1]
	var ai := AI.new()
	var bench_pos: Vector2 = w.get_athlete(d._rushers[2]).position
	assert_true(_run(w, d, ai, _idle), "rep ends")
	assert_true(w.phase != World.Phase.PRESNAP, "auto-snapped")
	assert_eq(d.sacks, 1, "an idle center gives up the sack")
	assert_eq(d.successes, 0)
	assert_true(w.get_athlete(d._rushers[2]).position.distance_to(bench_pos) < 0.01, "benched rusher stays put")
	assert_true(not d.banners.is_empty() and d.banners[-1][0] == "SACKED", "sack banner")

func test_blocking_protect_keeps_pocket_clean() -> void:
	var r := _drill("blocking")
	var w: World = r[0]
	var d: Drills = r[1]
	var ai := AI.new()
	var protect := func(wo, dr):
		return ai._protect(wo, wo.get_athlete(dr.me), wo.get_athlete(dr._qb))
	var clean := 0
	for rep in 3:
		assert_true(_run(w, d, ai, protect), "rep %d ends" % rep)
		clean += 1 if d.last_result == "CLEAN POCKET" else 0
		d.start_rep(w)
	assert_true(clean >= 2, "a good blocker wins level 1 (%d/3 clean)" % clean)
	assert_true(d.blocks_made >= 2, "blocks counted (%d)" % d.blocks_made)

func test_levels_up_and_down() -> void:
	var r := _drill("blocking")
	var d: Drills = r[1]
	for i in 3:
		d.rep_over = false
		d.on_event("pocket_clean", {})
	assert_eq(d.level, 2, "3 clean reps -> level 2")
	assert_eq(d.banners.filter(func(b): return b[0] == "LEVEL 2").size(), 1, "level-up banner")
	d.rep_over = false
	d.on_event("tackle", {})
	assert_eq(d.level, 1, "a sack drops a level")
	assert_eq(d.streak, 0)

func test_blocking_level_lines_up_more() -> void:
	var r := _drill("blocking")
	var w: World = r[0]
	var d: Drills = r[1]
	d.level = 3
	d.start_rep(w)
	var rush := 0
	var block := 0
	for a in w.athletes:
		if absf(a.position.y - Drills.LOS) < 2.0 and a.position.x < w.field.width - 2.0:
			if a.team == 1:
				rush += 1
			elif a.role == R.OL:
				block += 1
	assert_eq(rush, 3, "level 3: three rushers")
	assert_eq(block, 2, "level 3: two bot linemates")

func test_catching_routes_and_cushion() -> void:
	var r := _drill("catching")
	var w: World = r[0]
	var d: Drills = r[1]
	assert_eq(w.route_of.get(d.me, ""), Drills.CATCH_ROUTES[0], "first route")
	var cb := w.find_role(1, R.CB)
	assert_near(cb.position.y - Drills.LOS, Drills.CB_CUSHION[0], 0.01)
	d.level = 3
	d.start_rep(w)
	assert_eq(w.route_of.get(d.me, ""), Drills.CATCH_ROUTES[1], "route rotates")
	assert_near(cb.position.y - Drills.LOS, Drills.CB_CUSHION[2], 0.01, )
	for i in int(Drills.SNAP_DELAY / DT) + 2:
		d.tick(w, DT)
	assert_eq(w.phase, World.Phase.LIVE, "auto-snap")

func test_catching_race_records_best() -> void:
	var r := _drill("catching")
	var d: Drills = r[1]
	for i in Drills.CATCH_RACE:
		d.rep_over = false
		d.session_t += 4.0
		d.on_event("catch", {"by": d.me})
	assert_eq(d.race_done, 1)
	assert_near(float(d.bests["catch_race_time"]), 60.0, 0.01)
	assert_near(d.session_t, 0.0, 0.001, "race clock resets")
	d.rep_over = false
	d.on_event("interception", {})
	assert_eq(d.last_result, "PICKED OFF")

func test_field_targets_score() -> void:
	var r := _drill("field")
	var w: World = r[0]
	var d: Drills = r[1]
	assert_eq(w.phase, World.Phase.LIVE, "ball live in your hands")
	assert_true(w.ball.is_held_by(d.me))
	var ts := Drills.target_list(w.field)
	d.on_event("throw", {})
	d.on_event("incomplete", {"at": ts[2]["pos"]})
	assert_eq(d.points, 4, "deep bullseye = 3 + 1")
	d.on_event("throw", {})
	d.on_event("incomplete", {"at": ts[0]["pos"] + Vector2(2.5, 0)})
	assert_eq(d.points, 5, "short ring edge = 1")
	d.on_event("throw", {})
	d.on_event("incomplete", {"at": Vector2(1, 1)})
	assert_eq(d.last_result, "MISS")
	assert_eq(d.hits, 2)
	assert_eq(d.throws, 3)

func test_field_real_throw_respawns_ball() -> void:
	var r := _drill("field")
	var w: World = r[0]
	var d: Drills = r[1]
	var t: Vector2 = Drills.target_list(w.field)[0]["pos"]
	var a := w.get_athlete(d.me)
	a.position = t - Vector2(0, 10)
	assert_true(w.throw(d.me, t, 0.6), "throw allowed from anywhere")
	var respawned := false
	for i in 400:
		w.step({}, DT)
		d.tick(w, DT)
		if d.throws == 1 and w.ball.is_held_by(d.me) and w.phase == World.Phase.LIVE:
			respawned = true
			break
	assert_true(respawned, "ball back in your hands")
	assert_true(d.hits == 1, "the real throw hit the short target (%s)" % d.last_result)

func test_dash_timer() -> void:
	var r := _drill("field")
	var w: World = r[0]
	var d: Drills = r[1]
	var lane := Drills.dash_lane(w.field)
	var a := w.get_athlete(d.me)
	a.position = Vector2(lane["x"], lane["start"] - 3.0)
	var frames := 0
	while frames < 1200 and d.dash_last < 0.0:
		w.step({d.me: {"dir": Vector2(0, 1), "sprint": true}}, DT)
		d.tick(w, DT)
		frames += 1
	assert_true(d.dash_last > 3.0 and d.dash_last < 8.0, "40 yd time %.2f" % d.dash_last)
	assert_near(float(d.bests["dash_40"]), d.dash_last, 0.001)
	# Leaving the lane cancels a run.
	a.position = Vector2(lane["x"], lane["start"] - 1.0)
	d._prev = a.position
	for i in 30:
		w.step({d.me: {"dir": Vector2(0, 1), "sprint": true}}, DT)
		d.tick(w, DT)
	assert_true(d.dash_t >= 0.0, "running")
	a.position.x -= 10.0
	d.tick(w, DT)
	assert_true(d.dash_t < 0.0, "left the lane: cancelled")

func test_hub_portals() -> void:
	var r := _drill("hub")
	var w: World = r[0]
	var d: Drills = r[1]
	assert_eq(w.athletes.size(), 1)
	assert_eq(w.phase, World.Phase.LIVE, "free roam")
	d.tick(w, DT)
	assert_eq(d.portal, "", "spawn is clear of portals")
	var ps := Drills.portal_positions(w.field)
	for i in ps.size():
		w.get_athlete(d.me).position = ps[i]
		d.portal = ""
		d.tick(w, DT)
		assert_eq(d.portal, Drills.STATIONS[i], "portal %d" % i)

func test_station_exit_portal() -> void:
	var r := _drill("field")
	var w: World = r[0]
	var d: Drills = r[1]
	w.get_athlete(d.me).position = Drills.EXIT_PORTAL
	d.tick(w, DT)
	assert_eq(d.portal, "hub", "exit portal returns to the training ground")

func test_bests_persist() -> void:
	var path := "user://test_training_bests.json"
	var d := Drills.new()
	d.load_bests(path)
	d.bests = {}
	d.bests["dash_40"] = 4.5
	d.save_bests()
	var d2 := Drills.new()
	d2.load_bests(path)
	assert_near(float(d2.bests["dash_40"]), 4.5, 0.001)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
