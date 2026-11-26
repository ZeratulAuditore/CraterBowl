extends Node
## ENet transport. Server: assigns athletes to peers, collects inputs/actions,
## broadcasts snapshots + events. Client: sends inputs/actions, receives state.

signal welcomed(athlete_id: int)
signal snapshot_received(snap: Dictionary)
signal event_received(n: String, d: Dictionary)
signal peer_joined(peer_id: int, athlete_id: int)
signal peer_left(peer_id: int, athlete_id: int)
signal lobby_received(state: Dictionary)
signal lobby_changed()

const P := preload("res://src/net/protocol.gd")
const DEFAULT_PORT := 24565
const MAX_PEERS := 13

enum Mode { OFFLINE, SERVER, CLIENT }

var mode: Mode = Mode.OFFLINE
var peer: ENetMultiplayerPeer
var api: SceneMultiplayer
var assign_fn: Callable       # server: func(peer_id) -> athlete_id or -1
var release_fn: Callable      # server: func(peer_id)
var peer_athlete := {}         # server: peer_id -> athlete_id
var inputs := {}               # server: athlete_id -> sanitized input
var actions: Array = []        # server: [[peer_id, athlete_id, action], ...] pending
var my_athlete := -1           # client
var match_size := 7            # server: sent in welcome
var match_mode := "classic"    # server: sent in welcome
var host_size := 7             # client: host's match size from welcome
var host_mode := "classic"     # client: host's ruleset from welcome
var lobby_mode := false        # server: joiners wait in the lobby (no athlete) until start
var lobby                      # server: Lobby (set by main)
var lobby_actions: Array = []  # server: [[peer_id, action], ...]
var last_snapshot_tick := -1

func _ready() -> void:
	api = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	api.peer_packet.connect(_on_packet)

func host(port: int, assign: Callable, release: Callable) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		return err
	api.multiplayer_peer = peer
	assign_fn = assign
	release_fn = release
	api.peer_connected.connect(_on_peer_connected)
	api.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.SERVER
	return OK

func join(address: String, port: int) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	api.multiplayer_peer = peer
	mode = Mode.CLIENT
	return OK

func human_athletes() -> Array:
	return peer_athlete.values()

func _send(target: int, msg: Dictionary, reliable: bool) -> void:
	var m := MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	api.send_bytes(var_to_bytes(msg), target, m, 0 if reliable else 1)

# ---- server ----
func _on_peer_connected(id: int) -> void:
	if lobby_mode and lobby != null and lobby.phase == lobby.Phase.LOBBY:
		lobby.add(id)
		lobby_changed.emit()
		return
	var aid: int = assign_fn.call(id)
	if aid < 0:
		peer.disconnect_peer(id)
		return
	set_assignment(id, aid)
	peer_joined.emit(id, aid)

## Server: (re)assign a peer to an athlete and tell them.
func set_assignment(id: int, aid: int) -> void:
	if peer_athlete.has(id):
		inputs.erase(peer_athlete[id])
	peer_athlete[id] = aid
	_send(id, {"k": "welcome", "aid": aid, "size": match_size, "mode": match_mode}, true)

func _on_peer_disconnected(id: int) -> void:
	if lobby != null and lobby.players.has(id):
		lobby.remove(id)
		lobby_changed.emit()
	if peer_athlete.has(id):
		var aid: int = peer_athlete[id]
		peer_athlete.erase(id)
		inputs.erase(aid)
		release_fn.call(id)
		peer_left.emit(id, aid)

func broadcast_snapshot(snap: Dictionary) -> void:
	if mode == Mode.SERVER and not peer_athlete.is_empty():
		_send(0, snap, false)

func broadcast_event(n: String, d: Dictionary) -> void:
	if mode == Mode.SERVER and not peer_athlete.is_empty():
		_send(0, {"k": "ev", "n": n, "d": d}, true)

func broadcast_lobby(state: Dictionary) -> void:
	if mode == Mode.SERVER and not api.get_peers().is_empty():
		_send(0, {"k": "lobby", "s": state}, true)

func take_lobby_actions() -> Array:
	var out := lobby_actions
	lobby_actions = []
	return out

func send_lobby_action(action: Dictionary) -> void:
	if mode == Mode.CLIENT:
		_send(1, {"k": "lact", "act": action}, true)

func take_actions() -> Array:
	var out := actions
	actions = []
	return out

# ---- client ----
func send_input(dir: Vector2, sprint: bool, seq: int = 0, block := false) -> void:
	if mode == Mode.CLIENT and my_athlete >= 0:
		_send(1, {"k": "in", "dir": dir, "spr": sprint, "seq": seq, "block": block}, false)

## Server: athlete_id -> last processed input seq (for client reconciliation).
func acks() -> Dictionary:
	var out := {}
	for aid in inputs:
		out[aid] = inputs[aid].get("seq", 0)
	return out

func send_action(action: Dictionary) -> void:
	if mode == Mode.CLIENT and my_athlete >= 0:
		_send(1, {"k": "act", "act": action}, true)

# ---- both ----
func _on_packet(from: int, bytes: PackedByteArray) -> void:
	var msg = bytes_to_var(bytes)   # never decodes objects
	if not (msg is Dictionary):
		return
	match msg.get("k", ""):
		"in":
			if mode == Mode.SERVER and peer_athlete.has(from):
				var inp := P.sanitize_input(msg)
				var aid: int = peer_athlete[from]
				# unreliable-ordered, but never go backwards in seq
				if not inp.is_empty() and inp["seq"] >= inputs.get(aid, {}).get("seq", -1):
					inputs[aid] = inp
		"act":
			if mode == Mode.SERVER and peer_athlete.has(from) and P.is_action(msg.get("act")):
				actions.append([from, peer_athlete[from], msg["act"]])
		"lact":
			if mode == Mode.SERVER and lobby != null and lobby.players.has(from) and msg.get("act") is Dictionary:
				lobby_actions.append([from, msg["act"]])
		"lobby":
			if mode == Mode.CLIENT and from == 1 and msg.get("s") is Dictionary:
				lobby_received.emit(msg["s"])
		"welcome":
			if mode == Mode.CLIENT and from == 1:
				my_athlete = int(msg.get("aid", -1))
				var sz = msg.get("size", 7)
				host_size = int(sz) if (sz is int and (sz == 3 or sz == 5 or sz == 7)) else 7
				host_mode = "chaosball" if msg.get("mode", "") == "chaosball" else "classic"
				welcomed.emit(my_athlete)
		"snap":
			if mode == Mode.CLIENT and from == 1 and int(msg.get("t", -1)) > last_snapshot_tick:
				last_snapshot_tick = int(msg["t"])
				snapshot_received.emit(msg)
		"ev":
			if mode == Mode.CLIENT and from == 1:
				event_received.emit(str(msg.get("n", "")), msg.get("d", {}) if msg.get("d") is Dictionary else {})
