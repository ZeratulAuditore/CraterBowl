extends Control
## Crater Bowl main menu. Every "start" button calls Launch.start_game(opts) with the
## same keys as the CLI flags (host, join, queue, practice, size, mode, replay...).

const UITheme := preload("res://src/ui/ui_theme.gd")
const Settings := preload("res://src/ui/settings_store.gd")
const Controls := preload("res://src/ui/controls.gd")
const Cosmetics := preload("res://src/sim/cosmetics.gd")
const Leaderboard := preload("res://src/sim/leaderboard.gd")
const Ranked := preload("res://src/sim/ranked.gd")
const Drills := preload("res://src/sim/drills.gd")
const InviteCode := preload("res://src/net/invite_code.gd")
const Browser := preload("res://src/ui/server_browser.gd")
const PortMapper := preload("res://src/net/port_mapper.gd")
const NetSession := preload("res://src/net/net_session.gd")
const QUEUE_HOST_PORT := 24566    # fixed so UPnP can map it before queueing
const SIZES := [3, 5, 7]

var launch                    # the Launch autoload (or a stand-in in tests)
var nav: VBoxContainer
var content: VBoxContainer
var status_label: Label
var nav_buttons := {}         # screen id -> Button
var current := ""
var profile := Cosmetics.new()
var profile_path := Cosmetics.DEFAULT_PATH
var leaderboard_path := Leaderboard.DEFAULT_PATH
var ranked_path := Ranked.DEFAULT_PATH
var replay_dir := "user://replays"
var pick_size := 5
var pick_mode := "classic"
var _capture_action := ""     # controls screen: waiting for a key for this action
var _capture_button: Button
var browser: Node
var list_public := true
var host_port := NetSession.DEFAULT_PORT
var party_code := ""
var party_size := 1          # 1 = solo
var _upnp_thread: Thread
var busy := false

func _ready() -> void:
	launch = get_node_or_null("/root/Launch")
	if launch and not launch.menu_visited and launch.should_skip_menu(OS.get_cmdline_user_args(), DisplayServer.get_name()) and not has_meta("force_menu"):
		get_tree().change_scene_to_file.call_deferred(launch.GAME_SCENE)
		return
	build()

func settings() -> Settings:
	return launch.settings

func build() -> void:
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48 if side in ["left", "right"] else 36)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var logo := TextureRect.new()
	logo.texture = UITheme.svg_texture("res://assets/brand/logo_stacked.svg", 0.38)
	if logo.texture == null:
		push_error("MENU logo missing (svg not exported?)")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(320, 205)
	left.add_child(logo)
	nav = VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	left.add_child(nav)
	for item in [["online", "Play online"], ["bots", "Play vs bots"], ["practice", "Training"],
			["locker", "Locker"], ["leaders", "Leaderboards"], ["replays", "Replays"],
			["settings", "Settings"], ["quit", "Quit"]]:
		var b := Button.new()
		b.text = item[1].to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 21)
		var id: String = item[0]
		b.pressed.connect(func(): show_screen(id))
		b.focus_entered.connect(func(): if id != "quit" and current != "welcome": show_screen(id))
		nav.add_child(b)
		nav_buttons[id] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var ver := Label.new()
	ver.text = "v%s" % launch.version()
	ver.add_theme_color_override("font_color", Color(UITheme.REGOLITH, 0.8))
	ver.add_theme_font_size_override("font_size", 14)
	left.add_child(ver)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", UITheme.ORANGE)
	status_label.text = launch.last_status
	left.add_child(status_label)
	launch.last_status = ""
	profile.load_file(profile_path)
	if settings().player_name == "":
		show_screen("welcome")
	else:
		show_screen("online")
		nav_buttons["online"].grab_focus.call_deferred()

