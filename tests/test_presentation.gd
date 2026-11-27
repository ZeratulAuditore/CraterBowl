extends "res://tests/test_case.gd"

## #250: freeing the match scene within 3.5 s of touchdown fireworks (leave to the menu, or
## the coin-toss roar's fireworks right before a test frees main) must not log engine errors.
## The SceneTree timers outlive the scene, so this needs real frames: run
## tests/fireworks_free.gd in a headless child and fail on any error it prints.
func test_fireworks_survive_freeing_the_match_scene() -> void:
	var out := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", "60", "-s", "res://tests/fireworks_free.gd"], out, true)
	var log: String = "".join(out)
	assert_eq(code, 0, "fireworks_free.gd exit code")
	assert_true(log.contains("FIREWORKS FREE DONE"), "ran past every fireworks timer")
	assert_true(not log.contains("FIREWORKS FAIL"), "fireworks checks: " + _lines(log, "FIREWORKS"))
	assert_true(not log.contains("ERROR:") and not log.contains("SCRIPT ERROR"),
		"no engine errors after freeing the match scene: " + _lines(log, "ERROR"))

func _lines(log: String, key: String) -> String:
	return " | ".join(Array(log.split("\n")).filter(func(l): return l.contains(key)))
