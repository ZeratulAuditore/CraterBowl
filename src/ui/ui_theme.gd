extends RefCounted
## Crater Bowl UI theme: palette shared with the in-game art direction
## (graphics-overhaul): space black, navy panels, neon cyan accent, orange alerts.

const SPACE := Color("#07080F")
const NAVY := Color("#0E1424")
const PANEL := Color(0.055, 0.078, 0.141, 0.85)
const REGOLITH := Color("#8A8C94")
const CREAM := Color("#FFF4E0")
const CYAN := Color("#5CE1FF")
const ORANGE := Color("#FF6A1F")
const GOLD := Color("#F2BF26")
const FONT_PATH := "res://assets/fonts/Oswald.ttf"

static func font(weight: int = 600) -> Font:
	var base = load(FONT_PATH)
	if base == null:
		return ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": weight}
	v.spacing_glyph = 1
	return v

static func box(bg: Color, border: Color, width: int = 2, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 20
	var normal := box(PANEL, Color(CYAN, 0.25))
	var hover := box(Color(NAVY.lightened(0.12), 0.95), CYAN)
	var pressed := box(Color(CYAN, 0.25), CYAN)
	var disabled := box(Color(PANEL, 0.5), Color(REGOLITH, 0.2))
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, box(Color(0, 0, 0, 0), CYAN, 2))
		t.set_stylebox("disabled", cls, disabled)
		t.set_color("font_color", cls, CREAM)
		t.set_color("font_hover_color", cls, CYAN)
		t.set_color("font_focus_color", cls, CYAN)
		t.set_color("font_pressed_color", cls, CREAM)
		t.set_color("font_disabled_color", cls, Color(REGOLITH, 0.6))
	t.set_stylebox("normal", "LineEdit", box(Color(SPACE, 0.9), Color(CYAN, 0.4)))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), CYAN))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", Color(REGOLITH, 0.8))
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_color("font_color", "Label", CREAM)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(CYAN, 0.18), 1, 10))
	t.set_stylebox("panel", "PopupMenu", box(NAVY, CYAN, 1, 4))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", CYAN)
	t.set_stylebox("panel", "ItemList", box(Color(SPACE, 0.7), Color(CYAN, 0.2)))
	t.set_color("font_color", "ItemList", CREAM)
	t.set_color("font_selected_color", "ItemList", SPACE)
	t.set_stylebox("selected", "ItemList", box(CYAN, CYAN, 0, 3))
	t.set_stylebox("selected_focus", "ItemList", box(CYAN, CYAN, 0, 3))
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_font("normal_font", "RichTextLabel", font(400))
	t.set_font("mono_font", "RichTextLabel", ThemeDB.fallback_font)
	t.set_stylebox("slider", "HSlider", box(Color(SPACE, 0.9), Color(CYAN, 0.3), 1, 3))
	t.set_stylebox("grabber_area", "HSlider", box(Color(CYAN, 0.6), CYAN, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(CYAN, CYAN, 0, 3))
	return t

## Rasterize an SVG at runtime (crisp at any scale, no import step needed).
static func svg_texture(path: String, scale: float = 1.0) -> Texture2D:
	var img := Image.new()
	if img.load_svg_from_string(FileAccess.get_file_as_string(path), scale) != OK:
		return null
	return ImageTexture.create_from_image(img)

static func heading(text: String, size: int = 34, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font(700))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
