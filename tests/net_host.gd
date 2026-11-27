extends SceneTree
## Host the normal net smoke scenario, then give the joiner's team one possession
## so the client can exercise a handoff as the quarterback.

var main
var saw_live := false
var presnap_time := 0.0
var prepared_handoff := false
var set_quarters := false
var reported_ids := false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(dt: float) -> bool:
	if prepared_handoff or not main.is_server():
		return false
	if main.in_lobby():
		if not set_quarters:
			_key(KEY_Q)   # #130: no-op now (halves are gone); the client checks the lobby stayed quarters
			_key(KEY_H)   # 2.5 -> 3-min quarters
			set_quarters = true
		return false
	if not reported_ids:   # match started: the joiner's install id came in through the lobby (#102)
		reported_ids = true
		for peer in main.peer_installs:
			print("NET host got install id %s" % main.peer_installs[peer])
	if main.world.phase == main.World.Phase.LIVE:
		saw_live = true
	if saw_live and main.world.phase == main.World.Phase.PRESNAP:
		presnap_time += dt
		if presnap_time >= 2.0:
			main.series.start(1)
			main.ai.defense_enabled = false
			prepared_handoff = true
			main.world.event.connect(_finish_after_handoff)
	return false

func _finish_after_handoff(event: String, _data: Dictionary) -> void:
	if event != "handoff":
		return
	main.world.event.disconnect(_finish_after_handoff)
	# Let the joiner observe the handoff before setting up the final score.
	await create_timer(0.5).timeout
	await _send_sideline_results()
	main.stats.award_stats.clear()
	_record_pass_before_seat_replacement()
	main.series.start(0, 95.0)
	main.world.event.emit("snap", {"qb": main.my_id})
	main.world.event.emit("touchdown", {"carrier": main.my_id, "spot": Vector2(26, 100), "team": 0, "points": 6})
	main.series.score = [6, 0]
	main.series.clock.half = 2
	main.series.clock.quarter = 4
	main.series.clock.remaining = 0.0
	main.world.phase = main.World.Phase.DEAD
	main.series.last_result = {"type": "incomplete"}
	main.next_play()

## Same airborne pass, opposite rulings based on where the receiver stands.
func _send_sideline_results() -> void:
	var w = main.world
	for receiver_x in [0.55, -0.55]:
		main.series.start(0, 25.0)
		var qb = w.find_role(0, main.Athlete.Role.QB)
		for a in w.athletes:
			a.position = Vector2(32.0, 26.0 + 2.0 * a.id)
		qb.position = Vector2(5.0, 20.0)
		w.start_live_with(qb.id)
		assert(w.throw(qb.id, Vector2(-0.75, 38.0), 0.8))
		for tick in 100:
			if w.ball.position.x < -0.2 or w.phase == w.Phase.DEAD:
				break
			w.step({}, 1.0 / w.Tick.HZ)
		w.find_role(0, main.Athlete.Role.WR).position = Vector2(receiver_x, w.ball.position.y)
		w.step({}, 1.0 / w.Tick.HZ)
		await create_timer(0.25).timeout

## Give the real client the QB seat between another player's throw and catch.
func _record_pass_before_seat_replacement() -> void:
	main.series.start(1, 25.0)
	var world = main.world
	var qb = world.find_role(1, main.Athlete.Role.QB)
	var receiver = world.find_role(1, main.Athlete.Role.WR)
	var slot: int = main.roster.slot_of_athlete(qb.id)
	var replacement: int = main.roster.slots[slot]["owner"]
	var original := 99
	assert(replacement > 1 and replacement != original)
	main.roster.release(replacement)
	main.roster.claim(original, slot)
	world.event.emit("snap", {"qb": qb.id})
	world.event.emit("throw", {"by": qb.id})
	main.roster.release(original)
	main.roster.claim(replacement, slot)
	world.event.emit("catch", {"by": receiver.id})
	world.event.emit("out_of_bounds", {"carrier": receiver.id, "spot": Vector2(0, 45), "team": 1})

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	main._unhandled_key_input(event)
