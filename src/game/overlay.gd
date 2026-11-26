extends CanvasLayer
## Broadcast-style match overlay: scorebug, play clock, status line, play-call
## picker, movement meters, hold-to-view scoreboard, and event banners.
## Reads main's state each frame. Text/debug HUD (main.hud) is kept for lobby,
## search and the final summary.

const Mats := preload("res://src/game/art/materials.gd")
const TEAM_NAMES := ["HELIOS", "NEBULA"]
const TEAM_ABBR := ["HEL", "NEB"]
const NAVY := Color(0.055, 0.078, 0.14, 0.9)
const ACCENT := Color(0.36, 0.88, 1.0)
const ALERT := Color(1.0, 0.42, 0.12)

var root: Control
var bug: PanelContainer
var team_score: Array = []   # Label per team
var team_tab: Array = []     # ColorRect per team
var poss: Array = []         # possession pip per team
var timeout_pips: Array[Label] = []
var clock_l: Label
var down_l: Label
var play_clock_l: Label
var status_l: Label
var mode_l: Label
var picker: PanelContainer
var picker_title: Label
var coaching_text: Label
var picker_grid: GridContainer
var route_select: OptionButton
var picker_side := -1
var picker_calls: Array = []
var scoreboard: PanelContainer
var scoreboard_label: Label
var me_panel: PanelContainer
var stamina_bar: ProgressBar
var stamina_fill: StyleBoxFlat
var move_circles: Array[Control] = []
var move_charge := 2.0
var banner: Label
var banner_sub: Label
var banner_t := 0.0
var _prev := {}
## HUD text/state refresh rate. Nothing on the scorebug changes faster than ~10 Hz, and
## rebuilding a dozen strings + label layouts every render frame cost ~1 ms/frame
## (docs/optimization/LOG.md). Animated bits (throw bar, banner) still run per frame.
const TEXT_HZ := 20.0
var _text_t := 0.0
var _was_pre_game := true

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "Overlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_scorebug()
	_build_picker()
	_build_me()
	_build_banner()
	_build_scoreboard()
	mode_l = _label(15, Color(0.85, 0.9, 1.0, 0.85), 700)
	mode_l.position = Vector2(18, 14)
	root.add_child(mode_l)

# --- builders ---------------------------------------------------------------

static func _box(bg: Color, radius: int = 6, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func _label(size: int, c: Color = Color.WHITE, weight: int = 700) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = Mats.ui_font(weight)
	ls.font_size = size
	ls.font_color = c
	ls.outline_size = 0
	ls.shadow_size = 3
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = Vector2(1, 2)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_scorebug() -> void:
	bug = PanelContainer.new()
	bug.name = "Scorebug"
	bug.add_theme_stylebox_override("panel", _box(NAVY, 8, Color(1, 1, 1, 0.08), 1))
	bug.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bug.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bug.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bug.position.y = -22
	root.add_child(bug)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bug.add_child(row)
	for t in 2:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		var tab := ColorRect.new()
		tab.custom_minimum_size = Vector2(6, 34)
		cell.add_child(tab)
		team_tab.append(tab)
		var team_label := VBoxContainer.new()
		team_label.alignment = BoxContainer.ALIGNMENT_CENTER
		team_label.add_theme_constant_override("separation", 0)
		var name_l := _label(22, Color(0.92, 0.95, 1.0), 700)
		name_l.text = TEAM_ABBR[t]
		team_label.add_child(name_l)
		var pips := _label(11, Color(0.85, 0.92, 1.0), 700)
		timeout_pips.append(pips)
		team_label.add_child(pips)
		cell.add_child(team_label)
		var sc := _label(30, Color.WHITE, 800)
		sc.custom_minimum_size.x = 34
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.add_child(sc)
		team_score.append(sc)
		var pip := _label(16, Color(1.0, 0.8, 0.3), 800)
		pip.text = "◆"
		pip.custom_minimum_size.x = 14
		cell.add_child(pip)
		poss.append(pip)
		row.add_child(cell)
		if t == 0:
			row.add_child(_divider())
	row.add_child(_divider())
	clock_l = _label(22, Color.WHITE, 700)
	row.add_child(clock_l)
	row.add_child(_divider())
	down_l = _label(22, Color(1.0, 0.86, 0.35), 700)
	row.add_child(down_l)
	row.add_child(_divider())
	play_clock_l = _label(22, ACCENT, 800)
	play_clock_l.custom_minimum_size.x = 36
	row.add_child(play_clock_l)
	status_l = _label(17, Color(0.88, 0.92, 1.0, 0.95), 600)
	status_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	status_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_l.position.y = -153
	root.add_child(status_l)

func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, 0.14)
	d.custom_minimum_size = Vector2(1, 30)
	return d

