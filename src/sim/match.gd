extends RefCounted
## Match flow layer: World (one play) + Downs (series) + score. Clock comes in A09.

const World := preload("res://src/sim/world.gd")
const Downs := preload("res://src/sim/downs.gd")

const TD_POINTS := 6
const SAFETY_POINTS := 2
const TRY_LOS := {1: 97.0, 2: 90.0}   # 1 pt from the 3, 2 pts from the 10
const KICKOFF_LOS := 25.0

enum State { SCRIMMAGE, TRY }

signal match_event(name: String, data: Dictionary)

var world: World
var downs := Downs.new()
var score := [0, 0]
var state: State = State.SCRIMMAGE
var try_points := 1
var last_result := {}
var last_outcome := {}

func _init(w: World) -> void:
	world = w
	world.event.connect(_on_world_event)

func start(offense: int = 0, los: float = 25.0) -> void:
	state = State.SCRIMMAGE
	downs.reset(offense, los)
	world.set_offense(offense)
	world.setup_formation(los)

func _on_world_event(n: String, d: Dictionary) -> void:
	match n:
		"tackle", "out_of_bounds":
			last_result = {"type": n, "spot": d["spot"].y}
		"incomplete":
			last_result = {"type": "incomplete"}
		"touchdown":
			last_result = {"type": "touchdown"}

## During try presnap: choose 1 (from the 3) or 2 (from the 10).
func choose_try(points: int) -> bool:
	if state != State.TRY or world.phase != World.Phase.PRESNAP or not TRY_LOS.has(points):
		return false
	try_points = points
	downs.los = TRY_LOS[points]
	world.setup_formation(downs.los)
	return true

func _award(team: int, pts: int, why: String) -> void:
	score[team] += pts
	match_event.emit("score", {"team": team, "points": pts, "why": why, "score": score.duplicate()})

func _kickoff(receiving: int) -> Dictionary:
	state = State.SCRIMMAGE
	downs.reset(receiving, KICKOFF_LOS)
	return {"outcome": "kickoff", "los": KICKOFF_LOS, "offense": receiving}

## Apply the last play's result and line up for the next snap.
func next_play() -> Dictionary:
	if last_result.is_empty():
		last_result = {"type": "incomplete"}
	var r := last_result
	last_result = {}
	var off := downs.offense_team
	var def := 1 - off
	if state == State.TRY:
		if r["type"] == "touchdown":
			_award(off, try_points, "try")
			last_outcome = _kickoff(def)
			last_outcome["try"] = "good"
		else:
			last_outcome = _kickoff(def)
			last_outcome["try"] = "no_good"
	elif r["type"] == "touchdown":
		_award(off, TD_POINTS, "touchdown")
		state = State.TRY
		try_points = 1
		downs.down = 1
		downs.los = TRY_LOS[1]
		downs.first_down_y = Downs.GOAL
		last_outcome = {"outcome": "try", "los": downs.los}
	elif r["type"] != "incomplete" and r.get("spot", 1.0) < 0.0:
		_award(def, SAFETY_POINTS, "safety")
		last_outcome = _kickoff(def)
		last_outcome["safety"] = true
	else:
		last_outcome = downs.apply(r)
	if downs.offense_team != world.offense_team:
		world.set_offense(downs.offense_team)
	world.setup_formation(downs.los)
	match_event.emit(last_outcome["outcome"], last_outcome)
	return last_outcome
