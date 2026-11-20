class_name SaveSlotsPanel
extends Control
## The save and load windows: the autosave, the quicksave and the numbered
## slots, each with who, when and where. Saving over a used slot takes a
## second click. Words come from story.json "saves".

var mode := "load"  # or "save"
var on_close: Callable
## Called with the slot name when the player saves (the map does the saving,
## since it knows whether a fight is on and has map state to store first).
var on_save: Callable

var _list: VBoxContainer
var _armed := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var w := words()
	var r := UITheme.modal(self, String(w.get("save_title" if mode == "save" else "load_title", "")), Vector2(600, 0))
	var vb: VBoxContainer = r[1]
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	vb.add_child(_list)
	vb.add_child(UITheme.button(String(w.get("close", "")), func(): on_close.call(), 120))
	_fill()


static func words() -> Dictionary:
	return DB.story().get("saves", {})


## "Slot 3", "Quicksave", "Autosave".
static func slot_name(slot: String) -> String:
	var w := words()
	if slot == "auto" or slot == "quick":
		return String(w.get(slot, slot))
	return String(w.get("slot", "%d")) % int(slot.substr(4))


## The two lines a slot shows: who and when in the story, then where and
## when it was saved.
static func describe(info: Dictionary) -> String:
	var w := words()
	if info.is_empty():
		return String(w.get("empty", ""))
	if info.get("damaged", false):
		return String(w.get("damaged", ""))
	var who := String(w.get("who", "%s, level %d")) % [info.get("name", ""), int(info.get("level", 1))]
	var when := String(info.get("date", ""))
	if when == "":
		when = String(w.get("day", "Day %d")) % int(info.get("day", 1))
	var line2: Array = []
	if String(info.get("place", "")) != "":
		line2.append(info["place"])
	var t := int(info.get("saved_at", 0))
	if t > 0:
		line2.append(String(w.get("saved", "saved %s")) % stamp(t))
	return "%s.  %s\n%s" % [who, when, ", ".join(line2)]


## A unix time as local "2026-11-20 14:05".
static func stamp(t: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var s := Time.get_datetime_string_from_unix_time(t + bias * 60, true)
	return s.substr(0, 16)


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var w := words()
	for slot in Game.save_slots(mode == "load"):
		var info: Dictionary = Game.save_info(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var name_l := UITheme.label(slot_name(slot), 15, UITheme.BRONZE)
		name_l.custom_minimum_size.x = 100
		row.add_child(name_l)
		var text := describe(info)
		if mode == "save" and slot == _armed:
			text = String(w.get("confirm", "")) + "\n" + text.get_slice("\n", 0)
		var b := UITheme.button(text, _pick.bind(slot, info))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(470, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mode == "load":
			b.disabled = info.is_empty() or info.get("damaged", false)
		if mode == "save" and slot == _armed:
			b.add_theme_color_override("font_color", UITheme.WARN)
		row.add_child(b)


func _pick(slot: String, info: Dictionary) -> void:
	if mode == "load":
		Game.goto("load", {"slot": slot})
		return
	if not info.is_empty() and _armed != slot:
		_armed = slot
		_fill()
		return
	on_save.call(slot)
	on_close.call()
