class_name TextScreen
extends Control
## A page of story text with one button: intros, death, endings.
## args: title, text, button, next (screen), next_args, image (optional color)

var args: Dictionary = {}


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
	var t := UITheme.label(args.get("title", ""), 34, UITheme.BRONZE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.custom_minimum_size = Vector2(760, 0)
	body.add_theme_font_size_override("normal_font_size", 18)
	body.text = Dialogue.fill(Game.state, args.get("text", "")) if Game.state else args.get("text", "")
	vb.add_child(body)
	var b := UITheme.button(args.get("button", "Continue"), _next, 240)
	var row := CenterContainer.new()
	row.add_child(b)
	vb.add_child(row)


func _next() -> void:
	var cb: Callable = args.get("callback", Callable())
	if cb.is_valid():
		cb.call()
		return
	Game.goto(args.get("next", "title"), args.get("next_args", {}))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
		_next()
