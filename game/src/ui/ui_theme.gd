class_name UITheme
extends RefCounted
## The interface look: dark leather panels, bronze edges, parchment text.

const BG := Color("#1e1610")
const PANEL := Color("#2a1f15")
const PANEL_LIGHT := Color("#3a2b1c")
const EDGE := Color("#8a6a3a")
const BRONZE := Color("#c08a3e")
const TEXT := Color("#e8d8b0")
const DIM := Color("#a89878")
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
	t.set_stylebox("hover", "Button", _box(Color("#4a3826"), BRONZE, 1, 6))
	t.set_stylebox("pressed", "Button", _box(Color("#5a4430"), BRONZE, 2, 6))
	t.set_stylebox("disabled", "Button", _box(Color("#241c14"), Color("#4a3a24"), 1, 6))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), BRONZE, 1, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("#fff0c8"))
	t.set_color("font_pressed_color", "Button", Color("#fff0c8"))
	t.set_color("font_disabled_color", "Button", Color("#6a5a44"))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "LineEdit", _box(Color("#140f0a"), EDGE, 1, 4))
	t.set_stylebox("focus", "LineEdit", _box(Color("#140f0a"), BRONZE, 1, 4))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "TooltipPanel", _box(Color("#140f0a"), EDGE, 1, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#140f0a")
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
