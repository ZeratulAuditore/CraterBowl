extends SceneTree
## Two-process net test (client side). Run with: -- --join=127.0.0.1 --port=N
## against a host started with: -- --host --port=N --playclock=4

var main
var f := 0
var ok := true
var aid := -1
var snaps := 0
var start_x := INF
var max_dx := 0.0
var got_snap_event := false
var saw_live := false
var bad_snap_sent_at := -1
var bad_snap_rejected := false

func check(cond: bool, msg: String) -> void:
	print(("  NET OK   " if cond else "  NET FAIL ") + msg)
	if not cond:
		ok = false

func _on_snap(s: Dictionary) -> void:
	snaps += 1
	if s["ph"] == 1:
		saw_live = true

func _on_event(n: String, _d: Dictionary) -> void:
	if n == "snap":
		got_snap_event = true

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_dt: float) -> bool:
	f += 1
	if f == 2:
		main.net.welcomed.connect(func(id): aid = id)
		main.net.snapshot_received.connect(_on_snap)
		main.net.event_received.connect(_on_event)
	if aid >= 0 and snaps > 3:
		var x: float = main.world.get_athlete(aid).position.x
		if start_x == INF:
			start_x = x
			main.input_override = Vector2(1, 0)  # strafe right (legal presnap for defense)
		max_dx = maxf(max_dx, x - start_x)
	# After the first play ends and the next presnap begins, try an illegal defense snap.
	if saw_live and bad_snap_sent_at < 0 and main.world.phase == 0:
		main.input_override = Vector2.ZERO
		main.do_action({"a": "snap"})
		bad_snap_sent_at = f
	if bad_snap_sent_at > 0 and f == bad_snap_sent_at + 30:
		bad_snap_rejected = main.world.phase == 0
	if f == 1100 or (bad_snap_sent_at > 0 and f == bad_snap_sent_at + 31):
		check(aid >= 0, "welcomed with athlete %d" % aid)
		check(aid >= 0 and main.world.get_athlete(aid).team == 1, "joiner plays for the opponent team")
		check(snaps > 20, "receiving snapshots (%d)" % snaps)
		check(max_dx > 2.0, "own input moved own athlete on server (dx %.1f)" % max_dx)
		check(saw_live and got_snap_event, "host auto-snap reached client (snapshot LIVE + reliable event)")
		check(bad_snap_rejected, "defense snap rejected by server")
		print("NET FLOW " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
