extends RefCounted
## Practice drills. Build their own athletes, score reps, reset. Pure.

const Athlete := preload("res://src/sim/athlete.gd")
const Routes := preload("res://src/sim/routes.gd")
const R := Athlete.Role
const KINDS := ["passing", "catching", "tackling", "scrimmage"]
const REP_PAUSE := 1.2
const TACKLE_TIMEOUT := 6.0
const LOS := 30.0

var kind := "passing"
var me := -1
var reps := 0
var successes := 0
var streak := 0
var best_streak := 0
var rep_over := false
var _pause := 0.0
var _play_i := 0
var _carrier := -1

static func valid(k: String) -> bool:
	return KINDS.has(k)

## Add this drill's athletes to an empty World and return the human athlete id.
func build(world, k: String) -> int:
	kind = k if valid(k) else "passing"
	var cx: float = world.field.width / 2.0
	match kind:
		"passing":
			var qb = world.add_two_way(0, R.QB, cx, R.LB, cx)
			world.add_two_way(0, R.WR, cx - 18.0, R.CB, cx - 18.0)
			world.add_two_way(0, R.WR, cx + 18.0, R.CB, cx + 18.0)
			world.add_two_way(0, R.RB, cx + 4.0, R.S, cx)
			me = qb.id
		"catching":
			world.add_two_way(0, R.QB, cx, R.LB, cx)
			var wr = world.add_two_way(0, R.WR, cx - 14.0, R.CB, cx - 14.0)
			world.add_two_way(1, R.WR, cx - 14.0, R.CB, cx - 14.0)
			me = wr.id
		"tackling":
			var rb = world.add_two_way(0, R.RB, cx, R.S, cx)
			var lb = world.add_two_way(1, R.QB, cx, R.LB, cx)
			_carrier = rb.id
			me = lb.id
		"scrimmage":
			return -1   # caller builds a full roster
	return me

func start_rep(world) -> void:
	rep_over = false
	_pause = 0.0
	world.setup_formation(LOS)
	match kind:
		"passing":
			world.call_play(Routes.PLAY_NAMES[_play_i % Routes.PLAY_NAMES.size()])
			_play_i += 1
		"catching":
			world.call_play("Curls" if _play_i % 2 == 0 else "Slants")
			_play_i += 1
		"tackling":
			var rb = world.get_athlete(_carrier)
			rb.position = Vector2(world.field.width / 2.0 + (4.0 if _play_i % 2 == 0 else -4.0), LOS - 2.0)
			world.get_athlete(me).position = Vector2(world.field.width / 2.0, LOS + 10.0)
			_play_i += 1
			world.start_live_with(_carrier)

func _score(ok: bool) -> void:
	if rep_over:
		return
	rep_over = true
	reps += 1
	if ok:
		successes += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0

## Feed every World event.
func on_event(n: String, d: Dictionary) -> void:
	if kind == "scrimmage":
		return
	match kind:
		"passing":
			if n == "catch":
				_score(true)
			elif n in ["incomplete", "interception", "tackle", "out_of_bounds"]:
				_score(false)
		"catching":
			if n == "catch" and d.get("by", -1) == me:
				_score(true)
			elif n in ["incomplete", "interception", "catch", "tackle"]:
				_score(false)
		"tackling":
			if n == "tackle":
				_score(true)
			elif n in ["touchdown", "out_of_bounds", "fumble"]:
				_score(n == "fumble")

## Returns true when the rep should be reset now.
func tick(world, dt: float) -> bool:
	if kind == "scrimmage":
		return false
	if kind == "tackling" and not rep_over and world.phase == world.Phase.LIVE and world.play_time >= TACKLE_TIMEOUT:
		_score(false)
	if rep_over:
		_pause += dt
		return _pause >= REP_PAUSE
	return false

func label() -> String:
	if kind == "scrimmage":
		return "PRACTICE: Scrimmage vs bots (no clock)"
	return "PRACTICE: %s drill  %d/%d  streak %d (best %d)" % [kind.capitalize(), successes, reps, streak, best_streak]
