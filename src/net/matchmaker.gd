extends RefCounted
## Queue rules (pure). Players: {id, mode, size, rating, since}.

const CASUAL_WAIT := 8.0
const COMP_WAIT := 15.0
const BASE_WINDOW := 100.0
const WINDOW_GROWTH := 25.0   # rating points per second waited
const MAX_WINDOW := 600.0
const MODES := ["casual", "competitive"]

var queue: Array = []

func enqueue(id: int, mode: String, size: int, rating: float, now: float) -> bool:
	if not MODES.has(mode) or not [3, 5, 7].has(size):
		return false
	dequeue(id)
	queue.append({"id": id, "mode": mode, "size": size, "rating": rating, "since": now})
	return true

func dequeue(id: int) -> void:
	for i in range(queue.size() - 1, -1, -1):
		if queue[i]["id"] == id:
			queue.remove_at(i)

static func window_for(waited: float) -> float:
	return minf(BASE_WINDOW + WINDOW_GROWTH * waited, MAX_WINDOW)

## Form as many matches as the rules allow at time `now`.
func tick(now: float) -> Array:
	var out := []
	var formed := true
	while formed:
		formed = false
		for mode in MODES:
			for size in [3, 5, 7]:
				var m := _try_form(mode, size, now)
				if not m.is_empty():
					out.append(m)
					for p in m["players"]:
						dequeue(p)
					formed = true
	return out

func _group(mode: String, size: int) -> Array:
	var g := []
	for e in queue:
		if e["mode"] == mode and e["size"] == size:
			g.append(e)
	g.sort_custom(func(a, b): return a["since"] < b["since"])
	return g

func _try_form(mode: String, size: int, now: float) -> Dictionary:
	var g := _group(mode, size)
	if g.size() < 2:
		return {}
	var full := size * 2
	var oldest: Dictionary = g[0]
	var waited: float = now - oldest["since"]
	var picked := []
	if mode == "casual":
		if g.size() >= full:
			picked = g.slice(0, full)
		elif waited >= CASUAL_WAIT:
			picked = g
	else:
		var w := window_for(waited)
		var cands := []
		for e in g:
			if absf(e["rating"] - oldest["rating"]) <= w:
				cands.append(e)
		cands.sort_custom(func(a, b): return absf(a["rating"] - oldest["rating"]) < absf(b["rating"] - oldest["rating"]))
		if cands.size() >= full:
			picked = cands.slice(0, full)
		elif waited >= COMP_WAIT and cands.size() >= 2:
			picked = cands
	if picked.size() < 2:
		return {}
	var ids := []
	for e in picked:
		ids.append(e["id"])
	return {"mode": mode, "size": size, "players": ids, "host": oldest["id"], "teams": snake_teams(picked)}

## Snake draft by rating (highest first): A B B A A B B A ...
static func snake_teams(entries: Array) -> Dictionary:
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a, b): return a["rating"] > b["rating"])
	var teams := {}
	for i in sorted.size():
		var r := i % 4
		teams[sorted[i]["id"]] = 0 if (r == 0 or r == 3) else 1
	return teams
