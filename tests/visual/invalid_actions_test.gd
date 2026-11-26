extends "res://tests/visual/harness.gd"
## #77: a host keeps stepping after a joined peer sends malformed match actions, and the
## same peer's next valid action still reaches the rules layer. Packets go through the real
## NetSession receive path (`_on_packet`) and the host's real tick (`main._step_authoritative`).

const JUNK := [
	null, 5, "snap", [1, 2], Vector2.ONE, {}, {"a": 5}, {"a": null}, {"a": ["snap"]}, {"a": Vector2.ZERO},
	{"a": "dash", "dir": "north"}, {"a": "throw", "t": Vector2.ONE, "p": "hard"}, {"a": "nope"},
]
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
	# Seat a fake joined peer on the offense (a receiver), as net.host's assign callback would.
	var wr = game.world.find_role(0, game.Athlete.Role.WR)
	check(game.roster.claim(PEER, game.roster.slot_of_athlete(wr.id)), "peer seated at WR")
	game.net.peer_athlete[PEER] = wr.id
	_add_label()

	var tick0: int = game.net_tick
	for v in JUNK:
		game.net._on_packet(PEER, var_to_bytes({"k": "act", "act": v}))
	game.net._on_packet(PEER, var_to_bytes({"k": "act"}))
	# A valid action queued behind the junk in the same host tick: before #77 the first
	# malformed entry aborted the tick and this one was silently dropped.
	game.net._on_packet(PEER, var_to_bytes({"k": "act", "act": {"a": "play", "p": "Slants"}}))
	await _frames(30)
	var stepped: int = game.net_tick - tick0
	check(stepped >= 25, "host kept stepping after %d malformed actions (%d ticks)" % [JUNK.size() + 1, stepped])
	check(game.world.phase == game.World.Phase.PRESNAP, "malformed actions did not snap the ball")
	check(game.world.play_name == "Slants", "valid play call queued behind the junk was applied (%s)" % game.world.play_name)
	_show("HOST  tick %d\n%d malformed actions from peer %d: ignored\nsame-tick valid play call: %s\nphase PRESNAP, host still stepping"
		% [game.net_tick, JUNK.size() + 1, PEER, game.world.play_name])
	await capture("host-after-malformed-actions")

	game.net._on_packet(PEER, var_to_bytes({"k": "act", "act": {"a": "snap"}}))
	await _frames(20)
	check(game.world.phase == game.World.Phase.LIVE, "peer's valid snap reached the rules layer")
	_show("HOST  tick %d\nvalid {\"a\": \"snap\"} from peer %d (WR): applied\nphase LIVE"
		% [game.net_tick, PEER])
	await capture("host-valid-snap-applied")
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
	label.text = "#77 test overlay\n" + text
	print("OVERLAY " + text.replace("\n", " | "))

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
