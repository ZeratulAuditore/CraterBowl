extends RefCounted
## Authoritative match simulation: athletes, ball, play phase.
## Deterministic and input-driven: step(inputs, dt) where inputs maps
## athlete id -> {"dir": Vector2, "sprint": bool}.

const T := preload("res://src/sim/tuning.gd")
const Field := preload("res://src/sim/field.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")
const Passing := preload("res://src/sim/passing.gd")
const Routes := preload("res://src/sim/routes.gd")

enum Phase { PRESNAP, LIVE, DEAD }

signal event(name: String, data: Dictionary)

var field := Field.new()
var ball := Ball.new()
var athletes: Array = []   # Array[Athlete]
var phase: Phase = Phase.DEAD
var offense_team := 0
var los_y := 25.0
var _snap_t := 0.0
var _snap_from := Vector3.ZERO
var _snap_to_id := -1
var forward_pass_thrown := false
var last_thrower_id := -1
var throw_origin := Vector2.ZERO
var dead_ball_spot := Vector2.ZERO
var last_possession := 0
var dead_ball_team := 0
var play_time := 0.0
var play_name := "Verticals"
var route_of := {}      # athlete_id -> route name (eligible offense receivers)
var route_paths := {}   # athlete_id -> Array[Vector2] absolute, set at snap

## role/pos are for the athlete's current side. Optional two-way setup:
## off/def roles + x via set_two_way().
func add_athlete(team: int, role: int, pos: Vector2) -> Athlete:
	var a := Athlete.new(athletes.size(), team, role, pos, field)
	athletes.append(a)
	return a

func add_two_way(team: int, off_role: int, off_x: float, def_role: int, def_x: float) -> Athlete:
	var a := add_athlete(team, off_role, Vector2(off_x, 0))
	a.off_role = off_role
	a.def_role = def_role
	a.off_x = off_x
	a.def_x = def_x
	a.set_side(team == offense_team)
	return a

func set_offense(team: int) -> void:
	offense_team = team
	for a in athletes:
		a.set_side(a.team == team)

func get_athlete(id: int) -> Athlete:
	return athletes[id] if id >= 0 and id < athletes.size() else null

func find_role(team: int, role: int) -> Athlete:
	for a in athletes:
		if a.team == team and a.role == role:
			return a
	return null

## Depth from the LOS per role (offense behind, defense ahead).
const FORMATION_DEPTH := {
	Athlete.Role.C: 0.5, Athlete.Role.OL: 1.0, Athlete.Role.WR: 1.0, Athlete.Role.QB: 5.0,
	Athlete.Role.RB: 6.0, Athlete.Role.DL: 1.0, Athlete.Role.LB: 5.0, Athlete.Role.CB: 2.0,
	Athlete.Role.S: 12.0,
}

## Offense attacks +y. Everyone returns to their home x at role depth; the C
## lines up at the field center with the ball.
func setup_formation(los: float) -> void:
	los_y = los
	play_time = 0.0
	var cx := field.width / 2.0
	for a in athletes:
		a.reset_state()
		var depth: float = FORMATION_DEPTH.get(a.role, 1.0)
		var y := los - depth if a.team == offense_team else los + depth
		a.position = Vector2(a.home_x, y)
	var c := find_role(offense_team, Athlete.Role.C)
	var qb := find_role(offense_team, Athlete.Role.QB)
	if c:
		c.position.x = cx
	if qb:
		qb.position.x = cx
	if c:
		ball.hold(c.id)
	forward_pass_thrown = false
	last_thrower_id = -1
	_snap_to_id = -1
	route_paths = {}
	last_possession = offense_team
	call_play("Verticals")
	phase = Phase.PRESNAP
	_sync_ball()

## Eligible receivers in playbook order: left WR, right WR, RB.
func receivers_in_order() -> Array:
	var wrs := []
	var rb = null
	for a in athletes:
		if a.team != offense_team:
			continue
		if a.role == Athlete.Role.WR:
			wrs.append(a)
		elif a.role == Athlete.Role.RB:
			rb = a
	wrs.sort_custom(func(p, q): return p.home_x < q.home_x)
	if rb:
		wrs.append(rb)
	return wrs

