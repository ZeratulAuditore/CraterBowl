extends SceneTree
## Host the normal net smoke scenario, then give the joiner's team one possession
## so the client can exercise a handoff as the quarterback.

var main
var saw_live := false
var threw_opening_pass := false
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
		if not threw_opening_pass and main.world.ball.is_held_by(main.my_id):
			_throw_opening_pass()
	if saw_live and main.world.phase == main.World.Phase.PRESNAP:
		presnap_time += dt
		if presnap_time >= 2.0:
			main.series.start(1)
			main.ai.defense_enabled = false
			prepared_handoff = true
			main.world.event.connect(_finish_after_handoff)
	return false

func _throw_opening_pass() -> void:
	threw_opening_pass = true
	var world = main.world
	var qb = world.carrier()
	var tipper = world.find_role(1, main.Athlete.Role.LB)
	for a in world.athletes:
		a.position = Vector2(30.0, 25.0 + 3.0 * a.id)
		a.velocity = Vector2.ZERO
	qb.position = Vector2(12.0, world.los_y - 5.0)
	tipper.position = qb.position + Vector2(0.0, 4.25)
	world.throw(qb.id, qb.position + Vector2(0.0, 6.0), main.T.PLAYER_PASS_POWER)

func _finish_after_handoff(event: String, _data: Dictionary) -> void:
	if event != "handoff":
		return
	main.world.event.disconnect(_finish_after_handoff)
	# Let the joiner observe the handoff before setting up the final score.
	await create_timer(0.5).timeout
	main.stats.award_stats.clear()
	_record_pass_before_seat_replacement()
	_record_run_before_seat_replacement()
	_record_fumbled_keeper()
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

## Replace the keeper after the snap, then leave the field for a 10-yard gain.
func _record_run_before_seat_replacement() -> void:
	main.series.start(1, 25.0)
	var world = main.world
	var qb = world.find_role(1, main.Athlete.Role.QB)
	var slot: int = main.roster.slot_of_athlete(qb.id)
	var replacement: int = main.roster.slots[slot]["owner"]
	var original := 99
	main.roster.release(replacement)
	main.roster.claim(original, slot)
	world.snap()
	while world.snap_in_flight():
		world.step({}, 1.0 / world.Tick.HZ)
	main.roster.release(original)
	main.roster.claim(replacement, slot)
	qb.position = Vector2(-0.5, 35.0)
	world.step({}, 1.0 / world.Tick.HZ)

## The current QB earns this carry even though the defense recovers.
func _record_fumbled_keeper() -> void:
	main.series.start(1, 25.0)
	var world = main.world
	var qb = world.find_role(1, main.Athlete.Role.QB)
	var defender = world.find_role(0, main.Athlete.Role.LB)
	world.snap()
	while world.snap_in_flight():
		world.step({}, 1.0 / world.Tick.HZ)
	qb.position = Vector2(5.0, world.los_y + 7.0)
	defender.position = qb.position
	world._fumble(qb, defender)
	world.ball.position.z = 0.0
	world._step_loose(0.0)
	defender.position.x = -0.5
	world.step({}, 1.0 / world.Tick.HZ)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	main._unhandled_key_input(event)
