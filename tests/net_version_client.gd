extends SceneTree
## #165 (net_test.sh phase 3): a client launched with a forced wrong protocol version
## (`--protocol-version=0`) joins a real host and must be refused through the existing
## refuse() path: the join screen shows "Update Crater Bowl to play online (server is vX,
## you have v0)" and the client is never welcomed or seated.

const P := preload("res://src/net/protocol.gd")

var main
var f := 0
var ok := true
var welcomed := false

func check(cond: bool, msg: String) -> void:
	print(("  NET OK   " if cond else "  NET FAIL ") + msg)
	if not cond:
		ok = false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_dt: float) -> bool:
	f += 1
	if f == 2:
		check(main.is_client(), "launched as a joining client")
		check(main.net.protocol_version == 0 and P.VERSION != 0, "--protocol-version=0 forces a wrong version (real v%d)" % P.VERSION)
		main.net.welcomed.connect(func(_aid): welcomed = true)
	if f > 2 and main.net.refused_reason != "" and f % 10 == 0:   # let the HUD redraw
		var want := "Update Crater Bowl to play online (server is v%d, you have v0)" % P.VERSION
		print("NET version refusal: %s" % main.net.refused_reason)
		check(main.net.refused_reason == want, "refused with the version reason")
		check(main.net.version_refused, "flagged as a version refusal")
		check(main.hud.text.contains("COULDN'T JOIN THE MATCH") and main.hud.text.contains(want), "join screen shows the reason: %s" % main.hud.text.replace("\n", " | "))
		check(not main.hud.text.contains("bigger match"), "no capacity hint on a version refusal")
		check(not welcomed and main.net.my_athlete < 0, "never welcomed or seated")
		quit(0 if ok else 1)
	if f > 1200:
		check(false, "refused within 20 s (got '%s')" % main.net.refused_reason)
		quit(1)
	return false
