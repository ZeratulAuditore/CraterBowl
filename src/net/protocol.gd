extends RefCounted
## Wire protocol: snapshot codec, input sanitizing, authoritative action routing. Pure.

const T := preload("res://src/sim/tuning.gd")
const Routes := preload("res://src/sim/routes.gd")
const DefensivePlaybook := preload("res://src/sim/defensive_playbook.gd")
const DIVE_FLAG := 1
const GROUND_FLAG := 2
const LOCK_FLAG := 4
const BLOCK_FLAG := 8
const SPIN_FLAG := 16
const SPIN_LEFT_FLAG := 32   # spin turned left (visual side)
const Emotes := preload("res://src/sim/emotes.gd")

static func encode_snapshot(m, tick: int, acks: Dictionary = {}) -> Dictionary:
	var w = m.world
	var a := PackedFloat32Array()
	var r := PackedInt32Array()
	var moves := PackedFloat32Array()
	for ath in w.athletes:
		a.append_array([ath.position.x, ath.position.y, ath.velocity.x, ath.velocity.y, ath.facing.x, ath.facing.y, ath.stamina])
		var flags := (DIVE_FLAG if ath.is_diving() else 0) | (GROUND_FLAG if ath.is_grounded() else 0) | (LOCK_FLAG if ath.set_lock else 0)
		flags |= (BLOCK_FLAG if ath.blocking else 0) | (SPIN_FLAG if ath.is_spinning() else 0)
		if ath.is_spinning() and ath.spin_dir < 0:
			flags |= SPIN_LEFT_FLAG
		r.append_array([ath.role, flags, ath.team])
		moves.append_array([ath.move_charge, ath.move_t])
	var b = w.ball
	return {
		"k": "snap", "t": tick, "ph": w.phase, "off": w.offense_team, "los": w.los_y, "fpt": w.forward_pass_thrown, "pt": w.last_possession,
		"a": a, "r": r, "moves": moves,
		"b": PackedFloat32Array([b.state, b.holder_id, b.position.x, b.position.y, b.position.z, b.velocity.x, b.velocity.y, b.velocity.z]),
		"d": PackedFloat32Array([m.downs.offense_team, m.downs.down, m.downs.los, m.downs.first_down_y]),
		"s": PackedInt32Array(m.score),
		"c": PackedFloat32Array([m.clock.half, m.clock.remaining, m.clock.play_clock, 1.0 if m.clock.final else 0.0]),
		"to": PackedInt32Array(m.clock.timeouts),
		"ms": m.state, "tp": m.try_points, "ack": acks, "pl": w.play_name, "rt": _routes_array(w),
		"dc": w.defensive_call, "rf": w.run_flipped, "hc": w.handoff_cooldown,
		"cs": PackedFloat32Array([w.streak, w.hold_t]),
	}

static func _routes_array(w) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(w.athletes.size())
	for i in w.athletes.size():
		out[i] = Routes.route_index(w.route_of.get(i, "")) if w.route_of.has(i) else -1
	return out

static func apply_snapshot(m, s: Dictionary) -> void:
	var w = m.world
	w.phase = s["ph"]
	w.offense_team = s["off"]
	w.los_y = s["los"]
	w.forward_pass_thrown = s["fpt"]
	w.last_possession = s.get("pt", w.offense_team)
	var a: PackedFloat32Array = s["a"]
	var r: PackedInt32Array = s["r"]
	var moves: PackedFloat32Array = s.get("moves", PackedFloat32Array())
	for i in mini(w.athletes.size(), r.size() / 3):
		var ath = w.athletes[i]
		var o := i * 7
		ath.position = Vector2(a[o], a[o + 1])
		ath.velocity = Vector2(a[o + 2], a[o + 3])
		ath.facing = Vector2(a[o + 4], a[o + 5])
		ath.stamina = a[o + 6]
		ath.role = r[i * 3]
		var flags := r[i * 3 + 1]
		ath.dive_t = 0.01 if flags & DIVE_FLAG else 0.0
		ath.recover_t = 0.01 if flags & GROUND_FLAG else 0.0
		ath.set_lock = (flags & LOCK_FLAG) != 0
		ath.blocking = (flags & BLOCK_FLAG) != 0
		ath.spin_move = (flags & SPIN_FLAG) != 0
		if moves.size() >= i * 2 + 2:
			ath.move_charge = moves[i * 2]
			ath.move_t = moves[i * 2 + 1]
		ath.spin_dir = -1 if flags & SPIN_LEFT_FLAG else 1
	var b: PackedFloat32Array = s["b"]
	w.ball.state = int(b[0])
	w.ball.holder_id = int(b[1])
	w.ball.position = Vector3(b[2], b[3], b[4])
	w.ball.velocity = Vector3(b[5], b[6], b[7])
	var d: PackedFloat32Array = s["d"]
	m.downs.offense_team = int(d[0])
	m.downs.down = int(d[1])
	m.downs.los = d[2]
	m.downs.first_down_y = d[3]
	var sc: PackedInt32Array = s["s"]
	m.score = [sc[0], sc[1]]
	var c: PackedFloat32Array = s["c"]
	m.clock.half = int(c[0])
	m.clock.remaining = c[1]
	m.clock.play_clock = c[2]
	m.clock.final = c[3] > 0.5
	if s.has("to"):
		m.clock.timeouts = Array(s["to"])
	m.state = s["ms"]
	m.try_points = s["tp"]
	w.play_name = str(s.get("pl", w.play_name))
	w.defensive_call = s.get("dc", "")
	w.run_flipped = s.get("rf", false)
	w.handoff_cooldown = s.get("hc", 0.0)
	var cs: PackedFloat32Array = s.get("cs", PackedFloat32Array([0, 0]))
	w.streak = int(cs[0])
	w.hold_t = cs[1]
	var rt: PackedInt32Array = s.get("rt", PackedInt32Array())
	w.route_of = {}
	for i in rt.size():
		if rt[i] >= 0 and rt[i] < Routes.ROUTE_NAMES.size():
			w.route_of[i] = Routes.ROUTE_NAMES[rt[i]]

