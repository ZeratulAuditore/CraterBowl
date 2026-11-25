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
var last_server_x := INF
var aid_before_swap := -1
var aid_before_pick := -1
var swapped_to_team0 := false
var pick_rejected := false
var first_team := -1
var saw_lobby := false
var lobby_size := 0
var lobby_code := ""
var lead_samples := 0

func check(cond: bool, msg: String) -> void:
	print(("  NET OK   " if cond else "  NET FAIL ") + msg)
	if not cond:
		ok = false

func _on_snap(s: Dictionary) -> void:
	snaps += 1
	if aid >= 0:
		last_server_x = (s["a"] as PackedFloat32Array)[aid * 7]
	if s["ph"] == 1:
		saw_live = true

func _on_lobby(st: Dictionary) -> void:
	if not saw_lobby and st.get("phase", 1) == 0:
		saw_lobby = true
		lobby_size = int(st.get("settings", {}).get("size", 0))
		lobby_code = str(st.get("code", ""))
		main.lobby_key(KEY_ENTER)   # ready up through the real lobby key path

func _on_welcome(id: int) -> void:
	aid = id
	if first_team < 0:
		first_team = main.world.get_athlete(id).team

func _on_event(n: String, _d: Dictionary) -> void:
	if n == "snap":
		got_snap_event = true

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_dt: float) -> bool:
	f += 1
	if f == 2:
		main.net.lobby_received.connect(_on_lobby)
		main.net.welcomed.connect(_on_welcome)
		main.net.snapshot_received.connect(_on_snap)
		main.net.event_received.connect(_on_event)
	if aid >= 0 and snaps > 3:
		var x: float = main.world.get_athlete(aid).position.x
		if start_x == INF:
			start_x = x
			main.input_override = Vector2(1, 0)  # strafe right (legal presnap for defense)

		max_dx = maxf(max_dx, x - start_x)
	# With prediction, the locally shown position leads the last raw server state while moving.
	if aid >= 0 and main.input_override == Vector2(1, 0) and last_server_x != INF and main.world.phase == 0:
		if main.world.get_athlete(aid).position.x - last_server_x > 0.02:
			lead_samples += 1
	# After the first play ends and the next presnap begins, try an illegal defense snap.
	if saw_live and bad_snap_sent_at < 0 and main.world.phase == 0:
		main.input_override = Vector2.ZERO
		main.do_action({"a": "snap"})
		bad_snap_sent_at = f
	if bad_snap_sent_at > 0 and f == bad_snap_sent_at + 30:
		bad_snap_rejected = main.world.phase == 0
		aid_before_swap = aid
		main.do_action({"a": "team"})
	if bad_snap_sent_at > 0 and f == bad_snap_sent_at + 60:
		swapped_to_team0 = aid != aid_before_swap and main.world.get_athlete(aid).team == 0
		aid_before_pick = aid
		main.do_action({"a": "pick", "slot": 0})  # host's QB/LB slot: must be rejected
	if bad_snap_sent_at > 0 and f == bad_snap_sent_at + 90:
		pick_rejected = aid == aid_before_pick
	if f == 1100 or (bad_snap_sent_at > 0 and f == bad_snap_sent_at + 91):
		check(saw_lobby and lobby_size == 5 and lobby_code.length() == 11, "joined by code into the private lobby (5v5, code %s)" % lobby_code)
		check(aid >= 0, "readied up -> match started -> welcomed with athlete %d" % aid)
		check(first_team == 1, "joiner initially placed on the opponent team")
		check(main.match_size == 5 and main.world.athletes.size() == 10, "client adopted host's 5v5 (%d athletes)" % main.world.athletes.size())
		check(snaps > 20, "receiving snapshots (%d)" % snaps)
		check(max_dx > 2.0, "own input moved own athlete on server (dx %.1f)" % max_dx)
		check(lead_samples > 10, "own athlete predicted ahead of server state (%d frames)" % lead_samples)
		check(saw_live and got_snap_event, "host auto-snap reached client (snapshot LIVE + reliable event)")
		check(bad_snap_rejected, "defense snap rejected by server")
		check(swapped_to_team0, "team swap request -> server reassigned to team 0")
		check(pick_rejected, "picking the host's occupied slot rejected")
		print("NET FLOW " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
