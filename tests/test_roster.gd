extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Roster := preload("res://src/sim/roster.gd")
const Athlete := preload("res://src/sim/athlete.gd")

func _roster() -> Roster:
	var w := World.new()
	var r := Roster.new()
	r.build(w)
	return r

func test_builds_7v7() -> void:
	var r := _roster()
	assert_eq(r.slots.size(), 14)
	assert_eq(r.label(0), "QB/LB")

func test_auto_assign_balances_and_prefers_qb() -> void:
	var r := _roster()
	var a := r.auto_assign(100)
	var b := r.auto_assign(101)
	assert_eq(r.slots[r.slot_of_player(100)]["team"], 0, "first -> team 0")
	assert_eq(r.slots[r.slot_of_player(101)]["team"], 1, "second -> team 1")
	assert_eq(r.slots[r.slot_of_player(100)]["off_role"], Athlete.Role.QB, "QB first")
	assert_eq(r.slots[r.slot_of_player(101)]["off_role"], Athlete.Role.QB, "QB first on other side too")
	r.auto_assign(102)
	assert_eq(r.humans_on(0), 2, "third balances to team 0")
	assert_true(a != b)

func test_claim_conflict_and_release() -> void:
	var r := _roster()
	r.auto_assign(1)
	var s := r.slot_of_player(1)
	r.auto_assign(2)
	var requester_slot := r.slot_of_player(2)
	assert_true(requester_slot >= 0 and requester_slot != s, "both players start assigned")
	assert_true(not r.claim(2, s), "occupied")
	assert_eq(r.slot_of_player(1), s, "current owner keeps the slot")
	assert_eq(r.slot_of_player(2), requester_slot, "requester keeps their previous slot")
	r.release(1)
	assert_true(r.claim(2, s), "free after release")
	assert_eq(r.slot_of_player(2), s, "requester moves to the released slot")
	assert_eq(r.slots[requester_slot]["owner"], -1, "requester's old slot is free")
	assert_eq(r.humans().size(), 1)

func test_swap_team_keeps_pairing() -> void:
	var r := _roster()
	r.auto_assign(1)                 # team 0 QB
	r.claim(1, 1)                    # team 0 WR/CB
	var aid := r.swap_team(1)
	var s := r.slot_of_player(1)
	assert_eq(r.slots[s]["team"], 1, "now team 1")
	assert_eq(r.slots[s]["off_role"], Athlete.Role.WR, "still a WR")
	assert_eq(aid, r.slots[s]["athlete_id"])

func test_swap_fails_when_full() -> void:
	var r := _roster()
	for i in 7:
		r.claim(200 + i, 7 + i)  # fill team 1
	r.claim(1, 0)
	assert_eq(r.swap_team(1), -1, "other team full")
	assert_eq(r.slots[r.slot_of_player(1)]["team"], 0, "unchanged")

func test_cycle_position_skips_taken() -> void:
	var r := _roster()
	r.claim(1, 0)
	r.claim(2, 1)
	var aid := r.cycle_position(1)
	assert_eq(r.slot_of_player(1), 2, "skips slot 1 (taken)")
	assert_eq(aid, r.slots[2]["athlete_id"])