func call_play(name: String) -> bool:
	if not Routes.PLAYBOOK.has(name):
		return false
	play_name = name
	route_of = {}
	var recv := receivers_in_order()
	var routes: Array = Routes.PLAYBOOK[name]
	for i in mini(recv.size(), routes.size()):
		route_of[recv[i].id] = routes[i]
	return true

func set_route(id: int, route: String) -> bool:
	var a := get_athlete(id)
	if a == null or a.team != offense_team or not is_eligible_receiver(a) or a.role == Athlete.Role.QB:
		return false
	if not Routes.ROUTES.has(route):
		return false
	route_of[id] = route
	return true

func snap() -> bool:
	if phase != Phase.PRESNAP:
		return false
	var c := find_role(offense_team, Athlete.Role.C)
	var qb := find_role(offense_team, Athlete.Role.QB)
	if c == null or qb == null or not ball.is_held_by(c.id):
		return false
	ball.state = Ball.State.IN_FLIGHT
	ball.holder_id = -1
	_snap_t = 0.0
	_snap_from = ball.position
	_snap_to_id = qb.id
	route_paths = {}
	for id in route_of:
		var a := get_athlete(id)
		route_paths[id] = Routes.path_for(route_of[id], a.position, field.width)
	phase = Phase.LIVE
	event.emit("snap", {"qb": qb.id})
	return true

## Throw from the holder toward target (field plane) with power 0..1.
func throw(id: int, target: Vector2, power: float) -> bool:
	var a := get_athlete(id)
	if a == null or phase != Phase.LIVE or not ball.is_held_by(id):
		return false
	if forward_pass_thrown or a.position.y > los_y:
		return false
	var from := Vector3(a.position.x, a.position.y, T.RELEASE_HEIGHT)
	var v := Passing.solve_velocity(from, target, power)
	v += Vector3(a.velocity.x, a.velocity.y, 0.0) * T.THROW_INHERIT
	ball.state = Ball.State.IN_FLIGHT
	ball.holder_id = -1
	ball.position = from
	ball.velocity = v
	forward_pass_thrown = true
	last_thrower_id = id
	throw_origin = Vector2(from.x, from.y)
	event.emit("throw", {"by": id, "target": target, "power": power})
	return true

## Defender starts a dive tackle in their facing direction.
func tackle(id: int) -> bool:
	var a := get_athlete(id)
	if a == null or phase != Phase.LIVE:
		return false
	return a.start_dive()

## Team in possession during live play (carrier's team), else the offense.
func possession_team() -> int:
	var c := carrier()
	if c != null:
		return c.team
	if ball.state == Ball.State.LOOSE:
		return last_possession
	return offense_team

func carrier() -> Athlete:
	return get_athlete(ball.holder_id) if ball.state == Ball.State.HELD else null

func step(inputs: Dictionary, dt: float) -> void:
	if phase == Phase.LIVE:
		play_time += dt
	var prev: Array = []
	for a in athletes:
		prev.append(a.position)
		var inp: Dictionary = inputs.get(a.id, {})
		a.step(inp.get("dir", Vector2.ZERO), inp.get("sprint", false), dt)
	if phase == Phase.LIVE:
		_step_blocks(prev, dt)
	_resolve_collisions()
	if phase == Phase.PRESNAP:
		for a in athletes:
			_enforce_neutral_zone(a)
	_step_snap(dt)
	_step_flight(dt)
	if phase == Phase.LIVE:
		_step_loose(dt)
	_sync_ball()
	if phase == Phase.LIVE:
		_check_tackles()