## ------------------------------------------------------------------ screens
func show_screen(id: String) -> void:
	if id == "quit":
		get_tree().quit()
		return
	if id == current:
		return
	current = id
	if browser:
		browser.queue_free()
		browser = null
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	for k in nav_buttons:
		nav_buttons[k].add_theme_color_override("font_color", UITheme.CYAN if k == id else UITheme.CREAM)
	call("_screen_" + id)

func _screen_welcome() -> void:
	content.add_child(UITheme.heading("Welcome to the Crater", 40, UITheme.CYAN))
	_text("Pick a name. It shows on scoreboards, leaderboards and your ranked rating. You can change it in Settings.")
	var name_edit := _line("Your name", "")
	name_edit.name = "NameEdit"
	var go := _button("Continue", func():
		var n := Settings.clean_name(name_edit.text)
		if n == "":
			_status("Names need 2-16 characters (and can't be You/Bot/Host).")
			return
		settings().player_name = n
		launch.save_settings()
		current = ""
		show_screen("online"))
	name_edit.text_submitted.connect(func(_t): go.pressed.emit())
	name_edit.grab_focus.call_deferred()

func _screen_online() -> void:
	content.add_child(UITheme.heading("Play online"))
	_text("Playing as %s  ·  %s" % [settings().player_name, _rating_line()])
	content.add_child(UITheme.heading("Matchmaking", 22, UITheme.CYAN))
	_mode_picker()
	_size_picker(false)
	_party_row()
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 10)
	content.add_child(q)
	_button("Quick match", func(): _queue("casual"), q)
	_button("Ranked", func(): _queue("competitive"), q)
	content.add_child(UITheme.heading("Private match", 22, UITheme.CYAN))
	var pub := CheckButton.new()
	pub.text = "List publicly in the match browser"
	pub.button_pressed = list_public
	pub.toggled.connect(func(v): list_public = v)
	content.add_child(pub)
	_button("Host a match", func(): host_match())
	var j := HBoxContainer.new()
	j.add_theme_constant_override("separation", 10)
	content.add_child(j)
	var code := _line("Invite code (XXXXX-XXXXX) or IP", "", j)
	code.name = "JoinCode"
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var join := _button("Join", func(): _join(code.text), j)
	code.text_submitted.connect(func(_t): join.pressed.emit())
	content.add_child(UITheme.heading("Open matches", 22, UITheme.CYAN))
	browser = Browser.new()
	browser.name = "Browser"
	browser.setup(self, settings().matchmaker)
	content.add_child(browser)

func _screen_bots() -> void:
	content.add_child(UITheme.heading("Play vs bots"))
	_text("A full match offline. Bots fill every other slot.")
	_size_picker(true)
	_mode_picker()
	_button("Kick off", func(): launch.start_game({"size": str(pick_size), "mode": pick_mode}))

