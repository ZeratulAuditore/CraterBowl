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

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const Protocol := preload("res://src/net/protocol.gd")

func _match() -> Match:
	var world := World.new()
	Roster.new().build(world)
	return Match.new(world)

func test_classic_match_suggests_and_refreshes_defense_call() -> void:
	var m := _match()
	m.start(0, m.goal() - 4)
	assert_eq(m.world.defensive_call, "goal_zone")
	assert_true(m.world.call_defense("goal_blitz"))
	m.world.phase = World.Phase.DEAD
	m.last_result = {"type": "incomplete", "team": 0}
	m.next_play()
	assert_eq(m.world.defensive_call, "goal_zone")
	m.world.set_ruleset("chaosball")
	m.start()
	assert_eq(m.world.defensive_call, "")
	assert_true(not m.world.call_defense("cover_2"))

func test_defensive_selection_authority() -> void:
	var m := _match()
	m.start()
	var defender: int = m.world.find_role(1, World.Athlete.Role.LB).id
	var qb: int = m.world.find_role(0, World.Athlete.Role.QB).id
	assert_eq(m.world.defensive_call, "cover_2")
	assert_true(not Protocol.apply_action(m, qb, {"a": "defense", "p": "cover_1"}))
	assert_true(not Protocol.apply_action(m, defender, {"a": "defense", "p": "unknown"}))
	assert_true(Protocol.apply_action(m, defender, {"a": "defense", "p": "cover_1"}))
	assert_eq(m.world.defensive_call, "cover_1")
	m.world.snap()
	assert_true(not Protocol.apply_action(m, defender, {"a": "defense", "p": "cover_3"}))
	assert_eq(m.world.defensive_call, "cover_1")