## Linemen block any time; skill players only block downfield (after a catch
## or once the carrier is past the LOS), so receivers run routes instead.
func _can_block(a: Athlete) -> bool:
	var pt := possession_team()
	if a.team != pt or ball.is_held_by(a.id) or not a.can_act() or a.engaged_with >= 0 or a.immune_t > 0.0:
		return false
	if pt != offense_team:
		return true   # return after a takeaway: anyone can block
	if a.role == Athlete.Role.OL or a.role == Athlete.Role.C:
		return true
	var c := carrier()
	return c != null and (c.role != Athlete.Role.QB or c.position.y > los_y)

func _can_be_blocked(d: Athlete) -> bool:
	return d.team != possession_team() and not d.is_grounded() and d.engaged_with < 0 and d.immune_t <= 0.0

func _step_blocks(prev: Array, dt: float) -> void:
	for a in athletes:
		a.immune_t = maxf(0.0, a.immune_t - dt)
	# Form new engagements
	for b in athletes:
		if not _can_block(b):
			continue
		for d in athletes:
			if not _can_be_blocked(d):
				continue
			var to: Vector2 = d.position - b.position
			if to.length() <= T.ENGAGE_DIST and b.facing.dot(to.normalized()) >= T.ENGAGE_FACING_DOT:
				b.engaged_with = d.id
				d.engaged_with = b.id
				b.engage_t = 0.0
				d.engage_t = 0.0
				event.emit("block", {"blocker": b.id, "defender": d.id})
				break
	# Apply engagements: defender displacement driven by blocker
	var pt := possession_team()
	for d in athletes:
		if d.team == pt or d.engaged_with < 0:
			continue
		var b := get_athlete(d.engaged_with)
		d.engage_t += dt
		if d.engage_t >= T.BLOCK_HOLD or b == null or not b.can_act() or ball.is_held_by(b.id):
			_release_block(d, b)
			continue
		var d_delta: Vector2 = d.position - prev[d.id]
		var b_delta: Vector2 = b.position - prev[b.id]
		d.position = field.clamp_playable(prev[d.id] + d_delta.lerp(b_delta, T.BLOCK_DRIVE))
		d.velocity = d.velocity.lerp(b.velocity, T.BLOCK_DRIVE)

func _release_block(d: Athlete, b: Athlete) -> void:
	d.engaged_with = -1
	d.immune_t = T.BLOCK_IMMUNITY
	if b:
		b.engaged_with = -1
		b.immune_t = T.BLOCKER_BEATEN
	event.emit("shed", {"defender": d.id})

func _resolve_collisions() -> void:
	var min_d := T.BODY_RADIUS * 2.0
	for i in athletes.size():
		var a: Athlete = athletes[i]
		if a.is_grounded():
			continue
		for j in range(i + 1, athletes.size()):
			var o: Athlete = athletes[j]
			if o.is_grounded():
				continue
			var delta: Vector2 = o.position - a.position
			var d := delta.length()
			if d < min_d:
				var n := delta / d if d > 0.0001 else Vector2(1, 0)
				var push := (min_d - d) * 0.5
				a.position -= n * push
				o.position += n * push

func _check_tackles() -> void:
	var c := carrier()
	if c == null:
		return
	last_possession = c.team
	var z := field.zone_of(c.position)
	var scoring_zone := Field.Zone.ENDZONE_B if c.team == offense_team else Field.Zone.ENDZONE_A
	if z == scoring_zone:
		_whistle("touchdown", {"carrier": c.id, "team": c.team})
		return
	if z == Field.Zone.OUT_OF_BOUNDS:
		_whistle("out_of_bounds", {"carrier": c.id, "team": c.team})
		return
	for a in athletes:
		if a.team != c.team and a.is_diving() and a.position.distance_to(c.position) <= T.TACKLE_REACH:
			if _is_strip(a, c):
				_fumble(c, a)
			else:
				_whistle("tackle", {"by": a.id, "carrier": c.id, "team": c.team})
			return

## Deterministic strip: sprinting carrier hit from behind.
func _is_strip(diver: Athlete, c: Athlete) -> bool:
	if not c.last_sprinting or c.velocity.length() < 1.0:
		return false
	return diver.facing.dot(c.velocity.normalized()) > T.FUMBLE_BEHIND_DOT

