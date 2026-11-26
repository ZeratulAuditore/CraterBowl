extends "res://tests/visual/harness.gd"
## #62: the host marks every joined peer's input as human (`World.HUMAN`), so a remote
## lineman blocks only while holding the shield, while bot linemen keep auto-engaging.
## The input goes through the real NetSession receive path (`_on_packet`) and the host's
## real tick (`main._step_authoritative`).

const PEER := 7

var label: Label

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	game.series.start(0, 30.0)
	game.set_controlled(game.my_id)
	var port := 30000 + randi() % 20000
	game._host_game(port, {"no_lobby": true})
	check(game.is_server(), "match is hosted")
	var ols: Array = game.world.athletes.filter(func(a): return a.team == 0 and a.role == game.Athlete.Role.OL)
	check(ols.size() >= 2, "at least two OL (%d)" % ols.size())
	var ol = ols[0]
	check(game.roster.claim(PEER, game.roster.slot_of_athlete(ol.id)), "peer seated at OL")
	game.net.peer_athlete[PEER] = ol.id
	_add_label()

	# The peer stands still without the shield. Its wire input carries no human flag.
	game.net._on_packet(PEER, var_to_bytes({"k": "in", "dir": Vector2.ZERO, "spr": false, "seq": 1, "block": false}))
	game.net._on_packet(PEER, var_to_bytes({"k": "act", "act": {"a": "snap"}}))
	await _frames(2)
	check(game.world.phase == game.World.Phase.LIVE, "peer snapped the ball")
	# Square the peer up on a free defender inside engage range, the spot where a bot
	# lineman engages on the next tick.
	var free: Array = game.world.athletes.filter(func(a): return a.team == 1 and a.engaged_with < 0 and not a.is_grounded())
	free.sort_custom(func(a, b): return a.position.distance_to(ol.position) < b.position.distance_to(ol.position))
	check(not free.is_empty(), "a free defender to square up on")
	var d = free[0]
	var toward := Vector2(0, signf(d.position.y - game.world.los_y))
	ol.position = d.position - toward * 0.9
	ol.facing = toward
	await _frames(43)
	var bot_engaged := 0
	for a in ols:
		if a.id != ol.id and a.engaged_with >= 0:
			bot_engaged += 1
	check(ol.engaged_with == -1, "peer OL without the shield never auto-engaged (engaged_with=%d)" % ol.engaged_with)
	check(bot_engaged >= 1, "bot OL still auto-engage (%d engaged)" % bot_engaged)
	_show("HOST  tick %d\npeer %d at OL #%d, no shield held: engaged_with %d (human rules)\nbot OL engaged: %d of %d"
		% [game.net_tick, PEER, ol.id, ol.engaged_with, bot_engaged, ols.size() - 1])
	await capture("peer-ol-human-bots-engage")
	finish()

func _add_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	label = Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	root.add_child(layer)

func _show(text: String) -> void:
	label.text = "#62 test overlay\n" + text
	print("OVERLAY " + text.replace("\n", " | "))

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
