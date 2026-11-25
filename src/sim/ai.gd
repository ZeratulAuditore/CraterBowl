extends RefCounted
## Placeholder AI (foundation for A14 bots). Produces inputs for athletes not
## controlled by humans and triggers defender dives. Deterministic.

const T := preload("res://src/sim/tuning.gd")
const Athlete := preload("res://src/sim/athlete.gd")

var defense_enabled := true
var offense_enabled := true

## Returns inputs for every athlete not in `human_ids`. May call world.tackle().
func think(world, human_ids: Array) -> Dictionary:
	var out := {}
	if world.phase != world.Phase.LIVE:
		return out
	var c = world.carrier()
	var caught: bool = c != null and c.role != Athlete.Role.QB
	for a in world.athletes:
		if human_ids.has(a.id):
			continue
		if a.team == world.offense_team:
			if offense_enabled and (a.role == Athlete.Role.WR or a.role == Athlete.Role.RB) and not world.ball.is_held_by(a.id):
				out[a.id] = {"dir": Vector2(0, 1), "sprint": false}
		elif defense_enabled and c != null and (caught or world.play_time >= T.AI_RUSH_DELAY):
			var to: Vector2 = c.position - a.position
			# lead the carrier a little
			to += c.velocity * clampf(to.length() / T.SPRINT_SPEED, 0.0, 0.6)
			out[a.id] = {"dir": to.normalized(), "sprint": true}
			if to.length() <= T.AI_DIVE_RANGE and a.can_act():
				a.facing = (c.position - a.position).normalized()
				world.tackle(a.id)
	return out