func _fumble(c: Athlete, by: Athlete) -> void:
	ball.state = Ball.State.LOOSE
	ball.holder_id = -1
	ball.position = Vector3(c.position.x, c.position.y, T.BALL_CARRY_HEIGHT)
	ball.velocity = Vector3(c.velocity.x * 0.5, c.velocity.y * 0.5, 3.0)
	c.recover_t = T.FUMBLE_KNOCKDOWN
	c.velocity *= 0.3
	last_possession = c.team
	event.emit("fumble", {"carrier": c.id, "by": by.id, "at": c.position})

func _step_loose(dt: float) -> void:
	if ball.state != Ball.State.LOOSE:
		return
	ball.velocity.z -= T.GRAVITY * dt
	ball.position += ball.velocity * dt
	if ball.position.z <= 0.0:
		ball.position.z = 0.0
		ball.velocity.z = -ball.velocity.z * T.LOOSE_BOUNCE if absf(ball.velocity.z) > 1.0 else 0.0
		var flat := Vector2(ball.velocity.x, ball.velocity.y)
		flat = flat.move_toward(Vector2.ZERO, T.LOOSE_FRICTION * dt)
		ball.velocity.x = flat.x
		ball.velocity.y = flat.y
	var bp := Vector2(ball.position.x, ball.position.y)
	if field.zone_of(bp) == Field.Zone.OUT_OF_BOUNDS:
		dead_ball_spot = bp
		dead_ball_team = last_possession
		ball.state = Ball.State.DEAD
		phase = Phase.DEAD
		var data := {"spot": bp, "team": last_possession, "loose": true}
		event.emit("out_of_bounds", data)
		event.emit("whistle", data)
		return
	if ball.position.z > T.RECOVER_MAX_HEIGHT:
		return
	var best: Athlete = null
	var best_d := T.RECOVER_RADIUS
	for a in athletes:
		if not a.can_act():
			continue
		var d: float = a.position.distance_to(bp)
		if d <= best_d:
			best_d = d
			best = a
	if best:
		ball.hold(best.id)
		event.emit("recovery", {"by": best.id, "team": best.team, "turnover": best.team != last_possession})
		last_possession = best.team

func _whistle(reason: String, data: Dictionary) -> void:
	var c := carrier()
	dead_ball_spot = c.position
	dead_ball_team = c.team
	data["spot"] = dead_ball_spot
	ball.state = Ball.State.DEAD
	phase = Phase.DEAD
	event.emit(reason, data)
	event.emit("whistle", data)

func _step_flight(dt: float) -> void:
	if ball.state != Ball.State.IN_FLIGHT or _snap_to_id >= 0:
		return
	ball.velocity.z -= T.GRAVITY * dt
	ball.position += ball.velocity * dt
	if _try_catch():
		return
	if ball.position.z <= 0.0:
		ball.position.z = 0.0
		ball.velocity = Vector3.ZERO
		ball.state = Ball.State.DEAD
		phase = Phase.DEAD
		event.emit("incomplete", {"at": Vector2(ball.position.x, ball.position.y)})

## Offensive linemen (C, OL) are ineligible; all defenders may play the ball.
func is_eligible_receiver(a: Athlete) -> bool:
	if a.team != offense_team:
		return true
	return a.role != Athlete.Role.C and a.role != Athlete.Role.OL

