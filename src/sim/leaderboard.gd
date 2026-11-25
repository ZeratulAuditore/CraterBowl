extends RefCounted
## Career stats per player|POSITION and per-position rankings. JSON-backed.

const DEFAULT_PATH := "user://leaderboard.json"
const MAX_ROWS := 100

var careers := {}   # "player|POS" -> {"games": n, field: sum, ...}

## Merge one match's Stats.lines (bots skipped).
func record_match(lines: Dictionary) -> void:
	for k in lines:
		var player: String = k.get_slice("|", 0)
		if player == "Bot" or player == "":
			continue
		if not careers.has(k):
			careers[k] = {"games": 0}
		careers[k]["games"] += 1
		for f in lines[k]:
			careers[k][f] = careers[k].get(f, 0.0) + float(lines[k][f])

static func score(pos: String, l: Dictionary) -> float:
	var g := func(f): return float(l.get(f, 0.0))
	match pos:
		"QB":
			return g.call("pass_yds") + 20 * g.call("pass_td") - 25 * g.call("int_thrown") + g.call("rush_yds") + 20 * g.call("rush_td")
		"WR":
			return g.call("rec_yds") + 20 * g.call("rec_td") + 2 * g.call("rec")
		"RB":
			return g.call("rush_yds") + g.call("rec_yds") + 20 * (g.call("rush_td") + g.call("rec_td"))
		"C", "OL":
			return 2 * g.call("blk") + 5 * g.call("games")
		_:
			return 10 * g.call("tkl") + 25 * g.call("sack") + 40 * g.call("int") + 10 * g.call("pbu") + 25 * g.call("ff") + 25 * g.call("fr")

## Top rows for a position: [{player, score, games, line}], best first.
func top(pos: String, n: int = MAX_ROWS) -> Array:
	var rows := []
	for k in careers:
		if k.get_slice("|", 1) != pos:
			continue
		rows.append({"player": k.get_slice("|", 0), "score": score(pos, careers[k]), "games": int(careers[k]["games"]), "line": careers[k]})
	rows.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and a["games"] < b["games"]))
	return rows.slice(0, mini(n, MAX_ROWS))

func rank_of(player: String, pos: String) -> int:
	var rows := top(pos)
	for i in rows.size():
		if rows[i]["player"] == player:
			return i + 1
	return -1

func positions() -> Array:
	var out := []
	for k in careers:
		var p: String = k.get_slice("|", 1)
		if not out.has(p):
			out.append(p)
	out.sort()
	return out

func save(path: String = DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "careers": careers}))
	return true

func load_file(path: String = DEFAULT_PATH) -> void:
	careers = {}
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("careers") is Dictionary:
		careers = parsed["careers"]

func table_text(pos: String, n: int = 10) -> String:
	var out := ["%s leaderboard" % pos]
	var rows := top(pos, n)
	for i in rows.size():
		out.append("  #%d %-12s %7.1f  (%d games)" % [i + 1, rows[i]["player"], rows[i]["score"], rows[i]["games"]])
	return "\n".join(out)
