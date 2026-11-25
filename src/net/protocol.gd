extends RefCounted
## Wire protocol: snapshot codec, input sanitizing, authoritative action routing. Pure.

const DIVE_FLAG := 1
const GROUND_FLAG := 2

static func encode_snapshot(m, tick: int) -> Dictionary:
	var w = m.world
	var a := PackedFloat32Array()
	var r := PackedInt32Array()
	for ath in w.athletes:
		a.append_array([ath.position.x, ath.position.y, ath.velocity.x, ath.velocity.y, ath.facing.x, ath.facing.y, ath.stamina])
		var flags := (DIVE_FLAG if ath.is_diving() else 0) | (GROUND_FLAG if ath.is_grounded() else 0)
		r.append_array([ath.role, flags, ath.team])
	var b = w.ball
	return {
		"k": "snap", "t": tick, "ph": w.phase, "off": w.offense_team, "los": w.los_y, "fpt": w.forward_pass_thrown,
		"a": a, "r": r,
		"b": PackedFloat32Array([b.state, b.holder_id, b.position.x, b.position.y, b.position.z, b.velocity.x, b.velocity.y, b.velocity.z]),
		"d": PackedFloat32Array([m.downs.offense_team, m.downs.down, m.downs.los, m.downs.first_down_y]),
		"s": PackedInt32Array(m.score),
		"c": PackedFloat32Array([m.clock.half, m.clock.remaining, m.clock.play_clock, 1.0 if m.clock.final else 0.0]),
		"ms": m.state, "tp": m.try_points,
	}

static func apply_snapshot(m, s: Dictionary) -> void:
	var w = m.world
	w.phase = s["ph"]
	w.offense_team = s["off"]
	w.los_y = s["los"]
	w.forward_pass_thrown = s["fpt"]
	var a: PackedFloat32Array = s["a"]
	var r: PackedInt32Array = s["r"]
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
	m.state = s["ms"]
	m.try_points = s["tp"]

static func _finite_v(v) -> bool:
	return v is Vector2 and is_finite(v.x) and is_finite(v.y)

## Client input -> safe dict, or {} if malformed.
static func sanitize_input(msg) -> Dictionary:
	if not (msg is Dictionary):
		return {}
	var dir = msg.get("dir", Vector2.ZERO)
	if not _finite_v(dir):
		dir = Vector2.ZERO
	return {"dir": (dir as Vector2).limit_length(1.0), "sprint": msg.get("spr", false) == true}

static func sanitize_action(act) -> Dictionary:
	if not (act is Dictionary):
		return {}
	match act.get("a", ""):
		"snap", "tackle":
			return {"a": act["a"]}
		"throw":
			var t = act.get("t", Vector2.ZERO)
			var p = act.get("p", 0.0)
			if not _finite_v(t) or not (p is float or p is int) or not is_finite(float(p)):
				return {}
			return {"a": "throw", "t": t, "p": clampf(float(p), 0.0, 1.0)}
		"try":
			var n = act.get("n", 1)
			return {"a": "try", "n": n} if n is int and (n == 1 or n == 2) else {}
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
			return ath.team == w.offense_team and w.snap()
		"tackle":
			return w.tackle(athlete_id)
		"throw":
			return w.throw(athlete_id, act["t"], act["p"])
		"try":
			return ath.team == w.offense_team and m.choose_try(act["n"])
	return false
