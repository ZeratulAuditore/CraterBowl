extends Node
## ENet transport. Server: assigns athletes to peers, collects inputs/actions,
## broadcasts snapshots + events. Client: sends inputs/actions, receives state.

signal welcomed(athlete_id: int)
signal snapshot_received(snap: Dictionary)
signal event_received(n: String, d: Dictionary)
signal peer_joined(peer_id: int, athlete_id: int)
signal peer_left(peer_id: int, athlete_id: int)

const P := preload("res://src/net/protocol.gd")
const DEFAULT_PORT := 24565
const MAX_PEERS := 13

enum Mode { OFFLINE, SERVER, CLIENT }

var mode: Mode = Mode.OFFLINE
var peer: ENetMultiplayerPeer
var api: SceneMultiplayer
var athlete_pool: Array = []   # server: athletes available to assign, in order
var peer_athlete := {}         # server: peer_id -> athlete_id
var inputs := {}               # server: athlete_id -> sanitized input
var actions: Array = []        # server: [[athlete_id, action], ...] pending
var my_athlete := -1           # client
var last_snapshot_tick := -1

func _ready() -> void:
	api = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	api.peer_packet.connect(_on_packet)

func host(port: int, pool: Array) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		return err
	api.multiplayer_peer = peer
	athlete_pool = pool.duplicate()
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
	if athlete_pool.is_empty():
		peer.disconnect_peer(id)
		return
	var aid: int = athlete_pool.pop_front()
	peer_athlete[id] = aid
	_send(id, {"k": "welcome", "aid": aid}, true)
	peer_joined.emit(id, aid)

func _on_peer_disconnected(id: int) -> void:
	if peer_athlete.has(id):
		var aid: int = peer_athlete[id]
		peer_athlete.erase(id)
		inputs.erase(aid)
		athlete_pool.push_front(aid)
		peer_left.emit(id, aid)

func broadcast_snapshot(snap: Dictionary) -> void:
	if mode == Mode.SERVER and not peer_athlete.is_empty():
		_send(0, snap, false)

func broadcast_event(n: String, d: Dictionary) -> void:
	if mode == Mode.SERVER and not peer_athlete.is_empty():
		_send(0, {"k": "ev", "n": n, "d": d}, true)

func take_actions() -> Array:
	var out := actions
	actions = []
	return out

# ---- client ----
func send_input(dir: Vector2, sprint: bool) -> void:
	if mode == Mode.CLIENT and my_athlete >= 0:
		_send(1, {"k": "in", "dir": dir, "spr": sprint}, false)

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
				if not inp.is_empty():
					inputs[peer_athlete[from]] = inp
		"act":
			if mode == Mode.SERVER and peer_athlete.has(from):
				actions.append([peer_athlete[from], msg.get("act", {})])
		"welcome":
			if mode == Mode.CLIENT and from == 1:
				my_athlete = int(msg.get("aid", -1))
				welcomed.emit(my_athlete)
		"snap":
			if mode == Mode.CLIENT and from == 1 and int(msg.get("t", -1)) > last_snapshot_tick:
				last_snapshot_tick = int(msg["t"])
				snapshot_received.emit(msg)
		"ev":
			if mode == Mode.CLIENT and from == 1:
				event_received.emit(str(msg.get("n", "")), msg.get("d", {}) if msg.get("d") is Dictionary else {})
