extends "res://tests/test_case.gd"

const Ranked := preload("res://src/sim/ranked.gd")
const World := preload("res://src/sim/world.gd")
const Roster := preload("res://src/sim/roster.gd")

func test_equal_teams_win_loss_tie() -> void:
	var r := Ranked.new()
	var d := r.record_match(["A", "B"], ["C", "D"], 1.0)
	assert_near(d["A"], Ranked.K_PROVISIONAL / 2.0, 0.001, "winner +K/2")
	assert_near(d["C"], -Ranked.K_PROVISIONAL / 2.0, 0.001, "loser -K/2")
	var r2 := Ranked.new()
	var t := r2.record_match(["A"], ["B"], 0.5)
	assert_near(t["A"], 0.0, 0.001, "tie between equals")

func test_upset_gains_more() -> void:
	var r := Ranked.new()
	r.get_player("Pro")["rating"] = 1600.0
	var upset := r.record_match(["Rookie"], ["Pro"], 1.0)
	var r2 := Ranked.new()
	r2.get_player("Pro")["rating"] = 1600.0
	var expected_win := r2.record_match(["Pro"], ["Rookie"], 1.0)
	assert_true(upset["Rookie"] > expected_win["Pro"] * 3.0, "upset %.1f vs expected %.1f" % [upset["Rookie"], expected_win["Pro"]])

func test_provisional_k() -> void:
	var r := Ranked.new()
	for i in Ranked.PROVISIONAL_GAMES:
		r.record_match(["A"], ["B"], 0.5)
	var d := r.record_match(["A"], ["B"], 1.0)
	assert_near(absf(d["A"]), Ranked.K / 2.0, 0.5, "after 10 games K=32")

func test_tiers() -> void:
	assert_eq(Ranked.tier(1000), "Bronze")
	assert_eq(Ranked.tier(1100), "Silver")
	assert_eq(Ranked.tier(1499), "Gold")
	assert_eq(Ranked.tier(1500), "Platinum")
	assert_eq(Ranked.tier(2200), "Legend")

func test_season_rollover() -> void:
	var r := Ranked.new()
	r.ensure_season(8100)
	r.record_match(["A"], ["B"], 1.0)
	r.get_player("A")["rating"] = 1400.0
	r.get_player("A")["peak"] = 1550.0
	r.ensure_season(8101)
	assert_eq(r.rewards["A"], ["S8100-Platinum"], "reward from peak tier")
	assert_near(r.rating("A"), 1200.0, 0.001, "soft reset halfway")
	assert_eq(int(r.get_player("A")["games"]), 0)
	assert_eq(Ranked.season_id(0), 1970 * 4, "season id from date")

func test_store_round_trip() -> void:
	var path := "user://test_ranked_rt.json"
	var r := Ranked.new()
	r.ensure_season(8100)
	r.record_match(["A"], ["B"], 1.0)
	assert_true(r.save(path))
	var r2 := Ranked.new()
	r2.load_file(path)
	assert_near(r2.rating("A"), r.rating("A"), 0.001)
	assert_eq(r2.season, 8100)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_roster_assign_team() -> void:
	var w := World.new()
	var ro := Roster.new()
	ro.build(w, 3)
	var aid := ro.auto_assign_team(5, 1)
	assert_eq(w.get_athlete(aid).team, 1, "seated on requested team")
	for p in [6, 7]:
		ro.auto_assign_team(p, 1)
	var spill := ro.auto_assign_team(8, 1)
	assert_eq(w.get_athlete(spill).team, 0, "falls back when full")
