class_name UITheme
extends RefCounted
## The interface look: charcoal iron panels, iron edges, brass accents, bone text.
## T hates brown; keep it out of the interface.

const BG := Color("#121417")
const PANEL := Color("#1b1e22")
const PANEL_LIGHT := Color("#272b31")
const EDGE := Color("#59616b")
const BRONZE := Color("#d6ad52")  # brass: headings, hover, focus
const TEXT := Color("#e6e2d8")
const DIM := Color("#9a9ea4")
const GOOD := Color("#9cc07a")
const BAD := Color("#d8705a")
const WARN := Color("#e0b050")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	var panel := _box(PANEL, EDGE, 2)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT, EDGE, 1, 6))
	t.set_stylebox("hover", "Button", _box(Color("#323841"), BRONZE, 1, 6))
	t.set_stylebox("pressed", "Button", _box(Color("#3c434d"), BRONZE, 2, 6))
	t.set_stylebox("disabled", "Button", _box(Color("#17191c"), Color("#33383e"), 1, 6))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), BRONZE, 1, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("#ffffff"))
	t.set_color("font_pressed_color", "Button", Color("#ffffff"))
	t.set_color("font_disabled_color", "Button", Color("#5c6168"))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "LineEdit", _box(Color("#0e1012"), EDGE, 1, 4))
	t.set_stylebox("focus", "LineEdit", _box(Color("#0e1012"), BRONZE, 1, 4))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "TooltipPanel", _box(Color("#0e1012"), EDGE, 1, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0e1012")
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab := StyleBoxFlat.new()
	grab.bg_color = EDGE
	grab.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	_theme = t
	return t


static func _box(bg: Color, edge: Color, border: int, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(3)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(cb)
	return b


## A centered modal window over a dimmed background. Returns [root, content_vbox].
static func modal(parent: Node, title: String, size: Vector2) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	if title != "":
		var t := label(title, 22, BRONZE)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(t)
	parent.add_child(root)
	return [root, vb]
