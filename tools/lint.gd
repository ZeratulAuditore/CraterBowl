extends SceneTree
## Compile every GDScript in the project. Catches parse errors in files no test or
## scene loads yet (tools, new modules). Exit 1 on any failure.
##   godot --headless --path . -s res://tools/lint.gd

func _initialize() -> void:
	var bad := 0
	var n := 0
	for dir in ["res://src", "res://tests", "res://tools"]:
		for f in _files(dir):
			if f == get_script().resource_path:
				continue  # reloading the running script would break it
			n += 1
			var s = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
			if s == null or not (s is GDScript) or not s.can_instantiate():
				bad += 1
				print("LINT FAIL %s (does not compile)" % f)
	print("LINT %s: %d scripts, %d failed" % ["PASS" if bad == 0 else "FAIL", n, bad])
	quit(1 if bad > 0 else 0)

func _files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		if not sub.begins_with(".") and sub != "__pycache__":
			out.append_array(_files(dir + "/" + sub))
	return out
