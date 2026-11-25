extends RefCounted
## Match flow layer: World (one play) + Downs (series) + score. Clock comes in A09.

const World := preload("res://src/sim/world.gd")
const Downs := preload("res://src/sim/downs.gd")
const Clock := preload("res://src/sim/clock.gd")

const TD_POINTS := 6
const SAFETY_POINTS := 2
const TRY_DIST := {1: 3.0, 2: 10.0}   # 1 pt from the 3, 2 pts from the 10
const KICKOFF_FRACTION := 0.25        # receive at 25% of the field (own 25 on 100 yd)

enum State { SCRIMMAGE, TRY }

signal match_event(name: String, data: Dictionary)

var world: World
var downs := Downs.new()
var clock := Clock.new()
var opening_receiver := 0
var score := [0, 0]
var max_deficit := [0, 0]   # worst trailing margin each team faced
var state: State = State.SCRIMMAGE
var try_points := 1
var last_result := {}
var last_outcome := {}

func _init(w: World) -> void:
	world = w
	downs.goal = w.field.length
	world.event.connect(_on_world_event)

func goal() -> float:
	return world.field.length

func try_los(points: int) -> float:
	return goal() - TRY_DIST[points]

func kickoff_los() -> float:
	return roundf(goal() * KICKOFF_FRACTION)

func start(offense: int = 0, los: float = -1.0) -> void:
	downs.goal = goal()
	if los < 0.0:
		los = kickoff_los()
	state = State.SCRIMMAGE
	opening_receiver = offense
	clock.reset()
	downs.reset(offense, los)
	world.set_offense(offense)
	world.setup_formation(los)

func _on_world_event(n: String, d: Dictionary) -> void:
	match n:
		"tackle", "out_of_bounds":
			last_result = {"type": n, "spot": d["spot"].y, "team": d.get("team", world.offense_team)}
		"incomplete":
			last_result = {"type": "incomplete", "team": d.get("team", world.offense_team),
				"spot": (d.get("at", Vector2(0, downs.los)) as Vector2).y}
		"touchdown":
			last_result = {"type": "touchdown", "team": d.get("team", world.offense_team), "points": d.get("points", TD_POINTS)}
		"explode":
			last_result = {"type": "explode", "spot": d["spot"].y, "team": d.get("team", world.offense_team)}

## During try presnap: choose 1 (from the 3) or 2 (from the 10).
func choose_try(points: int) -> bool:
	if state != State.TRY or world.phase != World.Phase.PRESNAP or not TRY_DIST.has(points):
		return false
	try_points = points
	downs.los = try_los(points)
	world.setup_formation(downs.los)
	return true

func _award(team: int, pts: int, why: String) -> void:
	score[team] += pts
	for t in 2:
		max_deficit[t] = maxi(max_deficit[t], score[1 - t] - score[t])
	match_event.emit("score", {"team": team, "points": pts, "why": why, "score": score.duplicate()})

func _kickoff(receiving: int) -> Dictionary:
	state = State.SCRIMMAGE
	downs.reset(receiving, kickoff_los())
	return {"outcome": "kickoff", "los": downs.los, "offense": receiving}

## Advance clocks; auto-snap when the play clock expires.
func tick(dt: float) -> void:
	var snap_now := clock.tick(dt, world.phase == World.Phase.LIVE, world.phase == World.Phase.PRESNAP)
	if snap_now and world.snap():
		match_event.emit("auto_snap", {})

func is_final() -> bool:
	return clock.final

func winner() -> int:
	if score[0] == score[1]:
		return -1
	return 0 if score[0] > score[1] else 1

## Chaosball: one live play per possession. TD scores; anything else hands the
## ball to the team that didn't end the play with it, at the spot.
func _chaos_next(r: Dictionary, holder_team: int, off: int) -> Dictionary:
	if r["type"] == "touchdown":
		_award(holder_team, int(r.get("points", TD_POINTS)), "touchdown")
		return _kickoff(1 - holder_team)
	var new_off := 1 - holder_team
	var spot: float = r.get("spot", downs.los)
	var los := spot if new_off == off else goal() - spot
	downs.reset(new_off, clampf(los, 1.0, goal() - 1.0))
	return {"outcome": "turnover", "los": downs.los, "offense": new_off}

## Apply the last play's result and line up for the next snap.
func next_play() -> Dictionary:
	if clock.final:
		return {"outcome": "final"}
	if last_result.is_empty():
		last_result = {"type": "incomplete"}
	var r := last_result
	last_result = {}
	var off := downs.offense_team
	var def := 1 - off
	var r_team: int = r.get("team", off)
	if world.is_chaos():
		last_outcome = _chaos_next(r, r_team, off)
	elif state == State.TRY:
		if r["type"] == "touchdown" and r_team == off:
			_award(off, try_points, "try")
			last_outcome = _kickoff(def)
			last_outcome["try"] = "good"
		else:
			last_outcome = _kickoff(def)
			last_outcome["try"] = "no_good"
	elif r["type"] == "touchdown":
		_award(r_team, TD_POINTS, "touchdown" if r_team == off else "defensive_touchdown")
		downs.offense_team = r_team   # the scoring team attempts the try
		state = State.TRY
		try_points = 1
		downs.down = 1
		downs.los = try_los(1)
		downs.first_down_y = goal()
		last_outcome = {"outcome": "try", "los": downs.los}
	elif r["type"] != "incomplete" and r_team != off:
		# Takeaway: new offense from the mirrored spot; downed in own end zone -> touchback.
		var spot := goal() - float(r["spot"])
		if spot <= 0.0:
			spot = kickoff_los()
		downs.reset(r_team, clampf(spot, 1.0, goal() - 1.0))
		last_outcome = {"outcome": "turnover", "los": downs.los, "offense": r_team}
	elif r["type"] != "incomplete" and r.get("spot", 1.0) < 0.0:
		_award(def, SAFETY_POINTS, "safety")
		last_outcome = _kickoff(def)
		last_outcome["safety"] = true
	else:
		last_outcome = downs.apply(r)
	# Half/game ends once the clock is out and no try is pending.
	if clock.expired() and state != State.TRY:
		if clock.half < Clock.HALVES:
			clock.start_next_half()
			last_outcome = _kickoff(1 - opening_receiver)
			last_outcome["outcome"] = "halftime"
		else:
			clock.final = true
			world.phase = World.Phase.DEAD
			last_outcome = {"outcome": "final", "score": score.duplicate(), "winner": winner()}
			match_event.emit("final", last_outcome)
			return last_outcome
	clock.new_play()
	if downs.offense_team != world.offense_team:
		world.set_offense(downs.offense_team)
	world.setup_formation(downs.los)
	match_event.emit(last_outcome["outcome"], last_outcome)
	return last_outcome
