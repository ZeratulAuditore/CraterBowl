extends RefCounted
## Team slots (two-way athletes) owned by humans or bots. Pure.

const Athlete := preload("res://src/sim/athlete.gd")
const R := Athlete.Role

## Offense/defense pairing per slot index, in auto-assign priority order.
const PAIRS := [
	[R.QB, 0.0, R.LB, 0.0], [R.WR, -18.0, R.CB, -18.0], [R.WR, 18.0, R.CB, 18.0], [R.RB, 4.0, R.S, -8.0],
	[R.C, 0.0, R.DL, -1.5], [R.OL, -2.5, R.DL, 1.5], [R.OL, 2.5, R.S, 8.0],
]
const ROLE_NAMES := {R.QB: "QB", R.C: "C", R.WR: "WR", R.RB: "RB", R.LB: "LB", R.CB: "CB", R.S: "S", R.OL: "OL", R.DL: "DL"}

var slots: Array = []   # [{team, athlete_id, owner, off_role, def_role}]

## Create both teams' athletes in `world` and their slots.
func build(world) -> void:
	var cx: float = world.field.width / 2.0
	slots.clear()
	for t in 2:
		for p in PAIRS:
			var a = world.add_two_way(t, p[0], cx + p[1], p[2], cx + p[3])
			slots.append({"team": t, "athlete_id": a.id, "owner": -1, "off_role": p[0], "def_role": p[2]})

func slot_of_player(player: int) -> int:
	for i in slots.size():
		if slots[i]["owner"] == player:
			return i
	return -1

func slot_of_athlete(aid: int) -> int:
	for i in slots.size():
		if slots[i]["athlete_id"] == aid:
			return i
	return -1

func athlete_of(player: int) -> int:
	var s := slot_of_player(player)
	return slots[s]["athlete_id"] if s >= 0 else -1

func humans_on(team: int) -> int:
	var n := 0
	for s in slots:
		if s["team"] == team and s["owner"] >= 0:
			n += 1
	return n

func humans() -> Array:
	var out := []
	for s in slots:
		if s["owner"] >= 0:
			out.append(s["athlete_id"])
	return out

func release(player: int) -> void:
	var s := slot_of_player(player)
	if s >= 0:
		slots[s]["owner"] = -1

func claim(player: int, slot: int) -> bool:
	if slot < 0 or slot >= slots.size():
		return false
	if slots[slot]["owner"] == player:
		return true
	if slots[slot]["owner"] >= 0:
		return false
	release(player)
	slots[slot]["owner"] = player
	return true

func _first_free(team: int, prefer_off_role: int = -1) -> int:
	if prefer_off_role >= 0:
		for i in slots.size():
			if slots[i]["team"] == team and slots[i]["owner"] < 0 and slots[i]["off_role"] == prefer_off_role:
				return i
	for i in slots.size():
		if slots[i]["team"] == team and slots[i]["owner"] < 0:
			return i
	return -1

## Join the team with fewer humans (ties -> team 0), best free slot. Returns athlete id or -1.
func auto_assign(player: int) -> int:
	var team := 0 if humans_on(0) <= humans_on(1) else 1
	var s := _first_free(team)
	if s < 0:
		s = _first_free(1 - team)
	if s < 0 or not claim(player, s):
		return -1
	return slots[s]["athlete_id"]

func swap_team(player: int) -> int:
	var cur := slot_of_player(player)
	if cur < 0:
		return -1
	var s := _first_free(1 - slots[cur]["team"], slots[cur]["off_role"])
	if s < 0 or not claim(player, s):
		return -1
	return slots[s]["athlete_id"]

## Next free slot on the player's team after the current one (wraps). Returns athlete id or -1.
func cycle_position(player: int) -> int:
	var cur := slot_of_player(player)
	if cur < 0:
		return -1
	var team: int = slots[cur]["team"]
	for k in range(1, slots.size()):
		var i := (cur + k) % slots.size()
		if slots[i]["team"] == team and slots[i]["owner"] < 0:
			claim(player, i)
			return slots[i]["athlete_id"]
	return slots[cur]["athlete_id"]

func label(slot: int) -> String:
	if slot < 0:
		return "-"
	return "%s/%s" % [ROLE_NAMES[slots[slot]["off_role"]], ROLE_NAMES[slots[slot]["def_role"]]]
