extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const Ball := preload("res://src/sim/ball.gd")
const T := preload("res://src/sim/tuning.gd")
const DT := 1.0 / 60.0

func test_run_picks_up_speed_and_stops_in_one_step() -> void:
	var runner := Athlete.new(0, 0, Athlete.Role.WR, Vector2(20, 30))
	runner.step(Vector2.RIGHT, false, DT)
	assert_eq(runner.velocity, Vector2.RIGHT * T.RUN_SPEED)
	runner.step(Vector2.LEFT, true, DT)
	assert_eq(runner.velocity, Vector2.LEFT * T.SPRINT_SPEED)
	runner.step(Vector2.ZERO, false, DT)
	assert_eq(runner.velocity, Vector2.ZERO)

func test_shield_slows_backpedal_and_spin_breaks_the_block() -> void:
	var world := World.new()
	var blocker := world.add_athlete(0, Athlete.Role.OL, Vector2(20, 30))
	var defender := world.add_athlete(1, Athlete.Role.DL, Vector2(20, 30.95))
	var carrier := world.add_athlete(0, Athlete.Role.QB, Vector2(20, 25))
	world.start_live_with(carrier.id)
	world.step({blocker.id: {"dir": Vector2.UP, "sprint": true, "block": true}}, DT)
	assert_true(blocker.blocking, "shield active")
	assert_eq(blocker.velocity, Vector2.UP * T.BLOCK_SPEED, "backpedal at shield speed")
	assert_eq(blocker.facing, Vector2.DOWN, "shield stays pointed toward defender")
	assert_eq(defender.engaged_with, blocker.id, "shield engages the defender")
	assert_true(world.evade(defender.id, true, Vector2.RIGHT), "spin sheds shield")
	assert_eq(defender.engaged_with, -1)
	assert_eq(blocker.engaged_with, -1)
	assert_near(defender.move_charge, 1.0, 0.001)

func test_move_charges_fill_only_when_moving() -> void:
	var world := World.new()
	var runner := world.add_athlete(0, Athlete.Role.WR, Vector2(20, 30))
	world.start_live_with(runner.id)
	assert_true(world.evade(runner.id, false, Vector2.RIGHT))
	for i in 30:
		world.step({}, DT)
	assert_near(runner.move_charge, 1.0, 0.001, "dash and standing still do not recharge")
	assert_true(world.evade(runner.id, true, Vector2.RIGHT))
	for i in 30:
		world.step({}, DT)
	assert_true(not world.evade(runner.id, false, Vector2.RIGHT), "empty meter blocks both moves")
	for i in 180:
		world.step({runner.id: {"dir": Vector2.DOWN}}, DT)
	assert_true(runner.move_charge >= 1.0, "running fills a charge")

func test_resting_tackled_carrier_retains_ball() -> void:
	var world := World.new()
	var carrier := world.add_athlete(0, Athlete.Role.QB, Vector2(20, 30))
	var defender := world.add_athlete(1, Athlete.Role.LB, Vector2(20, 31))
	defender.facing = Vector2.UP
	world.start_live_with(carrier.id)
	assert_true(world.tackle(defender.id))
	world.step({}, DT)
	assert_eq(world.phase, World.Phase.DEAD)
	assert_eq(world.ball.state, Ball.State.DEAD)
	assert_eq(world.ball.holder_id, carrier.id, "dead ball stays attached to the carrier")
	world.step({carrier.id: {"dir": Vector2.RIGHT}}, DT)
	assert_eq(carrier.position, world.dead_ball_spot)

func test_fumble_risk_increases_with_impact_and_fatigue() -> void:
	assert_true(World.fumble_risk(15.0, 0.1) > World.fumble_risk(7.0, 0.1))
	assert_true(World.fumble_risk(15.0, 0.1) > World.fumble_risk(15.0, 0.6))
