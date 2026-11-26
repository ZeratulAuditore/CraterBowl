extends CanvasLayer
## Broadcast-style match overlay: scorebug, play clock, status line, play-call
## card, athlete card (stamina), throw meter, big-play banners, control hints.
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
var clock_l: Label
var down_l: Label
var play_clock_l: Label
var status_l: Label
var mode_l: Label
var card: PanelContainer
var card_title: Label
var card_body: Label
var me_panel: PanelContainer
var me_name: Label
var stamina_bar: ProgressBar
var stamina_fill: StyleBoxFlat
var winded_l: Label
var throw_panel: PanelContainer
var throw_bar: ProgressBar
var throw_l: Label
var banner: Label
var banner_sub: Label
var banner_t := 0.0
var hints: Label
var _prev := {}

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "Overlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_scorebug()
	_build_card()
	_build_me()
	_build_throw()
	_build_banner()
	hints = _label(13, Color(0.85, 0.9, 1.0, 0.7), 600)
	hints.position = Vector2(18, 36)
	root.add_child(hints)
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
		var name_l := _label(22, Color(0.92, 0.95, 1.0), 700)
		name_l.text = TEAM_ABBR[t]
		cell.add_child(name_l)
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
	status_l.position.y = -96
	root.add_child(status_l)

func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, 0.14)
	d.custom_minimum_size = Vector2(1, 30)
	return d

func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "PlayCard"
	card.add_theme_stylebox_override("panel", _box(NAVY, 8, ACCENT * Color(1, 1, 1, 0.5), 1))
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.position = Vector2(-18, 16)
	root.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	card_title = _label(14, ACCENT, 700)
	v.add_child(card_title)
	card_body = _label(20, Color.WHITE, 700)
	v.add_child(card_body)

func _build_me() -> void:
	me_panel = PanelContainer.new()
	me_panel.name = "AthleteCard"
	me_panel.add_theme_stylebox_override("panel", _box(NAVY, 8))
	me_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	me_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	me_panel.position = Vector2(18, -22)
	root.add_child(me_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	me_panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	me_name = _label(18, Color.WHITE, 700)
	top.add_child(me_name)
	winded_l = _label(14, ALERT, 800)
	winded_l.text = "  WINDED"
	top.add_child(winded_l)
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(220, 9)
	stamina_bar.max_value = 1.0
	stamina_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.1), 4))
	stamina_fill = _box(ACCENT, 4)
	stamina_fill.content_margin_top = 0
	stamina_fill.content_margin_bottom = 0
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	v.add_child(stamina_bar)

func _build_throw() -> void:
	throw_panel = PanelContainer.new()
	throw_panel.name = "ThrowMeter"
	throw_panel.add_theme_stylebox_override("panel", _box(NAVY, 8))
	throw_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	throw_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	throw_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	throw_panel.position.y = -132
	root.add_child(throw_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	throw_panel.add_child(h)
	throw_l = _label(16, Color.WHITE, 800)
	h.add_child(throw_l)
	throw_bar = ProgressBar.new()
	throw_bar.show_percentage = false
	throw_bar.custom_minimum_size = Vector2(260, 12)
	throw_bar.max_value = 1.0
	throw_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	throw_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.1), 5))
	var f := _box(Color(1.0, 0.8, 0.3), 5)
	f.content_margin_top = 0
	f.content_margin_bottom = 0
	throw_bar.add_theme_stylebox_override("fill", f)
	h.add_child(throw_bar)

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

# --- per frame --------------------------------------------------------------

func refresh(main, delta: float) -> void:
	var s = main.series
	var w = main.world
	var pre_game: bool = main.searching() or main.in_lobby()
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
		return
	for t in 2:
		(team_tab[t] as ColorRect).color = main.TEAM_COLORS[t]
		(team_score[t] as Label).text = str(s.score[t])
		(poss[t] as Label).modulate.a = 1.0 if w.offense_team == t and not final else 0.0
	clock_l.text = "FINAL" if final else s.clock.label()
	down_l.text = _down_text(main)
	var pc := int(ceil(s.clock.play_clock))
	play_clock_l.text = ":%02d" % pc if int(w.phase) == 0 else ""
	play_clock_l.label_settings.font_color = ALERT if pc <= 5 else ACCENT
	mode_l.text = _mode_text(main)
	status_l.text = _status_text(main)
	_refresh_card(main)
	_refresh_me(main)
	throw_panel.visible = main.charging
	if main.charging:
		throw_bar.value = main.charge
		throw_l.text = "LOB" if main.lob_held() else "THROW"
	me_panel.visible = not final
	card.visible = not final
	bug.visible = true
	# First down detection (same offense, down reset, chains moved).
	var key := [w.offense_team, s.downs.down, snappedf(s.downs.first_down_y, 0.1)]
	if not _prev.is_empty() and _prev["k"][0] == key[0] and key[1] == 1 and _prev["k"][1] > 1 and int(s.state) == 0:
		show_banner("FIRST DOWN", "", Color(1.0, 0.86, 0.35), 1.4)
	elif not _prev.is_empty() and _prev["k"][0] != key[0] and _prev["k"][1] == 4 and _prev.get("score", []) == s.score and not final:
		show_banner("TURNOVER ON DOWNS", "", ALERT, 1.8)
	_prev = {"k": key, "score": s.score.duplicate()}
	# Banner animation: punch in, hold, fade.
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
	hints.text = _hints(main)

