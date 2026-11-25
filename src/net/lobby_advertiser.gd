extends Node
## Host side of the server browser: keeps this match's lobby registered with the
## matchmaker (player count, phase) until the host leaves. Attached by Launch when
## the menu launched a public host. Reads the game scene; never changes it.

const MMClient := preload("res://src/net/mm_client.gd")
const MMServer := preload("res://src/net/mm_server.gd")
const Settings := preload("res://src/ui/settings_store.gd")
const EVERY := 5.0

var game: Node
var title := "Match"
var client: MMClient
var _t := EVERY
var registered := false

func setup(g: Node, address: String, match_title: String) -> Error:
	game = g
	title = match_title
	client = MMClient.new()
	client.name = "AdvertiseClient"
	add_child(client)
	client.registered.connect(func(ok): registered = ok)
	var hp := Settings.split_address(address, MMServer.DEFAULT_PORT)
	return client.open(hp[0], hp[1])

## What we tell the browser about this match (null if not hosting a lobby yet).
static func lobby_info(g: Node, match_title: String):
	if g == null or g.get("lobby") == null or str(g.lobby.code) == "":
		return null
	return {"code": g.lobby.code, "name": match_title, "size": int(g.lobby.settings.get("size", 7)),
		"mode": str(g.lobby.settings.get("mode", "classic")), "players": g.lobby.players.size(),
		"in_game": g.lobby.phase != 0}

func _process(dt: float) -> void:
	_t += dt
	if _t < EVERY or client == null or not client.is_open():
		return
	_t = 0.0
	var info = lobby_info(game, title)
	if info != null:
		client.register_lobby(info)

func _exit_tree() -> void:
	if client and client.is_open():
		client.unregister_lobby()
		client.peer.close()
