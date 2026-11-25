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
			if not offense_enabled or world.ball.is_held_by(a.id):
				continue
			if a.role == Athlete.Role.WR or a.role == Athlete.Role.RB:
				out[a.id] = {"dir": _avoid(world, a, Vector2(0, 1)), "sprint": false}
			elif (a.role == Athlete.Role.OL or a.role == Athlete.Role.C) and c != null:
				out[a.id] = _protect(world, a, c)
		elif defense_enabled and c != null and (caught or a.role == Athlete.Role.DL or world.play_time >= T.AI_RUSH_DELAY):
			var to: Vector2 = c.position - a.position
			# lead the carrier a little
			to += c.velocity * clampf(to.length() / T.SPRINT_SPEED, 0.0, 0.6)
			out[a.id] = {"dir": to.normalized(), "sprint": true}
			if to.length() <= T.AI_DIVE_RANGE and a.can_act():
				a.facing = (c.position - a.position).normalized()
				world.tackle(a.id)
	return out

## Steer around an opponent standing directly in the running lane.
func _avoid(world, a, dir: Vector2) -> Vector2:
	for o in world.athletes:
		if o.team == a.team or o.is_grounded():
			continue
		var rel: Vector2 = o.position - a.position
		var ahead := rel.dot(dir)
		var side := rel.dot(Vector2(dir.y, -dir.x))
		if ahead > 0.0 and ahead < 2.5 and absf(side) < 1.2:
			var away := -signf(side) if absf(side) > 0.05 else (1.0 if a.position.x < world.field.width / 2.0 else -1.0)
			return (dir + Vector2(dir.y, -dir.x) * away * 1.2).normalized()
	return dir

## Pass protection: get between the nearest free rusher and the carrier, face him.
func _protect(world, a, carrier) -> Dictionary:
	if a.engaged_with >= 0:
		var held = world.get_athlete(a.engaged_with)
		return {"dir": (held.position - a.position).normalized(), "sprint": false}
	var best = null
	var best_d := INF
	for d in world.athletes:
		if d.team == world.offense_team or d.is_grounded():
			continue
		var dist: float = d.position.distance_to(a.position)
		if dist < best_d and dist < 8.0:
			best_d = dist
			best = d
	if best == null:
		return {"dir": Vector2.ZERO, "sprint": false}
	var spot: Vector2 = best.position + (carrier.position - best.position).normalized() * 0.9
	var to: Vector2 = spot - a.position
	if to.length() < 0.2:
		to = best.position - a.position  # in position: face the rusher
	return {"dir": to.normalized(), "sprint": false}
