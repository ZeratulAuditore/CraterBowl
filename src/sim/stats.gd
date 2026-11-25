extends RefCounted
## Per-owner, per-position match stats from World events. Pure.

const Athlete := preload("res://src/sim/athlete.gd")
const ROLE := {0: "QB", 1: "C", 2: "WR", 3: "RB", 4: "LB", 5: "CB", 6: "S", 7: "OL", 8: "DL"}
const FIELDS := ["att", "comp", "pass_yds", "pass_td", "int_thrown", "rec", "rec_yds", "rec_td",
	"car", "rush_yds", "rush_td", "tkl", "sack", "int", "pbu", "ff", "fr", "pts"]

var world
var owner_fn: Callable     # athlete_id -> owner name ("Bot" for AI)
var lines := {}            # "owner|POS" -> {field: value}
var _los := 0.0
var _passer := -1
var _receiver := -1
var _thrown := false

func attach(w, owner: Callable) -> void:
	world = w
	owner_fn = owner
	w.event.connect(_on_event)

func _key(aid: int) -> String:
	var a = world.get_athlete(aid)
	var owner: String = owner_fn.call(aid) if owner_fn.is_valid() else "Bot"
	return "%s|%s" % [owner, ROLE.get(a.role if a else -1, "?")]

func _add(aid: int, field: String, v: float = 1.0) -> void:
	if aid < 0 or world.get_athlete(aid) == null:
		return
	var k := _key(aid)
	if not lines.has(k):
		lines[k] = {}
		for f in FIELDS:
			lines[k][f] = 0.0
	lines[k][field] += v

func _on_event(n: String, d: Dictionary) -> void:
	match n:
		"snap":
			_los = world.los_y
			_passer = -1
			_receiver = -1
			_thrown = false
		"throw":
			if not _thrown:
				_passer = d["by"]
			_thrown = true
			_add(d["by"], "att")
		"catch":
			if _passer >= 0 and world.get_athlete(d["by"]).team == world.get_athlete(_passer).team:
				_receiver = d["by"]
				_add(_passer, "comp")
				_add(_receiver, "rec")
		"interception":
			if _passer >= 0:
				_add(_passer, "int_thrown")
			_add(d["by"], "int")
		"breakup":
			_add(d["by"], "pbu")
		"fumble":
			_add(d["by"], "ff")
		"recovery":
			_add(d["by"], "fr")
		"tackle", "out_of_bounds", "touchdown":
			_end_play(n, d)

func _end_play(n: String, d: Dictionary) -> void:
	var carrier: int = d.get("carrier", -1)
	if carrier < 0:
		return
	var c = world.get_athlete(carrier)
	var on_offense: bool = c.team == world.offense_team
	if n == "tackle":
		_add(d.get("by", -1), "tkl")
	var gain: float = d["spot"].y - _los if on_offense else 0.0
	if n == "touchdown" and on_offense:
		gain = world.field.length - _los
	if n == "tackle" and c.role == Athlete.Role.QB and not _thrown and on_offense and d["spot"].y < _los:
		_add(d.get("by", -1), "sack")
		return
	if not on_offense:
		if n == "touchdown":
			_add(carrier, "pts", d.get("points", 6))
		return   # return yards not tracked yet
	if _receiver >= 0 and carrier == _receiver:
		_add(_passer, "pass_yds", gain)
		_add(_receiver, "rec_yds", gain)
		if n == "touchdown":
			_add(_passer, "pass_td")
			_add(_receiver, "rec_td")
	elif not _thrown:
		_add(carrier, "car")
		_add(carrier, "rush_yds", gain)
		if n == "touchdown":
			_add(carrier, "rush_td")
	if n == "touchdown":
		_add(carrier, "pts", d.get("points", 6))

func get_line(owner: String, pos: String) -> Dictionary:
	return lines.get("%s|%s" % [owner, pos], {})

func total(field: String) -> float:
	var t := 0.0
	for k in lines:
		t += lines[k][field]
	return t

func to_dict() -> Dictionary:
	return lines.duplicate(true)

## Compact human-readable lines for every non-bot owner + bot totals.
func summary_lines() -> Array:
	var out := []
	var keys := lines.keys()
	keys.sort()
	for k in keys:
		var l: Dictionary = lines[k]
		var parts := []
		if l["att"] > 0: parts.append("%d/%d %dyd %dTD %dINT" % [l["comp"], l["att"], l["pass_yds"], l["pass_td"], l["int_thrown"]])
		if l["rec"] > 0: parts.append("%d rec %dyd %dTD" % [l["rec"], l["rec_yds"], l["rec_td"]])
		if l["car"] > 0: parts.append("%d car %dyd %dTD" % [l["car"], l["rush_yds"], l["rush_td"]])
		var dfn := []
		for f in ["tkl", "sack", "int", "pbu", "ff", "fr"]:
			if l[f] > 0: dfn.append("%d %s" % [l[f], f])
		if not dfn.is_empty(): parts.append(", ".join(dfn))
		if parts.is_empty():
			continue
		out.append("%s %s: %s" % [k.get_slice("|", 0), k.get_slice("|", 1), " | ".join(parts)])
	return out
