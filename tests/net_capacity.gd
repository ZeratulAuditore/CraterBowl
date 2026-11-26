extends SceneTree
## Lobby seat cap (#54), one process: the real main scene hosts, bare NetSession
## clients join over localhost. Run: godot --headless -s res://tests/net_capacity.gd -- --port=N
##   1. 5v5 lobby, 6 joiners -> 7 players (fits 10 seats).
##   2. Host presses 3 and M: both refused (7 players don't fit 3v3), host sees why.
##   3. One joiner leaves -> 6 players; host presses 3 -> 3v3, 6/6 seats.
##   4. A 7th joiner is refused with a visible "Lobby full" reason and disconnected.
##   5. Everyone readies -> match starts -> every remaining joiner is welcomed (none stranded).
##   6. A joiner arriving mid-match with every seat taken is refused with a reason too.

const NetSession := preload("res://src/net/net_session.gd")

var main
var port := 0
var ok := true
var clients: Array = []      # NetSession nodes
var welcomed := {}           # client index -> athlete id
var stage := 0
var wait := 0                # frames spent in the current stage
var f := 0

func check(cond: bool, msg: String) -> void:
	print(("  CAP OK   " if cond else "  CAP FAIL ") + msg)
	if not cond:
		ok = false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.get_slice("=", 1))
	if port == 0:
		port = 26000 + randi() % 3000
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _join() -> void:
	var c = NetSession.new()
	c.name = "Client%d" % clients.size()
	root.add_child(c)
	var i := clients.size()
	c.welcomed.connect(func(aid): welcomed[i] = aid)
	c.lobby_received.connect(func(st): c.set_meta("lobby", st))
	clients.append(c)
	c.join("127.0.0.1", port)

func _reason(i: int) -> String:
	var r = clients[i].get("refused_reason")
	return str(r) if r != null else ""

func _connected(i: int) -> bool:
	var c = clients[i]
	return c.peer != null and c.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _host_key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	main._unhandled_key_input(e)

func _next() -> void:
	stage += 1
	wait = 0

func _physics_process(_dt: float) -> bool:
	f += 1
	wait += 1
	match stage:
		0:
			if f == 2:
				main.match_size = 5
				main._host_game(port, {"size": 5})
				for i in 6:
					_join()
				_next()
		1:
			if main.lobby.players.size() == 7 or wait > 300:
				check(main.lobby.players.size() == 7, "5v5 lobby holds host + 6 joiners (%d players)" % main.lobby.players.size())
				_host_key(KEY_3)
				check(main.lobby.settings["size"] == 5, "host 3 refused: 7 players don't fit 3v3 (size %d)" % main.lobby.settings["size"])
				check(str(main.lobby.get("notice")).contains("6"), "host sees why 3v3 was refused: %s" % str(main.lobby.get("notice")))
				_host_key(KEY_M)
				check(main.lobby.settings["mode"] == "classic" and main.lobby.settings["size"] == 5, "host M (Chaosball 3v3) refused while over capacity")
				clients[5].peer.close()
				_next()
		2:
			if main.lobby.players.size() == 6 or wait > 300:
				check(main.lobby.players.size() == 6, "a joiner left -> 6 players")
				_host_key(KEY_3)
				check(main.lobby.settings["size"] == 3, "host 3 accepted once 6 players fit 3v3")
				check(str(main.lobby.get("notice")) == "", "refusal notice clears on an accepted change")
				_join()   # client 6: the 7th player for 6 seats
				_next()
		3:
			if _reason(6) != "" or wait > 300:
				check(_reason(6).contains("Lobby full"), "7th player refused with a visible reason: '%s'" % _reason(6))
				check(main.lobby.players.size() == 6, "refused joiner never entered the lobby (%d players)" % main.lobby.players.size())
				_next()
		4:
			if (not _connected(6) and main.net.api.get_peers().size() == 5) or wait > 300:
				check(not _connected(6), "refused joiner is disconnected")
				check(main.net.api.get_peers().size() == 5, "host keeps exactly the 5 seated joiners (%d peers)" % main.net.api.get_peers().size())
				for i in clients.size():   # everyone still connected readies (pre-fix: incl. the 7th)
					if _connected(i):
						clients[i].send_lobby_action({"a": "ready"})
				_host_key(KEY_ENTER)
				_next()
		5:
			if welcomed.size() >= 5 or wait > 400:
				check(main.lobby.phase == main.Lobby.Phase.IN_GAME, "everyone ready -> 3v3 match started")
				var aids := {}
				for i in 5:
					if welcomed.has(i) and welcomed[i] >= 0:
						aids[welcomed[i]] = true
				check(aids.size() == 5, "all 5 joiners welcomed with distinct athletes, none stranded (%s)" % str(welcomed))
				check(not welcomed.has(6), "the refused joiner was never welcomed")
				var stranded := []
				for i in clients.size():
					if _connected(i) and not (welcomed.has(i) and welcomed[i] >= 0):
						stranded.append(i)
				check(stranded.is_empty(), "no connected peer left in the lobby without an athlete (stranded: %s)" % str(stranded))
				_join()   # client 7: arrives mid-match, all 6 seats taken
				_next()
		6:
			if _reason(7) != "" or wait > 300:
				check(_reason(7).contains("full"), "mid-match joiner with no free seat refused with a reason: '%s'" % _reason(7))
				_next()
		7:
			if not _connected(7) or wait > 300:
				check(not _connected(7), "mid-match refused joiner is disconnected")
				print("NET CAPACITY " + ("PASS" if ok else "FAIL"))
				quit(0 if ok else 1)
	return false