func _screen_practice() -> void:
	content.add_child(UITheme.heading("Training"))
	var desc := {"hub": "Free-roam field with a portal to each station. It's also where you wait while queued online.",
		"blocking": "You're the center. Keep the QB clean against up to 3 rushers.",
		"field": "Throw at 1/2/3-point targets and run a timed 40-yard dash.",
		"catching": "Jugs drill: a new route every rep, tighter coverage as you streak. Race to 15 catches.",
		"passing": "You're the QB. Hit receivers running the playbook.",
		"tackling": "You're the linebacker. Bring down a live runner.",
		"scrimmage": "Full 7v7 with bots. No clock, no pressure."}
	var names := {"hub": "Training ground", "field": "Practice field"}
	var order: Array = ["hub"] + Drills.STATIONS + ["passing", "tackling", "scrimmage"]
	for i in order.size():
		var k: String = order[i]
		if i == 4:
			content.add_child(UITheme.heading("Classic drills", 18, UITheme.CYAN))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		content.add_child(h)
		var b := _button(names.get(k, k.capitalize()), func(): launch.start_game({"practice": k}), h)
		b.custom_minimum_size = Vector2(190, 0)
		_text(desc.get(k, ""), h).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _screen_locker() -> void:
	content.add_child(UITheme.heading("Locker"))
	profile.load_file(profile_path)
	var lvl := profile.level()
	_text("Level %d  ·  %d XP  (%d to next level). Earn XP by playing matches; cosmetics never affect gameplay."
		% [lvl, profile.xp, Cosmetics.XP_PER_LEVEL - profile.xp % Cosmetics.XP_PER_LEVEL])
	for slot in ["trim", "helmet", "celebration", "badge"]:
		var h := HBoxContainer.new()
		content.add_child(h)
		var l := _text(slot.capitalize(), h)
		l.custom_minimum_size = Vector2(160, 0)
		var ob := OptionButton.new()
		ob.name = "Slot_" + slot
		ob.custom_minimum_size = Vector2(260, 0)
		var ids := []
		for id in Cosmetics.CATALOG.get(slot, {}).keys() + (profile.season_rewards if slot == "badge" else []):
			var ok := profile.is_unlocked(slot, id)
			var nm: String = Cosmetics.CATALOG.get(slot, {}).get(id, {}).get("name", str(id))
			var need := int(Cosmetics.CATALOG.get(slot, {}).get(id, {}).get("level", 0))
			ob.add_item(nm if ok else "%s  (level %d)" % [nm, need])
			ob.set_item_disabled(ob.item_count - 1, not ok)
			ids.append(id)
			if profile.equipped.get(slot) == id:
				ob.select(ob.item_count - 1)
		ob.item_selected.connect(func(i): _equip(slot, ids[i]))
		h.add_child(ob)
	var h2 := HBoxContainer.new()
	content.add_child(h2)
	var l2 := _text("Number", h2)
	l2.custom_minimum_size = Vector2(160, 0)
	var sb := SpinBox.new()
	sb.min_value = 0
	sb.max_value = 99
	sb.value = int(profile.equipped.get("number", 1))
	sb.value_changed.connect(func(v): _equip("number", int(v)))
	h2.add_child(sb)

func _screen_leaders() -> void:
	content.add_child(UITheme.heading("Leaderboards"))
	var lb := Leaderboard.new()
	lb.load_file(leaderboard_path)
	var rk := Ranked.new()
	rk.load_file(ranked_path)
	_text("Ranked: %s" % _rating_line())
	var pos: Array = lb.positions()
	if pos.is_empty():
		_text("No matches recorded yet. Finish a match to get on the board.")
		return
	var ob := OptionButton.new()
	for p in pos:
		ob.add_item(p)
	content.add_child(ob)
	var table := RichTextLabel.new()
	table.name = "Table"
	table.fit_content = true
	table.custom_minimum_size = Vector2(0, 300)
	content.add_child(table)
	var fill := func(i):
		table.clear()
		table.push_mono()
		table.add_text(lb.table_text(pos[i], 20))
		table.pop()
	ob.item_selected.connect(fill)
	fill.call(0)

func _screen_replays() -> void:
	content.add_child(UITheme.heading("Replays"))
	var files := list_replays(replay_dir)
	if files.is_empty():
		_text("No saved replays yet. Every finished match is saved here automatically.")
		return
	_text("Space pause · ←/→ previous/next play · [ ] speed · Esc menu")
	for f in files.slice(0, 30):
		_button(f.get_file().get_basename().replace("_", " "), func(): launch.start_game({"replay": f}))

static func list_replays(dir_path: String) -> Array:
	var out := []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if not f.begins_with("test_"):
			out.append(dir_path.path_join(f))
	out.sort()
	out.reverse()   # newest first (timestamped names)
	return out