## Resolve catches for a ball in flight. Returns true if the play state changed.
func _try_catch() -> bool:
	var z := ball.position.z
	if z < T.CATCH_MIN_HEIGHT or z > T.CATCH_MAX_HEIGHT:
		return false
	# Not catchable/deflectable until it has left the thrower's immediate area.
	if Vector2(ball.position.x - throw_origin.x, ball.position.y - throw_origin.y).length() < T.MIN_PASS_TRAVEL:
		return false
	var bp := Vector2(ball.position.x, ball.position.y)
	var best := [null, null]   # per side: [offense, defense]
	var best_d := [INF, INF]
	for a in athletes:
		if a.id == last_thrower_id or not is_eligible_receiver(a):
			continue
		var d: float = a.position.distance_to(bp)
		var side := 0 if a.team == offense_team else 1
		# Defenders contest from slightly further out (body position matters).
		var reach := T.CATCH_RADIUS + (T.CONTEST_MARGIN if side == 1 else 0.0)
		if d > reach:
			continue
		if d < best_d[side]:
			best_d[side] = d
			best[side] = a
	if best[0] == null and best[1] == null:
		return false
	var at := bp
	var defender_reaches: bool = best[1] != null and best_d[1] <= T.CATCH_RADIUS
	var defender_contests: bool = best[1] != null and best[0] != null and best_d[1] <= best_d[0] + T.CONTEST_MARGIN
	if best[0] == null and not defender_reaches:
		return false
	if defender_contests:
		_end_incomplete("breakup", {"by": best[1].id, "at": at})
		return true
	if defender_reaches and best[0] == null:
		var dfn: Athlete = best[1]
		# Only a defender squarely at the ball intercepts; within normal reach he deflects it.
		# Decide at the ball's closest approach: keep flying while it's still getting closer.
		if best_d[1] > T.INT_RADIUS:
			var next := bp + Vector2(ball.velocity.x, ball.velocity.y) / 60.0
			var next_z := ball.position.z + ball.velocity.z / 60.0
			if next.distance_to(dfn.position) < best_d[1] and next_z >= T.CATCH_MIN_HEIGHT:
				return false
			_end_incomplete("breakup", {"by": dfn.id, "at": at})
			return true
		if field.zone_of(dfn.position) == Field.Zone.OUT_OF_BOUNDS:
			_end_incomplete("breakup", {"by": dfn.id, "at": at})
			return true
		ball.hold(dfn.id)
		last_possession = dfn.team
		event.emit("interception", {"by": dfn.id, "at": at, "team": dfn.team})
		return true
	var rx: Athlete = best[0]
	if field.zone_of(rx.position) == Field.Zone.OUT_OF_BOUNDS:
		_end_incomplete("caught_out_of_bounds", {"by": rx.id, "at": at})
		return true
	ball.hold(rx.id)
	event.emit("catch", {"by": rx.id, "at": at})
	return true

func _end_incomplete(reason: String, data: Dictionary) -> void:
	ball.velocity = Vector3.ZERO
	ball.state = Ball.State.DEAD
	phase = Phase.DEAD
	event.emit(reason, data)
	data["reason"] = reason
	event.emit("incomplete", data)

func _enforce_neutral_zone(a: Athlete) -> void:
	if a.team == offense_team:
		if a.position.y > los_y - 0.5:
			a.position.y = los_y - 0.5
			a.velocity.y = minf(a.velocity.y, 0.0)
	else:
		if a.position.y < los_y + 0.5:
			a.position.y = los_y + 0.5
			a.velocity.y = maxf(a.velocity.y, 0.0)

func _step_snap(dt: float) -> void:
	if _snap_to_id < 0 or ball.state != Ball.State.IN_FLIGHT:
		return
	_snap_t += dt
	var qb := get_athlete(_snap_to_id)
	var to := Vector3(qb.position.x, qb.position.y, T.BALL_CARRY_HEIGHT)
	var k := clampf(_snap_t / T.SNAP_TIME, 0.0, 1.0)
	ball.position = _snap_from.lerp(to, k)
	if k >= 1.0:
		ball.hold(_snap_to_id)
		_snap_to_id = -1
		event.emit("snap_received", {"qb": qb.id})

func _sync_ball() -> void:
	if ball.state == Ball.State.HELD:
		var h := get_athlete(ball.holder_id)
		if h:
			ball.position = Vector3(h.position.x, h.position.y, T.BALL_CARRY_HEIGHT)