func _build_picker() -> void:
	picker = PanelContainer.new()
	picker.name = "PlayPicker"
	picker.add_theme_stylebox_override("panel", _box(NAVY, 8, ACCENT.darkened(0.5), 1))
	picker.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	picker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	picker.grow_vertical = Control.GROW_DIRECTION_BOTH
	picker.position.x = -20
	root.add_child(picker)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	picker.add_child(column)
	picker_title = _label(17, ACCENT)
	column.add_child(picker_title)
	coaching_text = _label(16)
	column.add_child(coaching_text)
	picker_grid = GridContainer.new()
	picker_grid.columns = 2
	column.add_child(picker_grid)
	route_select = OptionButton.new()
	route_select.focus_mode = Control.FOCUS_NONE
	column.add_child(route_select)

func _build_me() -> void:
	me_panel = PanelContainer.new()
	me_panel.name = "MovementMeters"
	me_panel.add_theme_stylebox_override("panel", _box(NAVY, 8))
	me_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	me_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	me_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	me_panel.position.y = -87
	root.add_child(me_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	me_panel.add_child(row)
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(175, 10)
	stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stamina_bar.max_value = 1.0
	stamina_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.15), 4))
	stamina_fill = _box(ACCENT, 4)
	stamina_fill.content_margin_top = 0
	stamina_fill.content_margin_bottom = 0
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	row.add_child(stamina_bar)
	for i in 2:
		var circle := Control.new()
		circle.custom_minimum_size = Vector2(21, 21)
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.draw.connect(_draw_move_circle.bind(circle, i))
		row.add_child(circle)
		move_circles.append(circle)

func _draw_move_circle(circle: Control, index: int) -> void:
	var center := circle.size * 0.5
	var fraction := clampf(move_charge - index, 0.0, 1.0)
	circle.draw_circle(center, 8.0, Color(1, 1, 1, 0.12), true, -1.0, true)
	circle.draw_arc(center, 8.0, -PI / 2.0, TAU - PI / 2.0, 32, Color(1, 1, 1, 0.25), 2.0, true)
	if fraction > 0.0:
		circle.draw_arc(center, 8.0, -PI / 2.0, fraction * TAU - PI / 2.0, 32, ACCENT, 4.0, true)

func _build_scoreboard() -> void:
	scoreboard = PanelContainer.new()
	scoreboard.name = "Scoreboard"
	scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scoreboard.add_theme_stylebox_override("panel", _box(NAVY, 10, ACCENT.darkened(0.5), 1))
	scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scoreboard.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(scoreboard)
	scoreboard_label = _label(23)
	scoreboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_label.custom_minimum_size = Vector2(440, 0)
	scoreboard.add_child(scoreboard_label)
	scoreboard.hide()

func _build_banner() -> void:
	banner = _label(84, Color.WHITE, 800)
	banner.label_settings.outline_size = 14
	banner.label_settings.outline_color = Color(0.03, 0.04, 0.1, 0.85)
	banner.label_settings.shadow_size = 12
	banner.label_settings.shadow_color = Color(0, 0, 0, 0.35)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position.y = -150
	banner.visible = false
	root.add_child(banner)
	banner_sub = _label(24, ACCENT, 700)
	banner_sub.set_anchors_preset(Control.PRESET_CENTER)
	banner_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.position.y = -60
	banner_sub.visible = false
	root.add_child(banner_sub)

# --- events -----------------------------------------------------------------

func show_banner(text: String, sub: String = "", c: Color = Color.WHITE, dur: float = 2.2) -> void:
	banner.text = text
	banner.label_settings.font_color = c
	banner_sub.text = sub
	banner_t = dur
	banner.visible = true
	banner_sub.visible = sub != ""

func on_event(n: String, d: Dictionary) -> void:
	match n:
		"touchdown":
			var t := int(d.get("team", 0))
			show_banner("TOUCHDOWN", TEAM_NAMES[t] if t >= 0 and t < 2 else "", Color(1.0, 0.86, 0.3), 3.0)
		"interception": show_banner("INTERCEPTION", "", ALERT)
		"fumble": show_banner("FUMBLE", "", ALERT)
		"recovery": show_banner("RECOVERED", "TURNOVER" if d.get("turnover", false) else "", ACCENT)
		"explode": show_banner("BALL EXPLODED", "", ALERT, 1.6)
		"clock_warning": show_banner("ONE-MINUTE WARNING", "", ACCENT)
		"timeout":
			var team: int = d["team"]
			show_banner("TIMEOUT", TEAM_NAMES[team], ACCENT)
		"snap":
			if banner.text in ["TIMEOUT", "ONE-MINUTE WARNING"]:
				banner_t = 0.0

# --- per frame --------------------------------------------------------------

var _last_world

