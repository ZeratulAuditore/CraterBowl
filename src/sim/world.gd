extends RefCounted
## Authoritative match simulation: athletes, ball, play phase.
## Deterministic and input-driven: step(inputs, dt) where inputs maps
## athlete id -> {"dir": Vector2, "sprint": bool}.

const T := preload("res://src/sim/tuning.gd")
const Field := preload("res://src/sim/field.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")
const Passing := preload("res://src/sim/passing.gd")

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
var dead_ball_spot := Vector2.ZERO
var play_time := 0.0

func add_athlete(team: int, role: int, pos: Vector2) -> Athlete:
	var a := Athlete.new(athletes.size(), team, role, pos, field)
	athletes.append(a)
	return a

func get_athlete(id: int) -> Athlete:
	return athletes[id] if id >= 0 and id < athletes.size() else null

func find_role(team: int, role: int) -> Athlete:
	for a in athletes:
		if a.team == team and a.role == role:
			return a
	return null

## Offense attacks +y. Places the C on the LOS and the QB 5 yd behind. Other
## athletes keep their x and are set on their side of the line.
func setup_formation(los: float) -> void:
	los_y = los
	var cx := field.width / 2.0
	var c := find_role(offense_team, Athlete.Role.C)
	var qb := find_role(offense_team, Athlete.Role.QB)
	play_time = 0.0
	for a in athletes:
		a.reset_state()
		if a.team == offense_team:
			a.position.y = los - 1.0
		else:
			a.position.y = los + 5.0
	if c:
		c.position = Vector2(cx, los - 0.5)
	if qb:
		qb.position = Vector2(cx, los - 5.0)
	if c:
		ball.hold(c.id)
	forward_pass_thrown = false
	last_thrower_id = -1
	_snap_to_id = -1
	phase = Phase.PRESNAP
	_sync_ball()

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
	event.emit("throw", {"by": id, "target": target, "power": power})
	return true

## Defender starts a dive tackle in their facing direction.
func tackle(id: int) -> bool:
	var a := get_athlete(id)
	if a == null or phase != Phase.LIVE:
		return false
	return a.start_dive()

func carrier() -> Athlete:
	return get_athlete(ball.holder_id) if ball.state == Ball.State.HELD else null

func step(inputs: Dictionary, dt: float) -> void:
	if phase == Phase.LIVE:
		play_time += dt
	for a in athletes:
		var inp: Dictionary = inputs.get(a.id, {})
		a.step(inp.get("dir", Vector2.ZERO), inp.get("sprint", false), dt)
		if phase == Phase.PRESNAP:
			_enforce_neutral_zone(a)
	_step_snap(dt)
	_step_flight(dt)
	_sync_ball()
	if phase == Phase.LIVE:
		_check_tackles()

func _check_tackles() -> void:
	var c := carrier()
	if c == null:
		return
	if field.zone_of(c.position) == Field.Zone.OUT_OF_BOUNDS:
		_whistle("out_of_bounds", {"carrier": c.id})
		return
	for a in athletes:
		if a.team != offense_team and a.is_diving() and a.position.distance_to(c.position) <= T.TACKLE_REACH:
			_whistle("tackle", {"by": a.id, "carrier": c.id})
			return

func _whistle(reason: String, data: Dictionary) -> void:
	var c := carrier()
	dead_ball_spot = c.position
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
	if defender_reaches and best[0] == null or defender_contests:
		_end_incomplete("breakup", {"by": best[1].id, "at": at})
		return true
	var rx: Athlete = best[0]
	if field.zone_of(rx.position) == Field.Zone.OUT_OF_BOUNDS:
		_end_incomplete("out_of_bounds", {"by": rx.id, "at": at})
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
