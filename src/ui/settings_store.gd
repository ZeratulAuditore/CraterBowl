extends RefCounted
## Player settings persisted to user://settings.cfg (ConfigFile). Pure data + an
## apply() that pushes video/audio values into the engine. Tests pass a temp path.

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULT_MM := "127.0.0.1:24600"   # matchmaker; point at the hosted one once deployed
const FPS_CAPS := [0, 30, 60, 120, 144, 240]

var player_name := ""            # "" = ask on first launch
var fullscreen := false
var vsync := true
var render_scale := 1.0          # 3D resolution scale (0.5..1.0)
var max_fps := 0                 # 0 = unlimited
var master_volume := 0.8         # 0..1 linear
var music_volume := 0.7          # 0..1 linear, menu soundtrack
var home_mode := ""              # last mode picked on the home screen's PLAY selector
var matchmaker := DEFAULT_MM     # host[:port]
var upnp := true                 # try to open the port on the router when hosting
var bindings := {}               # action -> keycode overrides (see controls.gd)

func load_file(path: String = DEFAULT_PATH) -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	player_name = clean_name(str(cf.get_value("player", "name", player_name)))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cf.get_value("video", "vsync", vsync))
	render_scale = clampf(float(cf.get_value("video", "render_scale", render_scale)), 0.5, 1.0)
	max_fps = int(cf.get_value("video", "max_fps", max_fps))
	if not FPS_CAPS.has(max_fps):
		max_fps = 0
	master_volume = clampf(float(cf.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	home_mode = str(cf.get_value("player", "home_mode", home_mode))
	matchmaker = str(cf.get_value("online", "matchmaker", matchmaker)).strip_edges()
	if matchmaker == "":
		matchmaker = DEFAULT_MM
	upnp = bool(cf.get_value("online", "upnp", upnp))
	var b = cf.get_value("controls", "bindings", {})
	bindings = b if b is Dictionary else {}

func save(path: String = DEFAULT_PATH) -> bool:
	var cf := ConfigFile.new()
	cf.set_value("player", "name", player_name)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "vsync", vsync)
	cf.set_value("video", "render_scale", render_scale)
	cf.set_value("video", "max_fps", max_fps)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("player", "home_mode", home_mode)
	cf.set_value("online", "matchmaker", matchmaker)
	cf.set_value("online", "upnp", upnp)
	cf.set_value("controls", "bindings", bindings)
	return cf.save(path) == OK

## Names: 2..16 printable chars, no "|" (leaderboard key separator), not reserved.
static func clean_name(s: String) -> String:
	var out := ""
	for c in s.strip_edges():
		if c != "|" and c.unicode_at(0) >= 32:
			out += c
	out = out.strip_edges().left(16)
	if out.length() < 2 or out.to_lower() in ["you", "bot", "host"]:
		return ""
	return out

## Split "host[:port]" with a default port.
static func split_address(addr: String, default_port: int) -> Array:
	addr = addr.strip_edges()
	var i := addr.rfind(":")
	if i > 0 and addr.substr(i + 1).is_valid_int():
		return [addr.substr(0, i), int(addr.substr(i + 1))]
	return [addr, default_port]

func apply(window: Window) -> void:
	if DisplayServer.get_name() != "headless" and window != null:
		window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if window != null:
		window.scaling_3d_scale = render_scale
	Engine.max_fps = max_fps
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
