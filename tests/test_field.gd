extends "res://tests/test_case.gd"

const Field := preload("res://src/sim/field.gd")

func test_dimensions() -> void:
	var f := Field.new()
	assert_near(f.goal_line_a(), 0.0)
	assert_near(f.goal_line_b(), 100.0)
	assert_near(f.endzone_depth, 10.0)
	assert_near(f.width, 53.33)

func test_zones() -> void:
	var f := Field.new()
	assert_eq(f.zone_of(Vector2(20, 50)), Field.Zone.FIELD, "midfield")
	assert_eq(f.zone_of(Vector2(20, -5)), Field.Zone.ENDZONE_A, "endzone A")
	assert_eq(f.zone_of(Vector2(20, 105)), Field.Zone.ENDZONE_B, "endzone B")
	assert_eq(f.zone_of(Vector2(-1, 50)), Field.Zone.OUT_OF_BOUNDS, "sideline")
	assert_eq(f.zone_of(Vector2(20, 111)), Field.Zone.OUT_OF_BOUNDS, "back line")

func test_clamp_playable() -> void:
	var f := Field.new()
	var p := f.clamp_playable(Vector2(-50, 500))
	assert_near(p.x, -2.0, 0.001, "x clamp")
	assert_near(p.y, 112.0, 0.001, "y clamp")
