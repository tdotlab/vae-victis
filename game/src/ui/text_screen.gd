class_name TextScreen
extends Control
## A page of story text with one button: intros, death, endings.
## args: title, text, button, next (screen), next_args, image (optional color)
## or pages: [{title, text}] shown one after another (ending slides); the
## button reads "Go on" until the last page.

var args: Dictionary = {}
var _page := 0
var _title: Label
var _body: RichTextLabel
var _button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 760
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	_title = UITheme.title_label(args.get("title", ""), 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(760, 0)
	_body.add_theme_font_size_override("normal_font_size", 18)
	_body.text = _fill(args.get("text", ""))
	vb.add_child(_body)
	_button = UITheme.button(args.get("button", "Continue"), _next, 240)
	var row := CenterContainer.new()
	row.add_child(_button)
	vb.add_child(row)
	if args.has("pages"):
		_show_page()


func _fill(text: String) -> String:
	return Dialogue.fill(Game.state, text) if Game.state else text


func _pages() -> Array:
	return args.get("pages", [])


func _show_page() -> void:
	var ps := _pages()
	if ps.is_empty():
		return
	_title.text = ps[_page].get("title", "")
	_body.text = _fill(ps[_page].get("text", ""))
	_button.text = args.get("button", "Continue") if _page == ps.size() - 1 else "Go on"


func _next() -> void:
	if _page < _pages().size() - 1:
		_page += 1
		_show_page()
		return
	var cb: Callable = args.get("callback", Callable())
	if cb.is_valid():
		cb.call()
		return
	Game.goto(args.get("next", "title"), args.get("next_args", {}))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
		_next()
