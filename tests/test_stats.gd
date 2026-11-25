extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const Stats := preload("res://src/sim/stats.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const AI := preload("res://src/sim/ai.gd")
const DT := 1.0 / 60.0
const R := Athlete.Role

var owners := {}

func _setup() -> Array:
	owners = {}
	var w := World.new()
	Roster.new().build(w, 7)
	var m := Match.new(w)
	m.start(0, 25.0)
	var s := Stats.new()
	s.attach(w, func(aid): return owners.get(aid, "Bot"))
	return [w, m, s]

func _ids(w) -> Dictionary:
	return {"qb": w.find_role(0, R.QB).id, "wr": w.find_role(0, R.WR).id, "rb": w.find_role(0, R.RB).id,
		"lb": w.find_role(1, R.LB).id, "cb": w.find_role(1, R.CB).id}

func test_completion_line() -> void:
	var r := _setup()
	var w: World = r[0]
	var s: Stats = r[2]
	var i := _ids(w)
	owners[i["qb"]] = "Ann"
	owners[i["wr"]] = "Ben"
	w.event.emit("snap", {"qb": i["qb"]})
	w.event.emit("throw", {"by": i["qb"]})
	w.event.emit("catch", {"by": i["wr"]})
	w.event.emit("tackle", {"by": i["lb"], "carrier": i["wr"], "spot": Vector2(20, 37), "team": 0})
	var qb := s.get_line("Ann", "QB")
	assert_eq(int(qb["comp"]), 1)
	assert_eq(int(qb["att"]), 1)
	assert_near(qb["pass_yds"], 12.0)
	var wr := s.get_line("Ben", "WR")
	assert_eq(int(wr["rec"]), 1)
	assert_near(wr["rec_yds"], 12.0)
	assert_eq(int(s.get_line("Bot", "LB")["tkl"]), 1)

func test_incomplete_int_breakup() -> void:
	var r := _setup()
	var w: World = r[0]
	var s: Stats = r[2]
	var i := _ids(w)
	w.event.emit("snap", {})
	w.event.emit("throw", {"by": i["qb"]})
	w.event.emit("breakup", {"by": i["cb"]})
	w.event.emit("snap", {})
	w.event.emit("throw", {"by": i["qb"]})
	w.event.emit("interception", {"by": i["cb"]})
	var qb := s.get_line("Bot", "QB")
	assert_eq(int(qb["att"]), 2)
	assert_eq(int(qb["comp"]), 0)
	assert_eq(int(qb["int_thrown"]), 1)
	var cb := s.get_line("Bot", "CB")
	assert_eq(int(cb["pbu"]), 1)
	assert_eq(int(cb["int"]), 1)

func test_sack_and_run_and_td() -> void:
	var r := _setup()
	var w: World = r[0]
	var s: Stats = r[2]
	var i := _ids(w)
	w.event.emit("snap", {})
	w.event.emit("tackle", {"by": i["lb"], "carrier": i["qb"], "spot": Vector2(26, 19), "team": 0})
	assert_eq(int(s.get_line("Bot", "LB")["sack"]), 1, "sack")
	assert_eq(int(s.get_line("Bot", "QB").get("car", 0)), 0, "sack isn't a carry")
	w.event.emit("snap", {})
	w.event.emit("tackle", {"by": i["lb"], "carrier": i["rb"], "spot": Vector2(26, 31), "team": 0})
	var rb := s.get_line("Bot", "RB")
	assert_eq(int(rb["car"]), 1)
	assert_near(rb["rush_yds"], 6.0)
	w.event.emit("snap", {})
	w.event.emit("touchdown", {"carrier": i["rb"], "spot": Vector2(26, 101), "team": 0, "points": 6})
	rb = s.get_line("Bot", "RB")
	assert_eq(int(rb["rush_td"]), 1)
	assert_eq(int(rb["pts"]), 6)

func test_passing_td_and_fumble() -> void:
	var r := _setup()
	var w: World = r[0]
	var s: Stats = r[2]
	var i := _ids(w)
	w.event.emit("snap", {})
	w.event.emit("throw", {"by": i["qb"]})
	w.event.emit("catch", {"by": i["wr"]})
	w.event.emit("touchdown", {"carrier": i["wr"], "spot": Vector2(20, 101), "team": 0, "points": 6})
	assert_eq(int(s.get_line("Bot", "QB")["pass_td"]), 1)
	assert_eq(int(s.get_line("Bot", "WR")["rec_td"]), 1)
	assert_near(s.get_line("Bot", "WR")["rec_yds"], 75.0, 0.001, "100 - LOS 25")
	w.event.emit("fumble", {"carrier": i["wr"], "by": i["lb"]})
	w.event.emit("recovery", {"by": i["cb"], "team": 1})
	assert_eq(int(s.get_line("Bot", "LB")["ff"]), 1)
	assert_eq(int(s.get_line("Bot", "CB")["fr"]), 1)

func test_owner_change_splits_lines() -> void:
	var r := _setup()
	var w: World = r[0]
	var s: Stats = r[2]
	var i := _ids(w)
	owners[i["wr"]] = "Cy"
	w.event.emit("snap", {})
	w.event.emit("throw", {"by": i["qb"]})
	w.event.emit("catch", {"by": i["wr"]})
	owners.erase(i["wr"])   # Cy switches away; a bot takes the WR
	w.event.emit("snap", {})
	w.event.emit("throw", {"by": i["qb"]})
	w.event.emit("catch", {"by": i["wr"]})
	assert_eq(int(s.get_line("Cy", "WR")["rec"]), 1)
	assert_eq(int(s.get_line("Bot", "WR")["rec"]), 1)

func test_bot_game_consistency() -> void:
	var r := _setup()
	var w: World = r[0]
	var m: Match = r[1]
	var s: Stats = r[2]
	var ai := AI.new()
	var dead_t := 0.0
	for k in int(180.0 / DT):
		m.tick(DT)
		ai.presnap_tick(w, [], DT, m.downs.down, m.downs.distance())
		w.step(ai.think(w, []), DT)
		if w.phase == World.Phase.DEAD:
			dead_t += DT
			if dead_t > 0.5:
				m.next_play()
				dead_t = 0.0
	assert_true(s.total("att") >= 5, "passes tracked (%d)" % s.total("att"))
	assert_true(s.total("comp") <= s.total("att"))
	assert_near(s.total("pass_yds"), s.total("rec_yds"), 0.01, "pass yds == rec yds")
	assert_eq(int(s.total("comp")), int(s.total("rec")))
	assert_true(not s.summary_lines().is_empty(), "summary")
	for l in s.summary_lines():
		print("    " + l)
