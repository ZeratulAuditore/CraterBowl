extends Control
## Taunt wheel (#139): hold the taunt key (C) and a radial wheel opens at screen centre,
## one slice per taunt. Mouse motion drags a selector out from the hub (the camera stops
## turning meanwhile) and the slice it points at lights up. Releasing the key returns the
## highlighted taunt; releasing in the hub's dead zone cancels. A quick tap with no drag
## repeats the last taunt. Only the chosen id goes over the wire (main.taunt).
## Selection math lives in radial_select.gd.

const Emotes := preload("res://src/sim/emotes.gd")
const Radial := preload("res://src/game/radial_select.gd")
const UITheme := preload("res://src/ui/ui_theme.gd")

const R_OUT := 210.0      # px (720p canvas): outer edge of the slices
const R_IN := 80.0        # inner edge of the slices; the hub sits inside
const GAP := 0.03         # rad trimmed off each side of a slice
const POP := 10.0         # px the highlighted slice moves outward
const MAX_DRAG := 90.0    # px of mouse travel the selector can hold
const DEAD_ZONE := 24.0   # px: release inside this cancels
const TAP_TIME := 0.25    # s: a press shorter than this that never left the dead zone repeats the last taunt
const FADE_TIME := 0.08
const ARC_SEGS := 12

var open := false
var ids: Array[String] = []
var selector := Vector2.ZERO
var held_t := 0.0
var left_dead := false
var last_id := ""
var _font: Font
var _body: Font

func _ready() -> void:
	name = "TauntWheel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UITheme.font(600)
	_body = UITheme.body_font(600)
	_load_ids()
	visible = false

func _load_ids() -> void:
	if not ids.is_empty():
		return
	for row in Emotes.LIST:   # every taunt is unlocked today; cosmetic unlocks would filter here
		ids.append(row[0])
	last_id = ids[0]

## Index of the highlighted slice, -1 while the selector is in the dead zone.
func highlighted_index() -> int:
	return Radial.slice_at(selector, ids.size(), DEAD_ZONE) if open else -1

func highlighted() -> String:
	var i := highlighted_index()
	return ids[i] if i >= 0 else ""

func open_wheel() -> void:
	_load_ids()
	open = true
	selector = Vector2.ZERO
	held_t = 0.0
	left_dead = false
	modulate.a = 0.0
	visible = true
	queue_redraw()

## Relative mouse (or stick) motion while the wheel is open.
func drag(rel: Vector2) -> void:
	if not open:
		return
	selector = Radial.drag(selector, rel, MAX_DRAG)
	if selector.length() > DEAD_ZONE:
		left_dead = true
	queue_redraw()

## Close on key release. Returns the taunt to perform, or "" to cancel.
func release() -> String:
	if not open:
		return ""
	var id := highlighted()
	if id == "" and not left_dead and held_t < TAP_TIME:
		id = last_id   # tap: repeat the last taunt
	if id != "":
		last_id = id
	close()
	return id

## Close without performing (menu opened, replay started, focus lost).
func close() -> void:
	open = false
	visible = false

func _process(delta: float) -> void:
	if not open:
		return
	held_t += delta
	if modulate.a < 1.0:
		modulate.a = minf(1.0, modulate.a + delta / FADE_TIME)

func _pt(c: Vector2, r: float, a: float) -> Vector2:
	return c + Vector2(sin(a), -cos(a)) * r

func _draw() -> void:
	if not open or ids.is_empty():
		return
	var c := size * 0.5
	var n := ids.size()
	var step := TAU / n
	var hi := highlighted_index()
	draw_circle(c, R_OUT + 26.0, Color(UITheme.SPACE, 0.45))
	for i in n:
		var on := i == hi
		var off := Radial.slice_dir(i, n) * (POP if on else 0.0)
		var a0 := i * step - step * 0.5 + GAP
		var a1 := i * step + step * 0.5 - GAP
		var pts := PackedVector2Array()
		for s in ARC_SEGS + 1:
			pts.append(_pt(c + off, R_OUT + (6.0 if on else 0.0), lerpf(a0, a1, float(s) / ARC_SEGS)))
		for s in ARC_SEGS + 1:
			pts.append(_pt(c + off, R_IN, lerpf(a1, a0, float(s) / ARC_SEGS)))
		draw_colored_polygon(pts, UITheme.GOLD if on else Color(UITheme.NAVY, 0.9))
		pts.append(pts[0])
		draw_polyline(pts, UITheme.CREAM if on else Color(UITheme.CYAN, 0.45), 2.0, true)
		var label := Emotes.display_name(ids[i]).to_upper()
		var mid_r := lerpf(R_IN, R_OUT, 0.55)
		var room := 2.0 * mid_r * sin(step * 0.5 - GAP) - 8.0   # chord across the slice
		var fs := 28 if on else 24
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > room:   # long names shrink to fit their slice
			fs = int(fs * room / w)
			w = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var mid := _pt(c + off, mid_r, i * step)
		draw_string(_font, mid + Vector2(-w * 0.5, fs * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			UITheme.NAVY if on else UITheme.CREAM)
	# Hub: what you'll shout, or how to use the wheel.
	draw_circle(c, R_IN - 8.0, Color(UITheme.SPACE, 0.94))
	draw_arc(c, R_IN - 8.0, 0.0, TAU, 48, Color(UITheme.CYAN, 0.8), 2.0, true)
	var title := "TAUNT" if hi < 0 else Emotes.bubble(ids[hi])
	var sub := "DRAG TO PICK" if hi < 0 else "RELEASE C"
	var tfs := 26 if title.length() <= 9 else 20
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	draw_string(_font, c + Vector2(-tw * 0.5, -6.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs,
		UITheme.GOLD if hi >= 0 else UITheme.CREAM)
	var sw := _body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_body, c + Vector2(-sw * 0.5, 18.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.REGOLITH)
	# Selector: a knob that rides out to the hub's rim as you drag, and a gold arc on the
	# rim under the highlighted slice (kept off the hub text).
	var reach := R_IN - 8.0
	if hi >= 0:   # draw_arc angles: 0 = +x, so up-is-zero angles shift by -90 deg
		var a := hi * step - PI * 0.5
		draw_arc(c, reach, a - step * 0.5 + GAP, a + step * 0.5 - GAP, 12, UITheme.GOLD, 4.0, true)
	draw_circle(c + selector / MAX_DRAG * reach, 6.0, UITheme.GOLD if hi >= 0 else UITheme.CREAM)
