extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Clock := preload("res://src/sim/clock.gd")
const Protocol := preload("res://src/net/protocol.gd")
const Roster := preload("res://src/sim/roster.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

var mevents: Array = []

func _match(los: float = 25.0) -> Match:
	mevents.clear()
	var w := World.new()
	var cx := w.field.width / 2.0
	var pairs := [[R.C, 0.0, R.DL, -1.5], [R.QB, 0.0, R.LB, 0.0], [R.WR, -18.0, R.CB, -18.0], [R.WR, 18.0, R.CB, 18.0], [R.RB, 4.0, R.S, -8.0], [R.OL, -2.5, R.DL, 1.5], [R.OL, 2.5, R.S, 8.0]]
	for t in 2:
		for p in pairs:
			w.add_two_way(t, p[0], cx + p[1], p[2], cx + p[3])
	var m := Match.new(w)
	m.start(0, los)
	m.match_event.connect(func(n, _d): mevents.append(n))
	return m

## Resolve a pending kickoff as a touchback: receiving team's ball at its 25.
func _touchback(m) -> void:
	assert_eq(m.state, m.State.KICKOFF)
	m.world.kicked = true
	m.world.phase = World.Phase.DEAD
	m.last_result = {"type": "touchback", "spot": 105.0, "team": m.world.offense_team}
	m.next_play()
	assert_eq(m.state, m.State.SCRIMMAGE)

func _tick(m, seconds: float, inputs := {}) -> void:
	for i in int(round(seconds / DT)):
		m.tick(DT)
		m.world.step(inputs, DT)

func test_game_clock_runs_only_live() -> void:
	var m := _match()
	_tick(m, 2.0)  # presnap
	assert_near(m.clock.remaining, Clock.HALF_LENGTH, 0.001, "no game clock presnap")
	assert_true(m.clock.play_clock < Clock.PLAY_CLOCK, "play clock runs presnap")
	m.world.snap()
	_tick(m, 1.0)
	assert_near(m.clock.remaining, Clock.HALF_LENGTH - 1.0, 0.05, "game clock live")

func test_play_clock_auto_snaps() -> void:
	var m := _match()
	_tick(m, Clock.PLAY_CLOCK + 0.1)
	assert_true(mevents.has("auto_snap"), "auto snap")
	assert_eq(m.world.phase, World.Phase.LIVE, "live")

func test_play_clock_resets_each_play() -> void:
	var m := _match()
	_tick(m, 5.0)
	m.world.snap()
	m.last_result = {"type": "incomplete"}
	m.world.phase = World.Phase.DEAD
	m.next_play()
	assert_near(m.clock.play_clock, Clock.PLAY_CLOCK, 0.001, "reset")

func test_untimed_down_and_halftime() -> void:
	var m := _match()
	m.clock.remaining = 0.5
	m.world.snap()
	_tick(m, 1.0)
	assert_true(m.clock.expired(), "clock out")
	assert_eq(m.world.phase, World.Phase.LIVE, "play continues at 0:00")
	m.last_result = {"type": "incomplete"}
	m.world.phase = World.Phase.DEAD
	var out := m.next_play()
	assert_eq(out["outcome"], "halftime")
	assert_eq(m.clock.half, 2)
	assert_near(m.clock.remaining, Clock.HALF_LENGTH)
	# Opening receiver was team 0, so team 0 kicks off to team 1 from its 35.
	assert_eq(m.state, m.State.KICKOFF, "2nd half opens with a kickoff")
	assert_eq(out["receiving"], 1, "other team receives 2nd half")
	assert_eq(m.world.offense_team, 0, "team 0 kicks")
	assert_near(m.world.los_y, 35.0)

func test_final_and_winner() -> void:
	var m := _match()
	m.clock.half = 2
	m.clock.remaining = 0.0
	m.score = [14, 7]
	m.last_result = {"type": "incomplete"}
	var out := m.next_play()
	assert_eq(out["outcome"], "final")
	assert_true(m.is_final(), "final")
	assert_eq(m.winner(), 0)
	assert_eq(m.next_play()["outcome"], "final", "no-op after final")
	assert_true(mevents.has("final"))

func test_try_after_last_second_td() -> void:
	var m := _match(95.0)
	m.clock.half = 2
	m.clock.remaining = 0.0
	m.last_result = {"type": "touchdown"}
	var out := m.next_play()
	assert_eq(out["outcome"], "try", "try still played at 0:00")
	m.last_result = {"type": "touchdown"}
	out = m.next_play()
	assert_eq(out["outcome"], "final", "then final")
	assert_eq(m.score[0], 7)

func _snap_with_holder(m: Match) -> Athlete:
	m.world.snap()
	_tick(m, 0.5)
	return m.world.carrier()

func _end_tackle(m: Match, spot_y: float, team: int = 0) -> void:
	var carrier := m.world.carrier()
	carrier.position.y = spot_y
	m.world._whistle("tackle", {"carrier": carrier.id, "team": team})

func test_clock_continues_across_short_tackle_and_next_presnap() -> void:
	var m := _match()
	_snap_with_holder(m)
	_end_tackle(m, 28.0)
	var at_whistle := m.clock.remaining
	_tick(m, 1.0)
	assert_near(m.clock.remaining, at_whistle - 1.0, 0.001, "running between whistle and lineup")
	assert_eq(m.next_play()["outcome"], "next_down")
	_tick(m, 1.0)
	assert_near(m.clock.remaining, at_whistle - 2.0, 0.001, "running in presnap")

func test_dead_ball_results_that_stop_game_clock() -> void:
	for outcome in ["incomplete", "out_of_bounds", "touchdown", "safety", "first_down", "takeaway", "turnover_on_downs"]:
		var m := _match()
		if outcome == "turnover_on_downs":
			m.downs.down = 4
		var carrier := _snap_with_holder(m)
		match outcome:
			"incomplete":
				m.world._end_incomplete("ground", {})
			"out_of_bounds", "touchdown":
				m.world._whistle(outcome, {"carrier": carrier.id, "team": 0})
			"safety": _end_tackle(m, -1.0)
			"first_down": _end_tackle(m, 35.0)
			"takeaway": _end_tackle(m, 28.0, 1)
			"turnover_on_downs": _end_tackle(m, 28.0)
		var at_whistle := m.clock.remaining
		_tick(m, 1.0)
		assert_near(m.clock.remaining, at_whistle, 0.001, "%s stops the clock when dead" % outcome)
		m.next_play()
		_tick(m, 1.0)
		assert_near(m.clock.remaining, at_whistle, 0.001, "%s keeps the clock stopped before next snap" % outcome)
		if outcome == "touchdown":
			_snap_with_holder(m)
			assert_near(m.clock.remaining, at_whistle, 0.001, "the try is untimed")

func test_possession_change_midplay_stops_clock_even_if_offense_recovers() -> void:
	var m := _match()
	_snap_with_holder(m)
	m.world.event.emit("recovery", {"turnover": true})
	_end_tackle(m, 28.0)
	assert_true(not m.clock.running_between_plays)

func test_warning_waits_for_whistle_and_resets_at_halftime() -> void:
	var m := _match()
	_snap_with_holder(m)
	m.clock.remaining = 60.1
	_tick(m, 0.25)
	assert_true(not mevents.has("clock_warning"), "live play continues after 1:00")
	_end_tackle(m, 28.0)
	m.tick(DT)
	assert_eq(mevents.count("clock_warning"), 1)
	var at_warning := m.clock.remaining
	_tick(m, 1.0)
	assert_near(m.clock.remaining, at_warning, 0.001, "warning stopped the clock")
	m.next_play()
	_snap_with_holder(m)
	_end_tackle(m, 30.0)
	m.tick(DT)
	assert_eq(mevents.count("clock_warning"), 1, "only one warning per half")
	m.clock.remaining = 0.0
	m.next_play()
	assert_eq(m.clock.half, 2)
	_touchback(m)   # 2nd half opens with a kickoff (B09)
	_snap_with_holder(m)
	m.clock.remaining = 60.1
	_tick(m, 0.25)
	_end_tackle(m, 28.0, 1)
	m.tick(DT)
	assert_eq(mevents.count("clock_warning"), 2, "second half has its own warning")

func test_running_presnap_stops_at_warning_and_can_expire_after_warning() -> void:
	var m := _match()
	_snap_with_holder(m)
	m.clock.remaining = 60.1
	_end_tackle(m, 28.0)
	m.next_play()
	m.tick(0.25)
	assert_eq(mevents.count("clock_warning"), 1)
	assert_near(m.clock.remaining, 60.0, 0.001)
	assert_near(m.clock.play_clock, Clock.PLAY_CLOCK)
	_snap_with_holder(m)
	_end_tackle(m, 30.0)
	m.next_play()
	m.clock.remaining = 0.25
	m.clock.play_clock = 0.1
	m.tick(0.3)
	assert_true(not mevents.has("auto_snap"), "half expiry takes precedence over the play clock")
	assert_eq(m.last_outcome["outcome"], "halftime")
	assert_eq(m.clock.half, 2)
	assert_eq(m.world.phase, World.Phase.PRESNAP)
	assert_eq(m.state, m.State.KICKOFF, "2nd half opens with a kickoff")
	assert_eq(m.last_outcome["receiving"], 1)

func test_timeouts_stop_clock_use_actor_team_and_reset_at_half() -> void:
	var m := _match()
	_snap_with_holder(m)
	var defender := m.world.find_role(1, R.CB)
	assert_true(not Protocol.apply_action(m, defender.id, {"a": "timeout"}), "live request rejected")
	assert_eq(m.clock.timeouts, [3, 3])
	_end_tackle(m, 28.0)
	assert_true(Protocol.apply_action(m, defender.id, {"a": "timeout", "team": 0}), "any slot can call timeout for their own team")
	assert_eq(m.clock.timeouts, [3, 2])
	var remaining := m.clock.remaining
	_tick(m, 1.0)
	assert_near(m.clock.remaining, remaining, 0.001)
	m.next_play()
	_tick(m, 1.0)
	assert_true(m.call_timeout(1))
	assert_near(m.clock.play_clock, Clock.PLAY_CLOCK, 0.001, "timeout resets presnap countdown")
	assert_true(m.call_timeout(1))
	assert_true(not m.call_timeout(1), "spent timeouts cannot be reused")
	assert_true(not m.call_timeout(-1), "invalid team rejected")
	assert_eq(mevents.count("timeout"), 3)
	m.clock.remaining = 0.0
	m.next_play()
	assert_eq(m.clock.timeouts, [3, 3])

func test_3v3_has_two_timeouts_and_snapshot_carries_counts() -> void:
	var w := World.new()
	Roster.new().build(w, 3)
	var m := Match.new(w)
	m.start()
	assert_eq(m.clock.timeouts, [2, 2])
	assert_true(m.call_timeout(0))
	assert_eq(m.clock.timeouts, [1, 2])
	assert_eq(Protocol.encode_snapshot(m, 10)["to"], PackedInt32Array([1, 2]))
	var copy := _match()
	Protocol.apply_snapshot(copy, Protocol.encode_snapshot(m, 10))
	assert_eq(copy.clock.timeouts, [1, 2])