static func _finite_v(v) -> bool:
	return v is Vector2 and is_finite(v.x) and is_finite(v.y)

## Client input -> safe dict, or {} if malformed.
static func sanitize_input(msg) -> Dictionary:
	if not (msg is Dictionary):
		return {}
	var dir = msg.get("dir", Vector2.ZERO)
	if not _finite_v(dir):
		dir = Vector2.ZERO
	var seq = msg.get("seq", 0)
	if not (seq is int) or seq < 0:
		seq = 0
	return {"dir": (dir as Vector2).limit_length(1.0), "sprint": msg.get("spr", false) == true, "seq": seq, "block": msg.get("block", false) == true}

static func sanitize_action(act) -> Dictionary:
	if not (act is Dictionary):
		return {}
	match act.get("a", ""):
		"snap", "tackle", "recall_call", "flip_play", "handoff", "timeout":
			return {"a": act["a"]}
		"dash", "spin":
			if act["a"] == "spin" and act.has("s"):   # Q / E: spin left (-1) / right (+1) of facing
				var side = act["s"]
				return {"a": "spin", "s": side} if side is int and (side == -1 or side == 1) else {}
			var dir = act.get("dir", Vector2.ZERO)
			return {"a": act["a"], "dir": dir.limit_length(1.0)} if _finite_v(dir) else {}
		"throw":
			var p = act.get("p", 0.0)
			if not (p is float or p is int) or not is_finite(float(p)):
				return {}
			if act.has("d"):   # POV throw: view direction + launch angle
				var d = act["d"]
				var ang = act.get("ang", 0.0)
				if not _finite_v(d) or (d as Vector2).length_squared() < 0.0001 or not (ang is float or ang is int) or not is_finite(float(ang)):
					return {}
				return {"a": "throw", "d": (d as Vector2).normalized(), "ang": clampf(float(ang), T.POV_ANGLE_MIN, T.POV_ANGLE_MAX),
					"p": clampf(float(p), 0.0, 1.0)}
			var t = act.get("t", Vector2.ZERO)
			if not _finite_v(t):
				return {}
			return {"a": act["a"], "t": t, "p": clampf(float(p), 0.0, 1.0), "lob": act.get("lob", false) == true}
		"emote":
			var e = act.get("e", "")
			return {"a": "emote", "e": e} if e is String and Emotes.has(e) else {}
		"try":
			var n = act.get("n", 1)
			return {"a": "try", "n": n} if n is int and (n == 1 or n == 2) else {}
		"play":
			var p = act.get("p", "")
			return {"a": "play", "p": p} if p is String and (Routes.PLAYBOOK.has(p) or Routes.RUN_PLAYS.has(p)) else {}
		"defense":
			var id = act.get("p", "")
			return {"a": "defense", "p": id} if id is String and DefensivePlaybook.CALLS.has(id) else {}
		"route":
			var r = act.get("r", "")
			return {"a": "route", "r": r} if r is String and Routes.ROUTES.has(r) else {}
	return {}

## Authoritative: perform `action` on behalf of `athlete_id`. Returns success.
static func apply_action(m, athlete_id: int, action: Dictionary) -> bool:
	var act := sanitize_action(action)
	if act.is_empty():
		return false
	var w = m.world
	var ath = w.get_athlete(athlete_id)
	if ath == null:
		return false
	match act["a"]:
		"snap":
			# One key, routed by side: offense hikes, defense breaks stance.
			if ath.team == w.offense_team:
				return w.snap()
			return w.break_stance(athlete_id)
		"tackle":
			return w.tackle(athlete_id)
		"dash", "spin":
			if act.has("s"):
				return w.spin(athlete_id, act["s"])
			return w.evade(athlete_id, act["a"] == "spin", act["dir"])
		"throw":
			if act.has("d"):   # POV throw: charge = power
				return w.throw_dir(athlete_id, act["d"], act["ang"], act["p"])
			return w.throw(athlete_id, act["t"], T.PLAYER_PASS_POWER, act["lob"], false)
		"emote":
			return w.emote(athlete_id, act["e"])
		"handoff":
			return w.handoff(athlete_id)
		"timeout":
			return m.call_timeout(ath.team)
		"try":
			return ath.team == w.offense_team and m.choose_try(act["n"])
		"play":
			return ath.team == w.offense_team and w.phase == w.Phase.PRESNAP and w.call_play(act["p"])
		"recall_call":
			return w.recall_call(ath.team)
		"flip_play":
			return ath.team == w.offense_team and w.flip_play()
		"defense":
			return ath.team != w.offense_team and w.call_defense(act["p"])
		"route":
			return w.phase == w.Phase.PRESNAP and w.set_route(athlete_id, act["r"])
	return false
