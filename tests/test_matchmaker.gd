extends "res://tests/test_case.gd"

const MM := preload("res://src/net/matchmaker.gd")

func test_casual_full_match_immediate() -> void:
	var mm := MM.new()
	for i in 6:
		mm.enqueue(i + 1, "casual", 3, 1000, 0.0)
	var ms := mm.tick(0.1)
	assert_eq(ms.size(), 1)
	assert_eq(ms[0]["players"].size(), 6)
	assert_eq(ms[0]["host"], 1, "longest waiting hosts")
	assert_eq(mm.queue.size(), 0)

func test_casual_small_waits_then_starts() -> void:
	var mm := MM.new()
	mm.enqueue(1, "casual", 7, 1000, 0.0)
	mm.enqueue(2, "casual", 7, 1000, 1.0)
	assert_eq(mm.tick(5.0).size(), 0, "not yet")
	var ms := mm.tick(MM.CASUAL_WAIT + 0.1)
	assert_eq(ms.size(), 1, "starts with 2 + bots")
	assert_eq(ms[0]["players"].size(), 2)

func test_single_player_never_matches() -> void:
	var mm := MM.new()
	mm.enqueue(1, "casual", 5, 1000, 0.0)
	assert_eq(mm.tick(999.0).size(), 0)

func test_competitive_rating_window() -> void:
	var mm := MM.new()
	mm.enqueue(1, "competitive", 3, 1000, 0.0)
	mm.enqueue(2, "competitive", 3, 1500, 0.0)
	assert_eq(mm.tick(MM.COMP_WAIT + 0.5).size(), 0, "500 apart: window %.1f too small" % MM.window_for(MM.COMP_WAIT + 0.5))
	var later := (500.0 - MM.BASE_WINDOW) / MM.WINDOW_GROWTH + 0.5
	assert_eq(mm.tick(later).size(), 1, "window widened")

func test_competitive_close_ratings() -> void:
	var mm := MM.new()
	mm.enqueue(1, "competitive", 5, 1000, 0.0)
	mm.enqueue(2, "competitive", 5, 1050, 0.0)
	assert_eq(mm.tick(5.0).size(), 0, "waits for more")
	assert_eq(mm.tick(MM.COMP_WAIT + 0.1).size(), 1)

func test_modes_and_sizes_never_mix() -> void:
	var mm := MM.new()
	mm.enqueue(1, "casual", 3, 1000, 0.0)
	mm.enqueue(2, "competitive", 3, 1000, 0.0)
	mm.enqueue(3, "casual", 5, 1000, 0.0)
	assert_eq(mm.tick(100.0).size(), 0)
	assert_true(not mm.enqueue(4, "ranked-ish", 3, 1000, 0.0), "bad mode")
	assert_true(not mm.enqueue(4, "casual", 4, 1000, 0.0), "bad size")

func test_snake_draft_balances() -> void:
	var entries := []
	var ratings := [1900, 1700, 1500, 1300, 1100, 900]
	for i in ratings.size():
		entries.append({"id": i, "rating": ratings[i]})
	var teams := MM.snake_teams(entries)
	var sums := [0, 0]
	for i in ratings.size():
		sums[teams[i]] += ratings[i]
	assert_true(absf(sums[0] - sums[1]) <= 400, "balanced: %s" % str(sums))

func test_requeue_replaces() -> void:
	var mm := MM.new()
	mm.enqueue(1, "casual", 3, 1000, 0.0)
	mm.enqueue(1, "casual", 5, 1000, 1.0)
	assert_eq(mm.queue.size(), 1, "no duplicates")
	mm.dequeue(1)
	assert_eq(mm.queue.size(), 0)

func test_party_waits_for_all_members() -> void:
	var mm2 := MM.new()
	mm2.enqueue(1, "casual", 3, 1000, 0.0, "Ann", "FRIENDS", 2)
	assert_eq(mm2.tick(100.0).size(), 0, "incomplete party never matches")
	mm2.enqueue(2, "casual", 3, 1000, 1.0, "Ben", "FRIENDS", 2)
	var ms := mm2.tick(100.0)
	assert_eq(ms.size(), 1, "complete party of 2 plays (co-op vs bots after wait)")
	assert_eq(ms[0]["teams"][1], ms[0]["teams"][2], "party on the same team")

func test_party_never_split() -> void:
	var mm := MM.new()
	mm.enqueue(1, "casual", 3, 1000, 0.0, "A", "P1", 3)
	mm.enqueue(2, "casual", 3, 1000, 0.0, "B", "P1", 3)
	mm.enqueue(3, "casual", 3, 1000, 0.0, "C", "P1", 3)
	mm.enqueue(4, "casual", 3, 1000, 0.0, "D")
	mm.enqueue(5, "casual", 3, 1000, 0.0, "E")
	mm.enqueue(6, "casual", 3, 1000, 0.0, "F")
	var ms := mm.tick(0.1)
	assert_eq(ms.size(), 1, "full 3v3")
	var t: Dictionary = ms[0]["teams"]
	assert_true(t[1] == t[2] and t[2] == t[3], "party of 3 together")
	assert_true(t[4] == t[5] and t[5] == t[6] and t[4] != t[1], "solos on the other team")

func test_party_too_big_rejected() -> void:
	var mm := MM.new()
	assert_true(not mm.enqueue(1, "casual", 3, 1000, 0.0, "A", "BIG", 4), "party of 4 can't fit a 3v3 team")
	assert_true(not mm.enqueue(1, "casual", 3, 1000, 0.0, "A", "ONE", 1), "party needs 2+")

func test_competitive_party_uses_avg_rating() -> void:
	var mm := MM.new()
	mm.enqueue(1, "competitive", 3, 1400, 0.0, "A", "DUO", 2)
	mm.enqueue(2, "competitive", 3, 1000, 0.0, "B", "DUO", 2)   # duo avg 1200
	mm.enqueue(3, "competitive", 3, 1250, 0.0, "C")
	assert_eq(mm.tick(MM.COMP_WAIT + 0.1).size(), 1, "solo within window of duo avg")
