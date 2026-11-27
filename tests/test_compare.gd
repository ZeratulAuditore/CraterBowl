extends "res://tests/test_case.gd"

func test_compare_reports_output_errors() -> void:
	var root := ProjectSettings.globalize_path("user://test_compare_%d" % OS.get_process_id())
	var raw := root.path_join("raw")
	var out := root.path_join("compare")
	var shot := "fixture.png"
	DirAccess.make_dir_recursive_absolute(raw)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.CORNFLOWER_BLUE)
	assert_eq(img.save_png(raw.path_join(shot)), OK, "fixture saved")

	var result := _compare(raw, raw, out)
	assert_eq(result[0], 0, "valid comparison succeeds")
	assert_true(FileAccess.file_exists(out.path_join(shot)), "comparison PNG exists")

	DirAccess.remove_absolute(out.path_join(shot))
	DirAccess.make_dir_absolute(out.path_join(shot))
	result = _compare(raw, raw, out)
	assert_true(result[0] != 0 and result[1].contains("Could not save comparison PNG"), "failed PNG write is reported")
	result = _compare(raw, raw, raw.path_join(shot))
	assert_true(result[0] != 0 and result[1].contains("Could not create comparison directory"), "invalid output directory is reported")

	for path in [out.path_join(shot), out, raw.path_join(shot), raw, root]:
		DirAccess.remove_absolute(path)

func _compare(before: String, after: String, out: String) -> Array:
	var output := []
	var status := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tools/compare.gd", "--", "--before=" + before, "--after=" + after, "--out=" + out], output, true)
	return [status, "\n".join(output)]
