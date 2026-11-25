extends RefCounted
## Graphics quality preset (view-only). --gfx=low|medium|high, else auto:
## software rasterizers (llvmpipe/lavapipe/SwiftShader) get "low".

static var _level := ""

static func level() -> String:
	if _level == "":
		_level = "high"
		for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			if a.begins_with("--gfx="):
				_level = a.substr(6)
		if not _level in ["low", "medium", "high"]:
			_level = "high"
		var forced := false
		for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			forced = forced or a.begins_with("--gfx=")
		if not forced:
			var gpu := RenderingServer.get_video_adapter_name().to_lower()
			if gpu.contains("llvmpipe") or gpu.contains("lavapipe") or gpu.contains("swiftshader") or gpu.contains("software"):
				_level = "low"
	return _level

static func set_level(l: String) -> void:
	_level = l

static func at_least(l: String) -> bool:
	var order := ["low", "medium", "high"]
	return order.find(level()) >= order.find(l)