func _screen_settings() -> void:
	var s := settings()
	content.add_child(UITheme.heading("Settings"))
	content.add_child(UITheme.heading("Player", 22, UITheme.CYAN))
	var ne := _line("Name", s.player_name)
	ne.name = "NameEdit"
	ne.text_submitted.connect(func(t): _set_name(t))
	ne.focus_exited.connect(func(): _set_name(ne.text))
	content.add_child(UITheme.heading("Video", 22, UITheme.CYAN))
	_check("Fullscreen", s.fullscreen, func(v): s.fullscreen = v; launch.save_settings())
	_check("V-Sync", s.vsync, func(v): s.vsync = v; launch.save_settings())
	_slider("3D resolution", s.render_scale, 0.5, 1.0, 0.05, func(v): s.render_scale = v; launch.save_settings())
	var fh := HBoxContainer.new()
	content.add_child(fh)
	_text("Frame cap", fh).custom_minimum_size = Vector2(200, 0)
	var fps := OptionButton.new()
	for c in Settings.FPS_CAPS:
		fps.add_item("Unlimited" if c == 0 else str(c))
	fps.select(Settings.FPS_CAPS.find(s.max_fps))
	fps.item_selected.connect(func(i): s.max_fps = Settings.FPS_CAPS[i]; launch.save_settings())
	fh.add_child(fps)
	content.add_child(UITheme.heading("Audio", 22, UITheme.CYAN))
	_slider("Master volume", s.master_volume, 0.0, 1.0, 0.05, func(v): s.master_volume = v; launch.save_settings())
	content.add_child(UITheme.heading("Online", 22, UITheme.CYAN))
	var mm := _line("Matchmaker address", s.matchmaker)
	mm.text_submitted.connect(func(t): s.matchmaker = t.strip_edges(); launch.save_settings(); _status("Matchmaker set"))
	mm.focus_exited.connect(func(): s.matchmaker = mm.text.strip_edges(); launch.save_settings())
	_check("Open my router port automatically when hosting (UPnP)", s.upnp, func(v): s.upnp = v; launch.save_settings())
	content.add_child(UITheme.heading("Controls", 22, UITheme.CYAN))
	_text("Click an action, then press a key. Gamepads work automatically. Pressing a key that's already used swaps the two actions.")
	for a in Controls.ACTIONS:
		var h := HBoxContainer.new()
		content.add_child(h)
		_text(a[1], h).custom_minimum_size = Vector2(260, 0)
		var b := Button.new()
		b.name = "Bind_" + a[0]
		b.custom_minimum_size = Vector2(160, 0)
		b.text = Controls.key_name(Controls.key_for(a[0], s.bindings))
		var act: String = a[0]
		b.pressed.connect(func(): _capture_action = act; _capture_button = b; b.text = "PRESS A KEY…")
		h.add_child(b)
	_button("Reset controls to defaults", func():
		s.bindings = {}
		launch.save_settings()
		current = ""
		show_screen("settings"))

func _unhandled_key_input(e: InputEvent) -> void:
	if _capture_action == "" or not (e is InputEventKey and e.pressed):
		return
	get_viewport().set_input_as_handled()
	var act := _capture_action
	_capture_action = ""
	if e.keycode != KEY_ESCAPE:
		capture_binding(act, e.keycode)
	current = ""
	show_screen("settings")

## Rebind (tests call this directly too).
func capture_binding(action: String, key: int) -> void:
	settings().bindings = Controls.rebind(settings().bindings, action, key)
	launch.save_settings()

## ------------------------------------------------------------------ actions
func _queue(mode: String) -> void:
	_with_port(QUEUE_HOST_PORT, func(ip):
		var o := queue_options(mode)
		if ip != "":
			o["advertise"] = ip
		launch.start_game(o))

## Options for a queue launch (party: everyone enters the same code + size).
func queue_options(mode: String) -> Dictionary:
	var o := {"queue": mode, "mm": settings().matchmaker, "size": str(3 if pick_mode == "chaosball" else pick_size),
		"host-port": str(QUEUE_HOST_PORT)}
	if pick_mode == "chaosball":
		o["mode"] = "chaosball"
	var code := party_code.strip_edges().to_upper()
	if party_size >= 2 and code != "":
		o["party"] = "%s:%d" % [code, party_size]
	return o

