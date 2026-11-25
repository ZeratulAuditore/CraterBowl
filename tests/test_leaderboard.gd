extends "res://tests/test_case.gd"

const LB := preload("res://src/sim/leaderboard.gd")

func _line(fields: Dictionary) -> Dictionary:
	return fields

func test_scores() -> void:
	assert_near(LB.score("QB", {"pass_yds": 200, "pass_td": 2, "int_thrown": 1}), 215.0)
	assert_near(LB.score("WR", {"rec_yds": 80, "rec_td": 1, "rec": 5}), 110.0)
	assert_near(LB.score("CB", {"tkl": 3, "int": 1, "pbu": 2}), 90.0)
	assert_near(LB.score("OL", {"blk": 10, "games": 2}), 30.0)

func test_merge_and_bots_excluded() -> void:
	var lb := LB.new()
	lb.record_match({"Ann|QB": {"pass_yds": 100.0, "pass_td": 1.0}, "Bot|QB": {"pass_yds": 999.0}})
	lb.record_match({"Ann|QB": {"pass_yds": 50.0, "pass_td": 0.0}})
	assert_eq(int(lb.careers["Ann|QB"]["games"]), 2)
	assert_near(lb.careers["Ann|QB"]["pass_yds"], 150.0)
	assert_true(not lb.careers.has("Bot|QB"), "bots excluded")

func test_top_sorted_and_capped() -> void:
	var lb := LB.new()
	for i in 130:
		lb.record_match({"P%d|WR" % i: {"rec_yds": float(i)}})
	var rows := lb.top("WR")
	assert_eq(rows.size(), 100, "capped at 100")
	assert_eq(rows[0]["player"], "P129", "best first")
	assert_true(rows[0]["score"] >= rows[1]["score"])
	assert_eq(lb.rank_of("P129", "WR"), 1)
	assert_eq(lb.rank_of("nobody", "WR"), -1)
	assert_eq(lb.rank_of("P0", "WR"), -1, "outside top 100")

func test_save_load_round_trip() -> void:
	var path := "user://test_lb_roundtrip.json"
	var lb := LB.new()
	lb.record_match({"Ann|LB": {"tkl": 4.0, "sack": 1.0}})
	assert_true(lb.save(path))
	var lb2 := LB.new()
	lb2.load_file(path)
	assert_eq(lb2.rank_of("Ann", "LB"), 1)
	assert_near(LB.score("LB", lb2.careers["Ann|LB"]), 65.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var lb3 := LB.new()
	lb3.load_file("user://does_not_exist.json")
	assert_eq(lb3.careers.size(), 0, "missing file -> empty")
