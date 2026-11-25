extends RefCounted
## Authoritative match simulation: athletes, ball, play phase.
## Deterministic and input-driven: step(inputs, dt) where inputs maps
## athlete id -> {"dir": Vector2, "sprint": bool}.

const T := preload("res://src/sim/tuning.gd")
const Field := preload("res://src/sim/field.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")

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
	for a in athletes:
		a.velocity = Vector2.ZERO
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

func step(inputs: Dictionary, dt: float) -> void:
	for a in athletes:
		var inp: Dictionary = inputs.get(a.id, {})
		a.step(inp.get("dir", Vector2.ZERO), inp.get("sprint", false), dt)
		if phase == Phase.PRESNAP:
			_enforce_neutral_zone(a)
	_step_snap(dt)
	_sync_ball()

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