static func new_party_code() -> String:
	const A := "ABCDEFGHJKMNPQRSTVWXYZ23456789"
	var s := ""
	for i in 5:
		s += A[randi() % A.length()]
	return s

func _party_row() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	content.add_child(h)
	_text("Party", h).custom_minimum_size = Vector2(120, 0)
	var size_ob := OptionButton.new()
	size_ob.name = "PartySize"
	for n in range(1, 8):
		size_ob.add_item("Solo" if n == 1 else "%d friends" % n)
	size_ob.select(party_size - 1)
	h.add_child(size_ob)
	var code := _line("Party code", party_code, h)
	code.name = "PartyCode"
	code.custom_minimum_size = Vector2(150, 0)
	code.max_length = 8
	code.editable = party_size >= 2
	code.text_changed.connect(func(t): party_code = t)
	var gen := _button("New code", func():
		party_code = new_party_code()
		code.text = party_code, h)
	gen.disabled = party_size < 2
	size_ob.item_selected.connect(func(i):
		party_size = i + 1
		code.editable = party_size >= 2
		gen.disabled = party_size < 2
		if party_size >= 2 and party_code == "":
			party_code = new_party_code()
			code.text = party_code)
	_text("Everyone in the party picks the same size + code, then queues.", content).add_theme_color_override("font_color", Color(UITheme.REGOLITH, 0.9))

func host_match() -> void:
	_with_port(host_port, func(ip):
		var o := {"host": true, "size": str(pick_size), "mode": pick_mode}
		if host_port != NetSession.DEFAULT_PORT:
			o["port"] = str(host_port)
		if ip != "":
			o["advertise"] = ip
		if list_public:
			o["public"] = true
		launch.start_game(o))

## Open the router port with UPnP (if enabled), then cb(public_ip or "").
## Without UPnP the invite code carries the LAN address (works on LAN / manual forward).
func _with_port(port: int, cb: Callable) -> void:
	if busy:
		return
	if not settings().upnp:
		cb.call("")
		return
	busy = true
	_status("Opening port %d on your router…" % port)
	_upnp_thread = PortMapper.open_port_async(port, func(res):
		busy = false
		_upnp_thread.wait_to_finish()
		if res.get("ok", false):
			_status("Port %d open · public address %s" % [port, res["ip"]])
			cb.call(str(res["ip"]))
		else:
			launch.last_status = "%s. Friends on other networks need UDP port %d forwarded to this PC." % [res.get("error", "UPnP failed"), port]
			cb.call(""))

func _join(target: String) -> void:
	target = target.strip_edges()
	if target == "":
		_status("Enter an invite code or IP address.")
		return
	if not InviteCode.looks_like_code(target) and not target.is_valid_ip_address():
		_status("That doesn't look like an invite code (XXXXX-XXXXX) or an IP.")
		return
	launch.start_game({"join": target.to_upper() if InviteCode.looks_like_code(target) else target})

func _equip(slot: String, id) -> void:
	if profile.equip(slot, id):
		profile.save(profile_path)

func _set_name(t: String) -> void:
	var n := Settings.clean_name(t)
	if n == "":
		_status("Names need 2-16 characters.")
		return
	if n != settings().player_name:
		settings().player_name = n
		launch.save_settings()
		_status("Name saved")

func _rating_line() -> String:
	var rk := Ranked.new()
	rk.load_file(ranked_path)
	return rk.label(settings().player_name)

## ------------------------------------------------------------------ widgets
func _status(t: String) -> void:
	status_label.text = t

