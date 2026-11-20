class_name TitleScreen
extends Control
## The title: new game, continue, help, quit.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color("#0f1114")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := _Backdrop.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	var t := UITheme.title_label("VAE VICTIS", 72)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color("#0a0b0d"))
	t.add_theme_constant_override("outline_size", 10)
	vb.add_child(t)
	var sub := UITheme.label(DB.story().get("tagline", "Gaul, 52 BC"), 18, UITheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(Control.new())
	var newest := Game.newest_save()
	var cont := UITheme.button("Continue", func(): Game.goto("load", {"slot": newest}), 280)
	cont.disabled = newest == ""
	vb.add_child(cont)
	vb.add_child(UITheme.button("New game", func(): Game.goto("create", {}), 280))
	var load_b := UITheme.button("Load game", _open_load, 280)
	load_b.disabled = newest == ""
	vb.add_child(load_b)
	if OS.get_name() != "Web":
		vb.add_child(UITheme.button("Quit", func(): get_tree().quit(), 280))
	var ver := UITheme.label(DB.story().get("version", ""), 12, UITheme.DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position += Vector2(-140, -28)
	add_child(ver)


func _open_load() -> void:
	var w := SaveSlotsPanel.new()
	w.mode = "load"
	w.on_close = func(): w.queue_free()
	add_child(w)


## A hill fort on a ridge against a winter sky, drawn in code for now.
class _Backdrop extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sky := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
		draw_polygon(sky, PackedColorArray([Color("#2a2f36"), Color("#2a2f36"), Color("#101216"), Color("#101216")]))
		# The fort sits low, under the menu, so the palisade never shows between buttons.
		var hill := PackedVector2Array([Vector2(0, h * 0.9), Vector2(w * 0.18, h * 0.86), Vector2(w * 0.38, h * 0.8),
			Vector2(w * 0.62, h * 0.79), Vector2(w * 0.8, h * 0.84), Vector2(w, h * 0.88), Vector2(w, h), Vector2(0, h)])
		draw_colored_polygon(hill, Color("#15181b"))
		# Palisade on the hilltop.
		for i in range(48):
			var x := w * 0.4 + i * (w * 0.2 / 48.0)
			var top := h * 0.755 - (sin(i * 1.7) * 3.0)
			draw_line(Vector2(x, h * 0.797), Vector2(x, top), Color("#0b0c0e"), 4.0)
		# Smoke from the hearths.
		for j in range(3):
			var sx := w * (0.45 + j * 0.05)
			for k in range(14):
				draw_circle(Vector2(sx + sin(k * 0.6 + j) * 10.0 + k * 3.0, h * 0.745 - k * 14.0), 6.0 + k * 1.2, Color(0.5, 0.45, 0.4, 0.05))