func refresh(main, delta: float) -> void:
	var s = main.series
	var w = main.world
	if _last_world != w:
		_last_world = w
		_text_t = 0.0
	var pre_game: bool = main.in_lobby()   # queued + warming up on the training ground still shows the overlay
	var final: bool = s != null and s.is_final()
	root.visible = not pre_game
	# The detailed text HUD stays for lobby/search/final summary only.
	if main.hud:
		main.hud.visible = pre_game or final
		if main.hud.label_settings == null:
			var ls := LabelSettings.new()
			ls.font = Mats.ui_font(600)
			ls.font_size = 20
			ls.outline_size = 6
			ls.outline_color = Color(0.02, 0.03, 0.08, 0.9)
			main.hud.label_settings = ls
	if pre_game or s == null:
		_was_pre_game = true
		return
	_refresh_picker(main, final)
	scoreboard.visible = main.scoreboard_held
	_animate_banner(delta)
	_text_t -= delta
	if _text_t > 0.0 and not _was_pre_game:
		return
	_text_t = 1.0 / TEXT_HZ
	_was_pre_game = false
	for t in 2:
		(team_tab[t] as ColorRect).color = main.TEAM_COLORS[t]
		(team_score[t] as Label).text = str(s.score[t])
		(poss[t] as Label).modulate.a = 1.0 if w.possession_team() == t and not final else 0.0
		timeout_pips[t].visible = main.drill == null
		timeout_pips[t].text = "●".repeat(s.clock.timeouts[t]) + "○".repeat(s.clock.timeout_limit - s.clock.timeouts[t])
	clock_l.text = "FINAL" if final else ("" if main.drill != null else s.clock.label())
	down_l.text = _down_text(main)
	var pc := int(ceil(s.clock.play_clock))
	play_clock_l.text = ":%02d" % pc if int(w.phase) == 0 and main.drill == null else ""
	play_clock_l.label_settings.font_color = ALERT if pc <= 5 else ACCENT
	mode_l.text = _mode_text(main)
	status_l.text = _status_text(main)
	_refresh_me(main)
	me_panel.visible = not final
	bug.visible = true
	if scoreboard.visible:
		scoreboard_label.text = "%s     %d – %d     %s\n%s     ·     %s\n%s possession" % [
			TEAM_NAMES[0], s.score[0], s.score[1], TEAM_NAMES[1], clock_l.text,
			_down_text(main), TEAM_NAMES[w.possession_team()]]
	# First down detection (same offense, down reset, chains moved).
	var key := [w.offense_team, s.downs.down, snappedf(s.downs.first_down_y, 0.1)]
	if not _prev.is_empty() and _prev["k"][0] == key[0] and key[1] == 1 and _prev["k"][1] > 1 and int(s.state) == 0:
		show_banner("FIRST DOWN", "", Color(1.0, 0.86, 0.35), 1.4)
	elif not _prev.is_empty() and _prev["k"][0] != key[0] and _prev["k"][1] == 4 and _prev.get("score", []) == s.score and not final:
		show_banner("TURNOVER ON DOWNS", "", ALERT, 1.8)
	_prev = {"k": key, "score": s.score.duplicate()}

## Banner animation: punch in, hold, fade (every frame).
func _animate_banner(delta: float) -> void:
	if banner_t > 0.0:
		banner_t = maxf(0.0, banner_t - delta)
		var age := 3.0 - banner_t
		var a := clampf(banner_t * 2.5, 0.0, 1.0)
		var sc := 1.0 + maxf(0.0, 0.35 - age * 1.6) if banner_t > 0.0 else 1.0
		banner.pivot_offset = banner.size * 0.5
		banner.scale = Vector2(sc, sc)
		banner.modulate.a = a
		banner_sub.modulate.a = a
	else:
		banner.visible = false
		banner_sub.visible = false

func _down_text(main) -> String:
	var s = main.series
	if main.drill != null:
		return main.drill.label()
	if int(s.state) == 1:
		return "TRY FOR %d" % s.try_points
	if int(s.state) == 2:
		return "KICKOFF"
	if int(s.state) == 3:
		return "COIN TOSS"
	if main.world.is_chaos():
		return "STREAK %d  ·  TD %d" % [main.world.streak, main.world.streak_points()]
	var lab: String = s.downs.label()
	var at := lab.find(" at ")
	return (lab.substr(0, at) if at > 0 else lab).to_upper()

func _mode_text(main) -> String:
	var m := "CHAOSBALL" if main.match_mode == "chaosball" else "CLASSIC"
	var t := "%dv%d %s" % [main.match_size, main.match_size, m]
	if main.ranked_match:
		t += "  ·  RANKED"
	if main.drill != null:
		t = main.drill.title() if _training(main) else "PRACTICE"
	if main.searching():
		t = main.queue_text() + "  ·  " + t
	return t

