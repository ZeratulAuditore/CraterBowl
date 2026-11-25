extends SceneTree
## Minimal headless test runner. Loads every tests/test_*.gd, runs each
## method starting with "test_", and exits non-zero on any failure.
## Test scripts extend res://tests/test_case.gd.

func _init() -> void:
	var failures := 0
	var passed := 0
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failures += 1
			print("  FAIL %s (script failed to load/compile)" % f)
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var inst = script.new()
			inst.call(name)
			if inst.errors.is_empty():
				passed += 1
				print("  PASS %s::%s" % [f, name])
			else:
				failures += 1
				print("  FAIL %s::%s" % [f, name])
				for e in inst.errors:
					print("       - " + e)
	print("\n%d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)
