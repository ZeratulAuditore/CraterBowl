extends "res://tests/test_case.gd"

func test_harness_runs() -> void:
	assert_eq(1 + 1, 2, "math")
