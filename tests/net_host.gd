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
	main.stats.award_stats.clear()
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

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	main._unhandled_key_input(event)
