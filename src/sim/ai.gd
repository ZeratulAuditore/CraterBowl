extends RefCounted
## Placeholder AI (foundation for A14 bots). Produces inputs for athletes not
## controlled by humans and triggers defender dives. Deterministic.

const T := preload("res://src/sim/tuning.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Passing := preload("res://src/sim/passing.gd")

var defense_enabled := true
var offense_enabled := true

## Returns inputs for every athlete not in `human_ids`. May call world.tackle().
func think(world, human_ids: Array) -> Dictionary:
	var out := {}
	if world.phase != world.Phase.LIVE:
		return out
	var c = world.carrier()
	var caught: bool = c != null and c.role != Athlete.Role.QB
	var loose: bool = world.ball.state == world.ball.State.LOOSE
	var returning: bool = c != null and c.team != world.offense_team
	for a in world.athletes:
		if human_ids.has(a.id):
			continue
		if loose:
			if a.can_act():
				var bp := Vector2(world.ball.position.x, world.ball.position.y)
				out[a.id] = {"dir": (bp - a.position).normalized(), "sprint": true}
			continue
		if returning:
			if a.team == c.team:
				out[a.id] = _escort(world, a, c)
			else:
				out[a.id] = _pursue(world, a, c)
			continue
		if a.team == world.offense_team:
			if not offense_enabled:
				continue
			if world.ball.is_held_by(a.id):
				if a.role == Athlete.Role.QB and not world.forward_pass_thrown:
					_qb_decide(world, a)
				continue
			if a.role == Athlete.Role.WR or a.role == Athlete.Role.RB:
				out[a.id] = {"dir": _avoid(world, a, _route_dir(world, a)), "sprint": false}
			elif (a.role == Athlete.Role.OL or a.role == Athlete.Role.C) and c != null:
				out[a.id] = _protect(world, a, c)
		elif defense_enabled and c != null and (caught or a.role == Athlete.Role.DL or world.play_time >= T.AI_RUSH_DELAY):
			out[a.id] = _pursue(world, a, c)
	return out

func _pursue(world, a, c) -> Dictionary:
	var to: Vector2 = c.position - a.position
	to += c.velocity * clampf(to.length() / T.SPRINT_SPEED, 0.0, 0.6)  # lead the carrier
	if to.length() <= T.AI_DIVE_RANGE and a.can_act():
		a.facing = (c.position - a.position).normalized()
		world.tackle(a.id)
	return {"dir": to.normalized(), "sprint": true}

## Returner's teammates: get in front of the nearest pursuer.
func _escort(world, a, c) -> Dictionary:
	if a.id == c.id:
		return {}
	var best = null
	var best_d := INF
	for o in world.athletes:
		if o.team == a.team or o.is_grounded():
			continue
		var d: float = o.position.distance_to(c.position)
		if d < best_d:
			best_d = d
			best = o
	if best == null:
		return {"dir": Vector2(0, -1), "sprint": true}
	var spot: Vector2 = best.position + (c.position - best.position).normalized() * 0.9
	return {"dir": (spot - a.position).normalized(), "sprint": true}

## Throw to the most open eligible receiver after QB_THROW_TIME, or early under pressure.
func _qb_decide(world, qb) -> void:
	var pressure := INF
	for d in world.athletes:
		if d.team != world.offense_team:
			pressure = minf(pressure, d.position.distance_to(qb.position))
	if world.play_time < T.AI_QB_THROW_TIME and pressure > T.AI_QB_PRESSURE:
		return
	var best = null
	var best_sep := -INF
	for r in world.athletes:
		if r.team != world.offense_team or r.id == qb.id or not world.is_eligible_receiver(r):
			continue
		if r.position.y <= world.los_y:
			continue
		var sep := INF
		for d in world.athletes:
			if d.team != world.offense_team:
				sep = minf(sep, d.position.distance_to(r.position))
		if sep > best_sep:
			best_sep = sep
			best = r
	if best == null:
		return
	var from := Vector3(qb.position.x, qb.position.y, T.RELEASE_HEIGHT)
	world.throw(qb.id, Passing.lead_target(from, best.position, best.velocity, 0.85), 0.85)

## Follow the assigned route path; after the last waypoint keep the final direction.
var _route_progress := {}   # athlete_id -> waypoint index (reset when paths change)
var _paths_ref = null

func _route_dir(world, a) -> Vector2:
	if world.route_paths != _paths_ref:
		_paths_ref = world.route_paths
		_route_progress = {}
	var path: Array = world.route_paths.get(a.id, [])
	if path.is_empty():
		return Vector2(0, 1)
	var i: int = _route_progress.get(a.id, 0)
	while i < path.size() and a.position.distance_to(path[i]) < 1.0:
		i += 1
	_route_progress[a.id] = i
	if i < path.size():
		return (path[i] - a.position).normalized()
	var last: Vector2 = path[-1]
	var prev: Vector2 = path[-2] if path.size() > 1 else last - Vector2(0, 1)
	var d := (last - prev).normalized()
	return d if d.length_squared() > 0.0 else Vector2(0, 1)

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
