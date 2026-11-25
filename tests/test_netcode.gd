extends "res://tests/test_case.gd"

const Athlete := preload("res://src/sim/athlete.gd")
const Predictor := preload("res://src/net/client_predictor.gd")
const Interp := preload("res://src/net/interpolator.gd")
const P := preload("res://src/net/protocol.gd")
const DT := 1.0 / 60.0

func _copy_state(dst, src) -> void:
	dst.position = src.position
	dst.velocity = src.velocity
	dst.stamina = src.stamina
	dst.sprint_locked = src.sprint_locked
	dst.facing = src.facing

func test_prediction_leads_then_matches_server() -> void:
	var server := Athlete.new(0, 0, Athlete.Role.WR, Vector2(20, 30))
	var client := Athlete.new(0, 0, Athlete.Role.WR, Vector2(20, 30))
	var pred := Predictor.new()
	var latency := 6   # ticks each way
	var in_flight: Array = []   # inputs travelling to server: [arrive_tick, seq, dir, sprint]
	var snaps: Array = []       # snapshots travelling to client: [arrive_tick, state copy, ack]
	var server_ack := 0
	for tick in 180:
		var dir := Vector2(1, 0.5) if tick < 120 else Vector2.ZERO
		var seq := pred.record(dir, tick % 40 < 20, DT)
		client.step(dir, tick % 40 < 20, DT)
		in_flight.append([tick + latency, seq, dir, tick % 40 < 20])
		while not in_flight.is_empty() and in_flight[0][0] <= tick:
			var inp = in_flight.pop_front()
			server.step(inp[2], inp[3], DT)
			server_ack = inp[1]
		var st := Athlete.new()
		_copy_state(st, server)
		snaps.append([tick + latency, st, server_ack])
		while not snaps.is_empty() and snaps[0][0] <= tick:
			var sn = snaps.pop_front()
			_copy_state(client, sn[1])
			pred.reconcile(client, sn[2])
		if tick == 60:
			assert_true(client.position.x > server.position.x + 0.5, "client leads server during latency")
	# drain: let server process everything and client reconcile
	for tick in range(180, 200):
		while not in_flight.is_empty() and in_flight[0][0] <= tick:
			var inp = in_flight.pop_front()
			server.step(inp[2], inp[3], DT)
			server_ack = inp[1]
	_copy_state(client, server)
	pred.reconcile(client, server_ack)
	assert_true(client.position.distance_to(server.position) < 0.01, "converged")
	assert_eq(pred.pending.size(), 0, "acked inputs dropped")

func test_pending_bounded() -> void:
	var pred := Predictor.new()
	for i in 1000:
		pred.record(Vector2.ZERO, false, DT)
	assert_true(pred.pending.size() <= Predictor.MAX_PENDING, "bounded")

func test_interpolation_midpoint_and_clamps() -> void:
	var it := Interp.new()
	it.push(60, PackedFloat32Array([0, 0]), Vector3.ZERO)
	it.push(66, PackedFloat32Array([10, 20]), Vector3(1, 2, 3))
	var mid := it.sample(63.0 / 60.0)
	assert_near(mid["xy"][0], 5.0, 0.001, "x mid")
	assert_near(mid["xy"][1], 10.0, 0.001, "y mid")
	assert_true((mid["ball"] as Vector3).distance_to(Vector3(0.5, 1, 1.5)) < 0.001, "ball mid")
	assert_near(it.sample(0.0)["xy"][0], 0.0, 0.001, "before first -> first")
	assert_near(it.sample(99.0)["xy"][0], 10.0, 0.001, "after last -> last")

func test_interpolation_ignores_out_of_order() -> void:
	var it := Interp.new()
	it.push(60, PackedFloat32Array([0, 0]), Vector3.ZERO)
	it.push(70, PackedFloat32Array([10, 0]), Vector3.ZERO)
	it.push(64, PackedFloat32Array([99, 99]), Vector3.ZERO)
	assert_eq(it.buf.size(), 2, "stale snapshot dropped")

func test_input_seq_sanitized() -> void:
	assert_eq(P.sanitize_input({"dir": Vector2.ZERO, "seq": 17})["seq"], 17)
	assert_eq(P.sanitize_input({"dir": Vector2.ZERO, "seq": -5})["seq"], 0)
	assert_eq(P.sanitize_input({"dir": Vector2.ZERO, "seq": "x"})["seq"], 0)
