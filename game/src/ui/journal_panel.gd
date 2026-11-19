class_name JournalPanel
extends Control
## Quests in hand and finished, with the log entries for each, and the date.

var on_close: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var gs := Game.state
	var r := UITheme.modal(self, "Journal", Vector2(760, 0))
	var vb: VBoxContainer = r[1]
	vb.add_child(UITheme.label(gs.date_text(), 14, UITheme.DIM))
	var deadline := int(DB.story().get("deadline_day", 0))
	if deadline > 0 and gs.quest_status("hostages") == "active":
		vb.add_child(UITheme.label("Days until the spring assembly: %d" % maxi(0, deadline - gs.day()), 14, UITheme.WARN))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var order: Array = []
	for status in ["active", "done", "failed"]:
		for qid in gs.quests:
			if gs.quest_status(qid) == status:
				order.append(qid)
	for qid in order:
		var q := DB.quest(qid)
		var st := gs.quest_status(qid)
		var col := UITheme.BRONZE if st == "active" else (UITheme.GOOD if st == "done" else UITheme.BAD)
		var suffix := "" if st == "active" else ("  (done)" if st == "done" else "  (failed)")
		list.add_child(UITheme.label(q.get("name", qid) + suffix, 17, col))
		for e in gs.quest_log:
			if e["quest"] == qid:
				var l := UITheme.label("Day %d: %s" % [e["day"], e["text"]], 14, UITheme.TEXT if st == "active" else UITheme.DIM)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD
				l.custom_minimum_size.x = 720
				list.add_child(l)
	if order.is_empty():
		list.add_child(UITheme.label("Nothing yet.", 14, UITheme.DIM))
	vb.add_child(UITheme.button("Close", func(): on_close.call(), 120))
