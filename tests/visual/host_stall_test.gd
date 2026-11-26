extends "res://tests/visual/harness.gd"
## #86: a joiner in a match whose host goes silent (crashed, but the ENet link not yet timed
## out) sees "Connection to host lost…" after STALL_AFTER, the banner clears if the host is
## heard again (a lag spike, no drop), and after DROP_AFTER of silence the joiner is back on
## the menu with "Host disconnected", well before ENet's own 5-30 s peer timeout.
## The bare in-process host keeps ENet alive (it polls and acks) but never sends snapshots,
## so only the watchdog can be what fires.

const NetSession := preload("res://src/net/net_session.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var port := 32000 + randi() % 2000
	var launch = get_root().get_node("Launch")
	launch.settings_path = "user://test_host_stall_settings.cfg"
	launch.settings.player_name = "Rookie"
	var host = NetSession.new()
	host.name = "BareHost"
	root.add_child(host)
	check(host.host(port, func(_p): return 7, func(_p): pass) == OK, "host listening on %d" % port)

	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._join_game("127.0.0.1", port, {})
	for frame in 600:
		await process_frame
		if game.net.my_athlete >= 0:
			break
	check(game.net.my_athlete == 7, "joiner welcomed into the match (athlete %d)" % game.net.my_athlete)
	var banner = game.get_node_or_null("LinkBanner")

	# The host goes silent: the watchdog warns at STALL_AFTER on its own clock. (Wall time is
	# longer here: llvmpipe frames are slow and each counts at most SILENCE_STEP_MAX. The
	# headless net_test.sh asserts the wall-clock bound.)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000 and not game.net.get("stalled"):
		await process_frame
	var silence = game.net.get("host_silence")
	check(game.net.get("stalled") == true, "watchdog warns (%.2fs wall)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	check(silence != null and silence >= 2.0 and silence < 2.3, "warning comes at STALL_AFTER (2 s of silence): %s" % str(silence))
	check(banner != null and banner.visible and banner.title.text == "CONNECTION TO HOST LOST…",
		"'Connection to host lost…' banner is up")
	check(current_scene == game, "still in the match while warning")
	# Pin the watchdog clock so the capture doesn't depend on how long rendering took.
	game.net.set_process(false)
	game.net.set("host_silence", 2.0)
	if banner != null:
		banner._refresh()
		check(banner.sub.text == "Waiting for the host · back to the menu in 2s", "countdown: '%s'" % banner.sub.text)
		check(root.get_visible_rect().encloses(banner.panel.get_global_rect()), "banner fits the viewport")
	await capture("host-stall-banner")

	# A lag spike: the host is heard again before DROP_AFTER, so the banner clears, no drop.
	game.net.set_process(true)
	for p in host.api.get_peers():
		host._send(p, {"k": "noop"}, true)
	for frame in 120:
		await process_frame
		if not game.net.get("stalled"):
			break
	check(not game.net.get("stalled") and banner != null and not banner.visible, "host heard again: banner clears")
	check(current_scene == game, "a recovered stall doesn't drop the match")

	# Silence again, this time for good: back on the menu after DROP_AFTER, ENet still connected.
	var dropped_at := [-1.0]
	game.net.host_lost.connect(func(): dropped_at[0] = game.net.host_silence)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 40000:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn":
			break
	var drop_s := (Time.get_ticks_msec() - t1) / 1000.0
	var menu = current_scene
	check(menu != null and menu.scene_file_path == "res://scenes/menu.tscn", "joiner returned to the menu (%.2fs wall)" % drop_s)
	check(dropped_at[0] >= 4.0 and dropped_at[0] < 4.3, "drop comes at DROP_AFTER (4 s of silence) with ENet still connected: %.2f" % dropped_at[0])
	for frame in 20:
		await process_frame
	check(menu != null and menu.status_label.text == "Host disconnected", "menu status reads 'Host disconnected'")
	host.queue_free()
	finish()
