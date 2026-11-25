extends RefCounted
## Ratings, tiers, seasons, season rewards. JSON-backed.

const DEFAULT_PATH := "user://ranked.json"
const START := 1000.0
const K := 32.0
const K_PROVISIONAL := 48.0
const PROVISIONAL_GAMES := 10
const TIERS := [[1900.0, "Legend"], [1700.0, "Diamond"], [1500.0, "Platinum"], [1300.0, "Gold"], [1100.0, "Silver"], [-INF, "Bronze"]]

var season := 0
var players := {}   # name -> {"rating", "peak", "games", "wins"}
var rewards := {}   # name -> [reward ids]

static func season_id(unix_time: float) -> int:
	var d := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return int(d["year"]) * 4 + (int(d["month"]) - 1) / 3

static func tier(rating: float) -> String:
	for t in TIERS:
		if rating >= t[0]:
			return t[1]
	return "Bronze"

func get_player(name: String) -> Dictionary:
	if not players.has(name):
		players[name] = {"rating": START, "peak": START, "games": 0, "wins": 0}
	return players[name]

func rating(name: String) -> float:
	return float(get_player(name)["rating"])

## Roll to `new_season`: peak tier -> reward, soft reset halfway to START.
func ensure_season(new_season: int) -> void:
	if season == 0:
		season = new_season
		return
	if new_season == season:
		return
	for name in players:
		var p: Dictionary = players[name]
		if int(p["games"]) > 0:
			if not rewards.has(name):
				rewards[name] = []
			rewards[name].append("S%d-%s" % [season, tier(p["peak"])])
		p["rating"] = START + (float(p["rating"]) - START) * 0.5
		p["peak"] = p["rating"]
		p["games"] = 0
		p["wins"] = 0
	season = new_season

## result_a: 1 win for team A, 0 loss, 0.5 tie. Returns {name: delta}.
func record_match(team_a: Array, team_b: Array, result_a: float) -> Dictionary:
	if team_a.is_empty() or team_b.is_empty():
		return {}
	var avg := func(team): 
		var s := 0.0
		for n in team: s += rating(n)
		return s / team.size()
	var ra: float = avg.call(team_a)
	var rb: float = avg.call(team_b)
	var exp_a := 1.0 / (1.0 + pow(10.0, (rb - ra) / 400.0))
	var deltas := {}
	for side in [[team_a, result_a, exp_a], [team_b, 1.0 - result_a, 1.0 - exp_a]]:
		for n in side[0]:
			var p := get_player(n)
			var k := K_PROVISIONAL if int(p["games"]) < PROVISIONAL_GAMES else K
			var d: float = k * (side[1] - side[2])
			p["rating"] = float(p["rating"]) + d
			p["peak"] = maxf(float(p["peak"]), float(p["rating"]))
			p["games"] = int(p["games"]) + 1
			if side[1] > 0.5:
				p["wins"] = int(p["wins"]) + 1
			deltas[n] = d
	return deltas

func save(path: String = DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": 1, "season": season, "players": players, "rewards": rewards}))
	return true

func load_file(path: String = DEFAULT_PATH) -> void:
	season = 0
	players = {}
	rewards = {}
	if not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		season = int(d.get("season", 0))
		players = d.get("players", {}) if d.get("players") is Dictionary else {}
		rewards = d.get("rewards", {}) if d.get("rewards") is Dictionary else {}

func label(name: String) -> String:
	var p := get_player(name)
	return "%d %s (%d-%d)" % [int(round(p["rating"])), tier(p["rating"]), int(p["wins"]), int(p["games"]) - int(p["wins"])]
