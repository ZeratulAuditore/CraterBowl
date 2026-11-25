extends RefCounted
## Downs rules engine. Offense-frame yards: 0 = offense's own goal line,
## 100 = opponent goal line. Pure + deterministic.

const GOAL := 100.0   # default; real goal is `goal` (field length)

var goal := GOAL

var offense_team := 0
var down := 1
var los := 25.0
var first_down_y := 35.0

func reset(team: int, at: float) -> void:
	offense_team = team
	down = 1
	los = at
	first_down_y = minf(at + 10.0, goal)

func distance() -> float:
	return first_down_y - los

func is_goal_to_go() -> bool:
	return first_down_y >= goal

## result: {"type": "tackle"|"out_of_bounds"|"incomplete", "spot": float (offense frame)}
## Returns {"outcome": "first_down"|"next_down"|"turnover_on_downs", ...}
func apply(result: Dictionary) -> Dictionary:
	var spot := los
	if result.get("type", "") != "incomplete":
		spot = clampf(result.get("spot", los), 1.0, goal - 1.0)
	if spot >= first_down_y:
		reset(offense_team, spot)
		return {"outcome": "first_down", "los": los}
	down += 1
	los = spot
	if down > 4:
		reset(1 - offense_team, goal - spot)
		return {"outcome": "turnover_on_downs", "los": los, "offense": offense_team}
	return {"outcome": "next_down", "los": los, "down": down}

static func ordinal(n: int) -> String:
	return ["1st", "2nd", "3rd", "4th"][clampi(n - 1, 0, 3)]

func label() -> String:
	var dist := "Goal" if is_goal_to_go() else str(maxi(1, int(round(distance()))))
	var yl := int(round(los))
	var g := int(round(goal))
	var where := ("OWN %d" % yl) if yl <= g / 2 else ("OPP %d" % (g - yl))
	return "%s & %s at %s" % [ordinal(down), dist, where]
