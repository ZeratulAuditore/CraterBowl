extends "res://tests/test_case.gd"

func test_main_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert_true(packed != null, "main scene loads")
	var inst = packed.instantiate()
	assert_true(inst.has_method("_build_field"), "main script attached")
	inst.free()