func _down_text(main) -> String:
	var s = main.series
	if main.drill != null:
		return main.drill.label()
	if int(s.state) == 1:
		return "TRY FOR %d" % s.try_points
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
		t = "PRACTICE"
	return t

func _status_text(main) -> String:
	var w = main.world
	var s = main.series
	if s.is_final():
		return ""
	var lab: String = s.downs.label()
	var at := lab.find(" at ")
	var spot := lab.substr(at + 4).to_upper() if at > 0 else ""
	match int(w.phase):
		0:
			var mine: bool = w.offense_team == w.get_athlete(main.my_id).team
			var t := "BALL ON %s  ·  " % spot if spot != "" else ""
			return t + ("SPACE TO SNAP" if mine else "DEFENSE  ·  Q CHANGE CALL" if not w.defensive_call.is_empty() else "DEFENSE")
		1:
			if main.world.is_chaos():
				return "PASS CLOCK %.1f" % maxf(0.0, main.T.PASS_CLOCK - w.hold_t)
			return ""
		_:
			return ("%s  ·  R FOR NEXT PLAY" % main.last_whistle) if main.last_whistle != "" else ""

func _refresh_card(main) -> void:
	var w = main.world
	var me = w.get_athlete(main.my_id)
	var offense: bool = me != null and w.offense_team == me.team
	var remaining: int = main.huddle_remaining()
	if remaining > 0 and me != null:
		card_title.text = "%s HUDDLE  ·  %ds  ·  Q NEXT" % ["OFFENSE" if offense else "DEFENSE", remaining]
		card_body.text = main.huddle_calls(me.team) + ("\nL Last   ·   X Flip   ·   Y Auto" if offense else "\nL Last   ·   Y Auto")
	elif offense:
		card_title.text = "AUTO CALL  [Y]" if main.auto_call else "PLAY CALL  [Q]"
		var body: String = str(w.play_name).to_upper()
		if w.route_of.has(main.my_id):
			body += "\nYOUR ROUTE  %s  [F]" % w.route_of[main.my_id]
		card_body.text = body
	elif int(w.phase) == 0 and not w.defensive_call.is_empty():
		card_title.text = "AUTO CALL  [Y]" if main.auto_call else "DEFENSIVE CALL  [Q]"
		card_body.text = w.DefensivePlaybook.CALLS[w.defensive_call].name
	else:
		card_title.text = "DEFENSE"
		card_body.text = "F / RMB  DIVE TACKLE\nSHIFT  SPRINT"

func _refresh_me(main) -> void:
	var pv = main.player
	if pv == null:
		return
	var a = pv.athlete
	var slot: int = main.roster.slot_of_athlete(main.my_id)
	var pos_l: String = main.roster.label(slot) if slot >= 0 else ""
	var nm: String = main.owner_name(a.id) if a.id != main.my_id else main.player_name
	me_name.text = "#%s  %s  %s" % [pv.number_text, nm.to_upper(), pos_l]
	stamina_bar.value = a.stamina
	var low: bool = a.sprint_locked or a.stamina < 0.25
	stamina_fill.bg_color = ALERT if low else ACCENT.lerp(Color(0.4, 1.0, 0.55), a.stamina)
	winded_l.visible = a.sprint_locked

func _hints(main) -> String:
	var w = main.world
	var me = w.get_athlete(main.my_id)
	var offense: bool = me != null and w.offense_team == me.team
	if int(w.phase) == 0:
		return "WASD MOVE · SHIFT SPRINT · TAB POSITION · T TEAM" + (" · Q PLAY · F ROUTE · X FLIP" if offense else " · Q CALL") + " · WHEEL/G TAUNT"
	if int(w.phase) == 1 and main.pov_active() and main.world.ball.is_held_by(main.controlled_id):
		return "MOUSE LOOK = AIM (UP = LOFT) · HOLD LMB / J CHARGE · RELEASE TO THROW"
	if int(w.phase) == 1 and main.world.ball.is_held_by(main.controlled_id):
		return "Q / E SPIN · F DIVE · SHIFT SPRINT" + (" · HOLD LMB THROW" if main.world.can_throw(main.controlled_id) else "")
	return "WASD MOVE · SHIFT SPRINT · F / RMB DIVE TACKLE · WHEEL/G TAUNT"
