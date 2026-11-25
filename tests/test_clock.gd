extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Clock := preload("res://src/sim/clock.gd")
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
	assert_eq(m.world.offense_team, 1, "other team receives 2nd half")
	assert_near(m.world.los_y, 25.0)

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
