extends "res://tests/test_case.gd"
## #77: the host validates match action shapes before they reach the rules layer.
## A malformed action used to abort the host's tick with a script error (Godot 4 `==`
## between an int/Array and a String, or a non-Dictionary passed to the typed dispatcher).
## run_tests.gd/test.sh fail on any SCRIPT ERROR in the log, so these also catch a regression
## that only logs instead of returning a wrong value.

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const P := preload("res://src/net/protocol.gd")
const NetSession := preload("res://src/net/net_session.gd")
const R := Athlete.Role

## Values a peer could put in an "act" message that do not meet the dispatcher's contract.
const JUNK := [
	null, 5, 2.5, "snap", true, [1, 2], Vector2.ONE, {},
	{"a": 5}, {"a": null}, {"a": ["snap"]}, {"a": {"a": "snap"}}, {"a": Vector2.ZERO}, {"x": "snap"},
	{"a": "dash", "dir": "north"}, {"a": "spin", "s": 1.5}, {"a": "throw", "t": Vector2.ONE, "p": "hard"},
	{"a": "throw", "d": Vector2.UP, "p": 0.5, "ang": "high"}, {"a": "try", "n": "two"}, {"a": "nope"},
]

func _match() -> Match:
	var w := World.new()
	var cx := w.field.width / 2.0
	var pairs := [[R.C, 0.0, R.DL, -1.5], [R.QB, 0.0, R.LB, 0.0], [R.WR, -18.0, R.CB, -18.0], [R.WR, 18.0, R.CB, 18.0]]
	for t in 2:
		for p in pairs:
			w.add_two_way(t, p[0], cx + p[1], p[2], cx + p[3])
	var m := Match.new(w)
	m.start(0, 25.0)
	return m

func test_is_action_shape_gate() -> void:
	for v in [null, 5, "snap", [1], {}, {"a": 5}, {"a": null}, {"a": ["snap"]}]:
		assert_true(not P.is_action(v), "not an action: %s" % var_to_str(v))
	assert_true(P.is_action({"a": "snap"}), "plain action")
	assert_true(P.is_action({"a": "nope"}), "unknown names pass the shape gate (sanitize_action rejects them)")

func test_junk_actions_rejected_without_touching_the_match() -> void:
	var m := _match()
	var qb: int = m.world.find_role(0, R.QB).id
	for v in JUNK:
		assert_true(P.sanitize_action(v).is_empty(), "sanitized away: %s" % var_to_str(v))
		assert_true(not P.apply_action(m, qb, v), "rejected: %s" % var_to_str(v))
	assert_eq(m.world.phase, World.Phase.PRESNAP, "junk never snapped the ball")
	assert_true(P.apply_action(m, qb, {"a": "snap"}), "a normal action still reaches the rules layer")
	assert_eq(m.world.phase, World.Phase.LIVE, "snap applied")

func test_non_bool_flags_read_as_false() -> void:
	var t := P.sanitize_action({"a": "throw", "t": Vector2(20, 60), "p": 0.5, "lob": "yes"})
	assert_eq(t.get("lob"), false, "string lob flag")
	assert_eq(P.sanitize_action({"a": "throw", "t": Vector2(20, 60), "p": 0.5, "lob": true}).get("lob"), true, "real lob")
	var inp := P.sanitize_input({"dir": Vector2.ZERO, "spr": 1, "block": "x"})
	assert_eq(inp["sprint"], false, "int sprint flag")
	assert_eq(inp["block"], false, "string block flag")
	assert_eq(P.sanitize_input({"dir": Vector2.ZERO, "spr": true, "block": true})["block"], true, "real block flag")

## Host receive path: junk "act" packets from an assigned peer never enter the queue,
## the valid one does, and dispatching the queue the way main._step_authoritative does
## snaps the ball.
func test_host_queue_drops_junk_keeps_valid() -> void:
	var m := _match()
	var qb: int = m.world.find_role(0, R.QB).id
	var net := NetSession.new()
	net.mode = NetSession.Mode.SERVER
	net.peer_athlete = {7: qb}
	for v in JUNK.slice(0, 14):   # the shape-invalid ones
		net._on_packet(7, var_to_bytes({"k": "act", "act": v}))
	net._on_packet(7, var_to_bytes({"k": "act"}))          # missing payload
	net._on_packet(7, var_to_bytes([1, 2, 3]))            # not even a message
	net._on_packet(9, var_to_bytes({"k": "act", "act": {"a": "snap"}}))   # unassigned peer
	net._on_packet(7, var_to_bytes({"k": "act", "act": {"a": "snap"}}))
	var queued := net.take_actions()
	assert_eq(queued.size(), 1, "only the valid action from the assigned peer is queued")
	var applied := 0
	for pa in queued:
		if P.apply_action(m, pa[1], pa[2]):
			applied += 1
	assert_eq(applied, 1, "valid action applied")
	assert_eq(m.world.phase, World.Phase.LIVE, "assigned QB snapped via the queue")
	net.free()
