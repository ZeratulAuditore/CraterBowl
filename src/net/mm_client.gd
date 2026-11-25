extends Node
## Queue client: connect to the matchmaker, enqueue, receive host/join orders.

signal queued(ok: bool, n: int)
signal host_match(settings: Dictionary)
signal join_match(code: String)

var api: SceneMultiplayer
var peer: ENetMultiplayerPeer
var _req := {}

func queue_up(address: String, port: int, mode: String, size: int, rating: float, name: String = "", party: String = "", party_size: int = 1) -> Error:
	api = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	api.peer_packet.connect(_on_packet)
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	api.multiplayer_peer = peer
	_req = {"k": "enq", "mode": mode, "size": size, "rating": rating, "name": name, "party": party, "party_size": party_size}
	api.connected_to_server.connect(func(): _send(_req))
	return OK

func send_hosting(code: String) -> void:
	_send({"k": "hosting", "code": code})

func _send(msg: Dictionary) -> void:
	api.send_bytes(var_to_bytes(msg), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _on_packet(from: int, bytes: PackedByteArray) -> void:
	var msg = bytes_to_var(bytes)
	if from != 1 or not (msg is Dictionary):
		return
	match msg.get("k", ""):
		"queued":
			queued.emit(msg.get("ok", false) == true, int(msg.get("n", 0)))
		"match":
			if msg.get("role", "") == "host":
				host_match.emit(msg)
			elif msg.get("role", "") == "join":
				join_match.emit(str(msg.get("code", "")))
