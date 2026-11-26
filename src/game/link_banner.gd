extends CanvasLayer
## #86: "Connection to host lost..." while the client's host-silence watchdog
## (NetSession.watch_host) is warning. Hides again if the host comes back; at
## DROP_AFTER the session emits host_lost and main returns to the menu.

const UITheme := preload("res://src/ui/ui_theme.gd")
const TITLE := "Connection to host lost…"

var net
var panel: PanelContainer
var title: Label
var sub: Label
var _shown_left := -1

func _init(session) -> void:
	net = session
	name = "LinkBanner"
	layer = 70   # over the match HUD and Players of the Game (60), under the Esc menu (90)

func _ready() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, UITheme.ORANGE, 2, 10))
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 28
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	title = UITheme.heading(TITLE, 30, UITheme.ORANGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	sub = Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", UITheme.CREAM)
	box.add_child(sub)
	add_child(panel)
	visible = false
	net.host_stalled.connect(_on_stalled)
	net.host_recovered.connect(hide)

func _on_stalled() -> void:
	_shown_left = -1
	_refresh()
	show()

func _process(_dt: float) -> void:
	if visible:
		_refresh()

## Change-driven: the countdown text is rebuilt only when its whole second changes.
func _refresh() -> void:
	var left := maxi(1, ceili(net.DROP_AFTER - net.host_silence))
	if left != _shown_left:
		_shown_left = left
		sub.text = "Waiting for the host · back to the menu in %ds" % left
