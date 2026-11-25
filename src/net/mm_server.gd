extends Node
## Headless matchmaking server: queues players, elects a host per match,
## relays the host's invite code to the others.

const MM := preload("res://src/net/matchmaker.gd")
const DEFAULT_PORT := 24600

var api: SceneMultiplayer
var peer: ENetMultiplayerPeer
var mm := MM.new()
var pending := {}   # host peer id -> {"others": [ids], "match": Dictionary}

func start(port: int) -> Error:
	api = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	api.peer_packet.connect(_on_packet)
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 64)
	if err != OK:
		return err
	api.multiplayer_peer = peer
	api.peer_disconnected.connect(func(id): mm.dequeue(id); pending.erase(id))
	return OK

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _send(id: int, msg: Dictionary) -> void:
	api.send_bytes(var_to_bytes(msg), id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _on_packet(from: int, bytes: PackedByteArray) -> void:
	var msg = bytes_to_var(bytes)
	if not (msg is Dictionary):
		return
	match msg.get("k", ""):
		"enq":
			var size = msg.get("size", 7)
			var rating = msg.get("rating", 1000.0)
			var ok := mm.enqueue(from, str(msg.get("mode", "")), int(size) if size is int else 7,
				float(rating) if (rating is float or rating is int) else 1000.0, _now())
			_send(from, {"k": "queued", "ok": ok, "n": mm.queue.size()})
			print("MM enqueue %d -> %s (queue %d)" % [from, ok, mm.queue.size()])
		"hosting":
			if pending.has(from):
				var code := str(msg.get("code", ""))
				for o in pending[from]["others"]:
					_send(o, {"k": "match", "role": "join", "code": code})
				print("MM host %d ready with %s -> %d joiners" % [from, code, pending[from]["others"].size()])
				pending.erase(from)

func _process(_dt: float) -> void:
	if api == null:
		return
	for m in mm.tick(_now()):
		var others: Array = m["players"].filter(func(p): return p != m["host"])
		pending[m["host"]] = {"others": others, "match": m}
		_send(m["host"], {"k": "match", "role": "host", "mode": m["mode"], "size": m["size"],
			"expected": m["players"].size(), "teams": m["teams"]})
		print("MM formed %s %dv%d: %s (host %d)" % [m["mode"], m["size"], m["size"], str(m["players"]), m["host"]])
