extends "res://tests/test_case.gd"

func test_main_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert_true(packed != null, "main scene loads")
	var inst = packed.instantiate()
	assert_true(inst.has_method("_build_field"), "main script attached")
	inst.free()

## #74: the host's rules (menu "mode" / --mode) must reach _host_game as "game".
func test_host_options_forward_the_rules() -> void:
	var inst = load("res://scenes/main.tscn").instantiate()
	var chaos: Dictionary = inst.host_options({"host": true, "mode": "chaosball", "size": "7", "advertise": "127.0.0.1"})
	assert_eq(chaos.get("game"), "chaosball", "menu Chaosball pick -> host lobby rules")
	assert_eq(chaos.get("advertise"), "127.0.0.1", "advertise forwarded")
	assert_eq(inst.host_options({"host": true, "mode": "classic"}).get("game"), "classic", "classic stays classic")
	assert_eq(inst.host_options({"host": true}).get("game"), "classic", "no mode -> classic")
	var cli: Dictionary = inst.host_options({"host": true, "no-lobby": true, "start-when-ready": true, "playclock": "4"})
	assert_true(cli["no_lobby"] and cli["start_when_ready"] and cli["playclock"] == 4.0, "CLI host flags still forwarded")
	inst.free()
