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

const AI := preload("res://src/sim/ai.gd")

func test_zone_landmarks_and_blitz_pressure() -> void:
	var m := _match()
	m.start()
	var lb = m.world.find_role(1, World.Athlete.Role.LB)
	var cb = m.world.find_role(1, World.Athlete.Role.CB)
	assert_true(m.world.call_defense("cover_2"))
	var underneath: Vector2 = m.world.defense_assignment(cb).target
	assert_true(m.world.call_defense("cover_3"))
	var deep: Vector2 = m.world.defense_assignment(cb).target
	assert_true(deep.y > underneath.y)
	assert_true(m.world.call_defense("edge_blitz"))
	assert_eq(m.world.defense_assignment(lb).kind, "rush")
	assert_true(m.world.snap())
	var ai := AI.new()
	for tick in 30:
		m.world.step({}, 1.0 / 60.0)
	var qb = m.world.carrier()
	assert_true(qb != null)
	var inputs := ai.think(m.world, [qb.id])
	assert_true(inputs[lb.id].dir.dot(lb.position.direction_to(qb.position)) > 0.9)

func test_flip_and_last_play_recall() -> void:
	var m := _match()
	m.start()
	var w := m.world
	var offense: int = w.find_role(0, World.Athlete.Role.QB).id
	var defense: int = w.find_role(1, World.Athlete.Role.LB).id
	var receivers := w.receivers_in_order()
	assert_true(w.call_play("Flood"))
	var left: String = w.route_of[receivers[0].id]
	var right: String = w.route_of[receivers[1].id]
	assert_true(not Protocol.apply_action(m, defense, {"a": "flip_play"}))
	assert_true(Protocol.apply_action(m, offense, {"a": "flip_play"}))
	assert_eq(w.route_of[receivers[0].id], right)
	assert_eq(w.route_of[receivers[1].id], left)
	assert_true(w.call_defense("edge_blitz"))
	assert_true(w.snap())
	assert_true(not Protocol.apply_action(m, offense, {"a": "recall_call"}))
	w.phase = World.Phase.DEAD
	m.next_play()
	assert_true(Protocol.apply_action(m, offense, {"a": "recall_call"}))
	assert_true(Protocol.apply_action(m, defense, {"a": "recall_call"}))
	assert_eq(w.play_name, "Flood")
	assert_eq(w.defensive_call, "edge_blitz")

func test_base_zone_reduces_deep_completions_per_snap() -> void:
	var baseline := _deep_completions("")
	var zone := _deep_completions("cover_2")
	assert_true(baseline > 0 and zone < baseline,
		"deep completions in 24 matched bot snaps: legacy %d, Cover 2 %d" % [baseline, zone])

func _deep_completions(call: String) -> int:
	var totals := [0]
	for los in [20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0, 55.0]:
		for play in ["Verticals", "Deep Shot", "Flood"]:
			var w := World.new()
			Roster.new().build(w)
			w.setup_formation(los)
			w.call_play(play)
			w.call_defense(call)
			var deep := [false]
			w.event.connect(func(event, data):
				if event == "throw":
					deep[0] = data.target.y - los >= 18.0
				elif event == "catch" and deep[0]:
					totals[0] += 1)
			w.snap()
			var ai := AI.new()
			for tick in 450:
				w.step(ai.think(w, []), 1.0 / 60.0)
				if w.phase == World.Phase.DEAD:
					break
	return totals[0]

func test_standard_coverages_have_named_number_of_deep_defenders() -> void:
	for size in [3, 5, 7]:
		var w := World.new()
		Roster.new().build(w, size)
		w.setup_formation(25.0)
		for call in ["cover_2", "cover_3"]:
			w.call_defense(call)
			var deep := 0
			for a in w.athletes:
				deep += int(w.defense_assignment(a).get("deep", false))
			assert_eq(deep, 2 if call == "cover_2" else 3, "%dv%d %s" % [size, size, call])
