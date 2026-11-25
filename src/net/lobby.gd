extends RefCounted
## Private match lobby state. Pure; server-authoritative, mirrored to clients.

enum Phase { LOBBY, IN_GAME }
const SIZES := [3, 5, 7]
const HALF_MINUTES := [2, 5, 8]

var phase: Phase = Phase.LOBBY
var host_id := 1
var code := ""
var settings := {"size": 7, "half_minutes": 5}
var players := {}   # id -> {"name": String, "ready": bool}

func add(id: int, name: String = "") -> void:
	if not players.has(id):
		players[id] = {"name": name if name != "" else "Player %d" % (players.size() + 1), "ready": false}

func remove(id: int) -> void:
	players.erase(id)

func set_ready(id: int, ready: bool) -> bool:
	if phase != Phase.LOBBY or not players.has(id):
		return false
	players[id]["ready"] = ready
	return true

func toggle_ready(id: int) -> bool:
	return players.has(id) and set_ready(id, not players[id]["ready"])

func set_name(id: int, name: String) -> bool:
	if not players.has(id):
		return false
	var n := name.strip_edges().left(16)
	if n == "":
		return false
	players[id]["name"] = n
	return true

## Host-only, lobby-only, validated.
func set_setting(by: int, key: String, value) -> bool:
	if by != host_id or phase != Phase.LOBBY:
		return false
	match key:
		"size":
			if not (value is int and SIZES.has(value)):
				return false
		"half_minutes":
			if not (value is int and HALF_MINUTES.has(value)):
				return false
		_:
			return false
	settings[key] = value
	for id in players:
		players[id]["ready"] = id == host_id and players[id]["ready"]   # settings changed: re-ready
	return true

func all_ready() -> bool:
	if players.size() < 2:
		return false
	for id in players:
		if not players[id]["ready"]:
			return false
	return true

func start() -> bool:
	if phase != Phase.LOBBY or not all_ready():
		return false
	phase = Phase.IN_GAME
	return true

func to_dict() -> Dictionary:
	return {"phase": phase, "host": host_id, "code": code, "settings": settings.duplicate(), "players": players.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	phase = int(d.get("phase", 0))
	host_id = int(d.get("host", 1))
	code = str(d.get("code", ""))
	var s = d.get("settings", {})
	if s is Dictionary:
		settings = {"size": int(s.get("size", 7)), "half_minutes": int(s.get("half_minutes", 5))}
	var p = d.get("players", {})
	players = p if p is Dictionary else {}

func summary() -> String:
	var names := []
	for id in players:
		names.append("%s%s" % [players[id]["name"], " ✓" if players[id]["ready"] else ""])
	return "%dv%d, %d-min halves | %s" % [settings["size"], settings["size"], settings["half_minutes"], ", ".join(names)]
