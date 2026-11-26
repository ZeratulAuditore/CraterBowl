extends "res://tests/visual/harness.gd"
## #221: long menu footer statuses (a refusal reason the game returns with, the invite-code
## error) show their whole text instead of being clipped at the status slot's edge.

const MENU_SCENE := "res://scenes/menu.tscn"
## The #165 version refusal text, the longest reason the game hands the menu. Kept literal so
## this test doesn't depend on that PR's code.
const REFUSAL := "Update Crater Bowl to play online (server is v2, you have v1)"
const BAD_CODE := "That doesn't look like an invite code (XXXXX-XXXXX) or an IP."

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launch = root.get_node("Launch")
	launch.settings_path = "user://test_menu_long_status_settings.cfg"   # never leak into later cases
	launch.settings.player_name = "Rookie"   # home screen, not first-run

	# A match ends with a reason: the game hands it to the menu through Launch.go_to_menu.
	launch.go_to_menu(REFUSAL)
	var menu = await _menu()
	if menu == null:
		finish()
		return
	_check_full(menu, REFUSAL)
	await capture("menu-long-status-refusal")

	# The menu's own long error: a bad invite code typed into the Online screen's join field.
	menu.show_screen("online")
	await _settle()
	var code: LineEdit = menu.find_child("JoinCode", true, false)
	check(code != null, "online screen has the join field")
	if code != null:
		code.text = "not a code"
		code.text_submitted.emit(code.text)
	await _settle()
	_check_full(menu, BAD_CODE)
	await capture("menu-long-status-invite")

	# A short status gets a short, one-line tab.
	menu._status("Name saved")
	await _settle()
	_check_full(menu, "Name saved")
	check(menu.status_label.get_line_count() == 1, "a short status stays on one line")
	var short_w: float = menu.status_bar.size.x
	check(short_w < 300.0, "the status tab shrinks to a short status (%.0f px)" % short_w)
	menu._status("")
	await _settle()
	check(not menu.status_bar.is_visible_in_tree(), "no status, no tab")
	finish()

func _menu():
	for frame in 80:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == MENU_SCENE:
			break
	var menu = current_scene
	check(menu != null and menu.scene_file_path == MENU_SCENE, "returned to the menu")
	if menu == null or menu.scene_file_path != MENU_SCENE:
		return null
	await _settle()
	return menu

func _settle() -> void:
	for frame in 10:
		await process_frame

## The status reads `text` and every character of it is on screen: not clipped by the label
## (one line wider than its slot, or more wrapped lines than fit), inside the window, and
## sitting on the footer without covering the footer's links.
func _check_full(menu, text: String) -> void:
	var l: Label = menu.status_label
	check(l.text == text and l.is_visible_in_tree(), "footer status reads '%s'" % text)
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var fits: bool
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		fits = w <= l.size.x + 0.5
	else:
		fits = l.get_line_count() <= l.get_visible_line_count() \
				and l.get_visible_line_count() * font.get_height(fs) <= l.size.y + 0.5
	check(fits and (l.visible_characters < 0 or l.visible_characters >= text.length()),
			"whole status fits its label, not clipped (%d lines, %.0fx%.0f px)" % [l.get_line_count(), l.size.x, l.size.y])
	var r: Rect2 = l.get_global_rect()
	var foot: Control = menu.get_node("Footer")
	check(root.get_visible_rect().encloses(r), "status is inside the window")
	var foot_top := foot.get_global_rect().position.y
	check(r.end.y <= foot_top + 0.5 and r.end.y >= foot_top - 4.0, "status sits on top of the footer")
