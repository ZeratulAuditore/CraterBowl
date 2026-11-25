extends RefCounted
## Public lobby registry for the server browser (matchmaker side). Pure.
## Hosts register/refresh their open lobby; entries expire if not refreshed.

const TTL := 20.0          # seconds without a refresh before a lobby disappears
const MAX_LISTED := 50

var lobbies := {}          # host key (peer id) -> entry

## info: {code, name, size, mode, players, max, in_game}. Returns false if malformed.
func register(key, info: Dictionary, now: float) -> bool:
	var code := str(info.get("code", ""))
	var size = info.get("size", 0)
	if code.length() < 7 or code.length() > 32 or not (size is int) or not ([3, 5, 7].has(size)):
		return false
	var mode := str(info.get("mode", "classic"))
	lobbies[key] = {
		"code": code,
		"name": str(info.get("name", "Match")).strip_edges().left(24),
		"size": size,
		"mode": mode if mode in ["classic", "chaosball"] else "classic",
		"players": clampi(int(info.get("players", 1)), 0, 14),
		"max": size * 2,
		"in_game": info.get("in_game", false) == true,
		"seen": now,
	}
	return true

func remove(key) -> void:
	lobbies.erase(key)

func expire(now: float) -> void:
	for k in lobbies.keys():
		if now - float(lobbies[k]["seen"]) > TTL:
			lobbies.erase(k)

## Open lobbies first, then fuller ones (more fun), then newest.
func listing(now: float) -> Array:
	expire(now)
	var rows := []
	for k in lobbies:
		var e: Dictionary = lobbies[k].duplicate()
		e.erase("seen")
		rows.append(e)
	rows.sort_custom(func(a, b):
		if a["in_game"] != b["in_game"]:
			return not a["in_game"]
		var fa: bool = a["players"] < a["max"]
		var fb: bool = b["players"] < b["max"]
		if fa != fb:
			return fa
		return a["players"] > b["players"])
	return rows.slice(0, MAX_LISTED)
