extends RefCounted
## Shared defensive calls for the huddle and defensive assignments.
const T := preload("res://src/sim/tuning.gd")

enum Family { MAN, ZONE, BLITZ }
enum Shell { BASE, GOAL_LINE, PREVENT }

const CALLS := {
	"cover_1": {"name": "Cover 1", "family": Family.MAN, "shell": Shell.BASE},
	"cover_2": {"name": "Cover 2", "family": Family.ZONE, "shell": Shell.BASE},
	"cover_3": {"name": "Cover 3", "family": Family.ZONE, "shell": Shell.BASE},
	"edge_blitz": {"name": "Edge Blitz", "family": Family.BLITZ, "shell": Shell.BASE},
	"goal_man": {"name": "Goal Line Man", "family": Family.MAN, "shell": Shell.GOAL_LINE},
	"goal_zone": {"name": "Goal Line Zone", "family": Family.ZONE, "shell": Shell.GOAL_LINE},
	"goal_blitz": {"name": "Goal Line Blitz", "family": Family.BLITZ, "shell": Shell.GOAL_LINE},
	"deep_man": {"name": "Deep Man", "family": Family.MAN, "shell": Shell.PREVENT},
	"deep_zone": {"name": "Deep Zone", "family": Family.ZONE, "shell": Shell.PREVENT},
}

## Distances are measured from the line of scrimmage, in the offense's direction.
static func suggest(down: int, yards_to_gain: float, yards_to_goal: float, seconds_left: float) -> String:
	if yards_to_goal <= T.DEFENSE_GOAL_LINE_RANGE:
		return "goal_zone"
	if down >= 3 and yards_to_gain >= T.DEFENSE_PREVENT_DISTANCE and seconds_left <= T.DEFENSE_PREVENT_TIME:
		return "deep_zone"
	return "cover_2"