func _training(main) -> bool:
	return main.drill != null and main.Drills.is_training(main.drill.kind)

## Drill banners: [title, sub, kind] (good / miss / up / info).
func show_drill_banner(b: Array) -> void:
	var c: Color = {"good": Color(0.45, 1.0, 0.6), "miss": ALERT, "up": Color(1.0, 0.86, 0.35)}.get(b[2], ACCENT)
	show_banner(str(b[0]), str(b[1]), c, 1.6)

func _status_text(main) -> String:
	var w = main.world
	var s = main.series
	if s.is_final():
		return ""
	if _training(main):
		return main.drill.status(w)
	var lab: String = s.downs.label()
	var at := lab.find(" at ")
	var spot := lab.substr(at + 4).to_upper() if at > 0 else ""
	match int(w.phase):
		0:
			var mine: bool = w.offense_team == w.get_athlete(main.my_id).team
			if int(s.state) == 3:
				var won: bool = s.toss_winner == w.get_athlete(main.my_id).team
				return ("YOU WON THE TOSS  ·  1 RECEIVE  ·  2 KICK" if won else "COIN TOSS  ·  %s CHOOSING" % ("HOME" if s.toss_winner == 0 else "AWAY"))
			if w.kick_play == "kickoff":
				return "KICKOFF  ·  " + ("J / CLICK TO KICK" if mine else "RETURN TEAM")
			if w.kick_play != "" and mine:
				return ("BALL ON %s  ·  " % spot if spot != "" else "") + ("PUNT" if w.kick_play == "punt" else "FIELD GOAL") + "  ·  K CHANGE"
			return "BALL ON %s" % spot if spot != "" else ""
		1:
			if main.world.is_chaos():
				return "PASS CLOCK %.1f" % maxf(0.0, main.T.PASS_CLOCK - w.hold_t)
			return "MEET THE BACK" if w.handoff_receiver(main.my_id) == null and w.is_run_play() and w.ball.is_held_by(main.my_id) else ""
		_:
			return main.last_whistle

func _refresh_picker(main, final: bool) -> void:
	var w = main.world
	var training := _training(main)
	coaching_text.visible = training
	picker_grid.visible = not training
	if training:
		picker.visible = not main.scoreboard_held
		var card: Array = main.drill.card()
		picker_title.text = card[0]
		coaching_text.text = card[1]
		route_select.hide()
		return
	picker.visible = not final and w.phase == w.Phase.PRESNAP and w.kick_play != "kickoff" and main.play_picker_open and not main.scoreboard_held and not main.replay_active
	if not picker.visible:
		return
	var side := 0 if w.get_athlete(main.my_id).team == w.offense_team else 1
	var offense := side == 0
	var calls: Array = w.available_plays() if offense else w.DefensivePlaybook.CALLS.keys()
	if picker_side != side or picker_calls != calls:
		picker_side = side
		picker_calls = calls
		for child in picker_grid.get_children():
			picker_grid.remove_child(child)
			child.queue_free()
		for call in calls:
			var b := Button.new()
			b.text = call if offense else w.DefensivePlaybook.CALLS[call].name
			b.focus_mode = Control.FOCUS_NONE
			b.toggle_mode = true
			b.pressed.connect(func(): main.do_action({"a": "play" if offense else "defense", "p": call}))
			picker_grid.add_child(b)
		for action in ([["Last play", "recall_call"], ["Flip play", "flip_play"]] if offense else [["Last call", "recall_call"]]):
			var b := Button.new()
			b.text = action[0]
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func(): main.do_action({"a": action[1]}))
			picker_grid.add_child(b)
		if route_select.item_count == 0:
			for route in main.Routes.ROUTE_NAMES:
				route_select.add_item(route)
			route_select.item_selected.connect(func(index: int): main.do_action({"a": "route", "r": route_select.get_item_text(index)}))
	var called: String = w.play_name if offense else w.defensive_call
	picker_title.text = "Call an offensive play" if offense else "Call a defense"
	for i in calls.size():
		picker_grid.get_child(i).set_pressed_no_signal(calls[i] == called)
	route_select.visible = offense and w.route_of.has(main.my_id)
	if route_select.visible:
		route_select.select(main.Routes.ROUTE_NAMES.find(w.route_of[main.my_id]))

func _refresh_me(main) -> void:
	var a = main.player.athlete
	stamina_bar.value = a.stamina
	var low: bool = a.sprint_locked or a.stamina < 0.25
	stamina_fill.bg_color = ALERT if low else ACCENT.lerp(Color(0.4, 1.0, 0.55), a.stamina)
	if not is_equal_approx(move_charge, a.move_charge):
		move_charge = a.move_charge
		for circle in move_circles:
			circle.queue_redraw()
