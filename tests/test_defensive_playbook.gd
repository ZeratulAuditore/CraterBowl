extends "res://tests/test_case.gd"

const Playbook := preload("res://src/sim/defensive_playbook.gd")

func test_calls_cover_families_and_shells() -> void:
	var families := {}
	var shells := {}
	var names := {}
	for call in Playbook.CALLS.values():
		families[call.family] = true
		shells[call.shell] = true
		names[call.name] = true
	assert_eq(names.size(), 9)
	assert_eq(families.size(), 3)
	assert_eq(shells.size(), 3)
	for id in ["cover_1", "cover_2", "cover_3", "edge_blitz"]:
		assert_eq(Playbook.CALLS[id].shell, Playbook.Shell.BASE)

func test_situational_suggestions() -> void:
	assert_eq(Playbook.suggest(1, 10, 50, 180), "cover_2")
	assert_eq(Playbook.suggest(4, 15, 50, 60), "deep_zone")
	assert_eq(Playbook.suggest(4, 15, 50, 61), "cover_2")
	assert_eq(Playbook.suggest(4, 14, 50, 60), "cover_2")
	assert_eq(Playbook.suggest(2, 15, 50, 60), "cover_2")
	assert_eq(Playbook.suggest(4, 15, 5, 60), "goal_zone")
	assert_eq(Playbook.suggest(1, 5, 6, 60), "cover_2")