func _text(t: String, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent == null:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_override("font", UITheme.font(400))
	l.add_theme_font_size_override("font_size", 18)
	(parent if parent else content).add_child(l)
	return l

func _button(t: String, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = t.to_upper()
	b.pressed.connect(cb)
	(parent if parent else content).add_child(b)
	return b

func _line(placeholder: String, value: String, parent: Node = null) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.custom_minimum_size = Vector2(320, 0)
	(parent if parent else content).add_child(e)
	return e

func _check(t: String, value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = t
	c.button_pressed = value
	c.toggled.connect(cb)
	content.add_child(c)
	return c

func _slider(t: String, value: float, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var h := HBoxContainer.new()
	content.add_child(h)
	_text(t, h).custom_minimum_size = Vector2(200, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	h.add_child(s)
	return s

func _size_picker(include_label: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	content.add_child(h)
	_text("Team size" if include_label else "Size", h).custom_minimum_size = Vector2(120, 0)
	var group := ButtonGroup.new()
	for s in SIZES:
		var b := Button.new()
		b.text = "%dv%d" % [s, s]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = s == pick_size
		b.pressed.connect(func(): pick_size = s)
		h.add_child(b)

func _mode_picker() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	content.add_child(h)
	_text("Rules", h).custom_minimum_size = Vector2(120, 0)
	var group := ButtonGroup.new()
	for m in [["classic", "Classic"], ["chaosball", "Chaosball (3v3, low-g)"]]:
		var b := Button.new()
		b.text = m[1].to_upper()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = m[0] == pick_mode
		var id: String = m[0]
		b.pressed.connect(func(): pick_mode = id)
		h.add_child(b)

## Animated lunar backdrop: starfield, Earth, crater horizon with stadium glow.
class Backdrop extends Control:
	const C := preload("res://src/ui/ui_theme.gd")
	var stars: Array = []
	var t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 220:
			stars.append([Vector2(rng.randf(), rng.randf() * 0.75), rng.randf_range(0.6, 1.8), rng.randf()])
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), C.SPACE)
		for st in stars:
			var a: float = 0.35 + 0.65 * absf(sin(t * 0.7 + st[2] * 20.0))
			draw_circle(st[0] * s, st[1], Color(C.CREAM, a * 0.8))
		var earth := Vector2(s.x * 0.84, s.y * 0.2)
		var r := s.y * 0.075
		draw_circle(earth, r * 1.25, Color(C.CYAN, 0.06))
		draw_circle(earth, r, Color("#1E4E8C"))
		draw_circle(earth + Vector2(-r * 0.3, -r * 0.2), r * 0.45, Color("#2E6E3F", 0.9))
		draw_circle(earth + Vector2(r * 0.35, r * 0.3), r * 0.3, Color("#2E6E3F", 0.8))
		draw_circle(earth + Vector2(r * 0.25, -r * 0.1), r * 0.85, Color(C.SPACE, 0.0))
		var shade := PackedVector2Array()
		for i in 33:
			var ang := -PI / 2 + PI * i / 32.0
			shade.append(earth + Vector2(cos(ang), sin(ang)) * r)
		for i in 33:
			var ang := PI / 2 - PI * i / 32.0
			shade.append(earth + Vector2(cos(ang) * r * 0.35, sin(ang) * r))
		draw_colored_polygon(shade, Color(C.SPACE, 0.55))
		# crater rim horizon + stadium glow
		var hz := s.y * 0.82
		draw_circle(Vector2(s.x * 0.62, hz + s.y * 0.9), s.y * 0.95, Color(C.CYAN, 0.05 + 0.02 * sin(t)))
		var ground := PackedVector2Array([Vector2(0, hz)])
		for i in 41:
			var x := s.x * i / 40.0
			ground.append(Vector2(x, hz - sin(i * 0.9) * 6.0 - (s.y * 0.05 if i > 18 and i < 32 else 0.0)))
		ground.append(Vector2(s.x, s.y))
		ground.append(Vector2(0, s.y))
		draw_colored_polygon(ground, Color("#1A1C24"))
		draw_line(Vector2(s.x * 0.45, hz - s.y * 0.05), Vector2(s.x * 0.8, hz - s.y * 0.05), Color(C.CYAN, 0.7), 2.0)
