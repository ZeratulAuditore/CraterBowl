extends "res://tests/test_case.gd"

const Downs := preload("res://src/sim/downs.gd")

func _d(los: float = 25.0) -> Downs:
	var d := Downs.new()
	d.reset(0, los)
	return d

func test_first_down_on_gain() -> void:
	var d := _d()
	var r := d.apply({"type": "tackle", "spot": 37.0})
	assert_eq(r["outcome"], "first_down")
	assert_eq(d.down, 1)
	assert_near(d.los, 37.0)
	assert_near(d.distance(), 10.0)

func test_goal_to_go() -> void:
	var d := _d(85.0)
	d.apply({"type": "tackle", "spot": 95.0})
	assert_true(d.is_goal_to_go(), "& goal")
	assert_near(d.first_down_y, 100.0)
	assert_true(d.label().begins_with("1st & Goal"), d.label())

func test_short_gain_and_loss() -> void:
	var d := _d()
	d.apply({"type": "tackle", "spot": 28.0})
	assert_eq(d.down, 2)
	assert_near(d.distance(), 7.0)
	d.apply({"type": "tackle", "spot": 24.0})
	assert_eq(d.down, 3)
	assert_near(d.distance(), 11.0)

func test_incomplete_keeps_los() -> void:
	var d := _d()
	d.apply({"type": "incomplete"})
	assert_eq(d.down, 2)
	assert_near(d.los, 25.0)

func test_turnover_on_downs() -> void:
	var d := _d(40.0)
	for i in 3:
		d.apply({"type": "incomplete"})
	var r := d.apply({"type": "tackle", "spot": 45.0})
	assert_eq(r["outcome"], "turnover_on_downs")
	assert_eq(d.offense_team, 1, "possession flips")
	assert_near(d.los, 55.0, 0.001, "spot mirrored")
	assert_eq(d.down, 1)

func test_label() -> void:
	var d := _d()
	d.apply({"type": "tackle", "spot": 28.0})
	assert_eq(d.label(), "2nd & 7 at OWN 28")
	d.reset(0, 70.0)
	assert_eq(d.label(), "1st & 10 at OPP 30")
