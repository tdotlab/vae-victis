class_name ItemList2
extends VBoxContainer
## A titled, scrollable list of item buttons ("Name x3  wt 2"). Clicking an
## entry calls on_pick(id). Shared by the inventory, loot and trade windows.

var on_pick: Callable
var on_hover: Callable
var _title: Label
var _box: VBoxContainer
var show_value := false
var price_factor := 1.0
var market: Dictionary = {}   # Prices.market, when prices follow the story


func _init(title: String = "", min_size: Vector2 = Vector2(300, 320)) -> void:
	add_theme_constant_override("separation", 4)
	_title = UITheme.label(title, 16, UITheme.BRONZE)
	add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = min_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 2)
	scroll.add_child(_box)


func set_title(t: String) -> void:
	_title.text = t


## entries: Array of [id, count] or [id, count, suffix].
func fill(entries: Array) -> void:
	for c in _box.get_children():
		c.queue_free()
	for e in entries:
		var id: String = e[0]
		var n: int = e[1]
		var d := DB.item(id)
		var txt: String = d.get("name", id)
		if n > 1:
			txt += " x%d" % n
		if e.size() > 2:
			txt += e[2]
		if show_value:
			txt += "   %d" % Trade.price(id, price_factor, market)
		var b := UITheme.button(txt, func(): if on_pick.is_valid(): on_pick.call(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = _tooltip(d)
		if on_hover.is_valid():
			b.mouse_entered.connect(func(): on_hover.call(id))
		_box.add_child(b)
	if entries.is_empty():
		_box.add_child(UITheme.label("(nothing)", 14, UITheme.DIM))


static func _tooltip(d: Dictionary) -> String:
	var lines: Array = [d.get("name", "")]
	match d.get("type", ""):
		"weapon":
			lines.append("Damage %d-%d, %d AP, range %d" % [d["dmg"][0], d["dmg"][1], d.get("ap", 3), d.get("range", 1)])
			if d.get("two_handed", false):
				lines.append("Two-handed")
		"shield":
			lines.append("Block %d" % d.get("block", 0))
		"armor", "helmet":
			lines.append("Threshold %d, resistance %d%%" % [d.get("dt", 0), d.get("dr", 0)])
	lines.append("Weight %s, value %d" % [str(d.get("weight", 0)), d.get("value", 0)])
	if d.has("desc"):
		lines.append(d["desc"])
	return "\n".join(lines)


## Inventory plus equipped items of a sheet, as list entries.
static func sheet_entries(sheet: CharacterSheet, include_equipped: bool) -> Array:
	var out: Array = []
	if include_equipped:
		for slot in ["weapon", "shield", "armor", "helmet"]:
			var id := sheet.equipped(slot)
			if id != "" and not DB.item(id).get("natural", false):
				out.append([id, 1, "  (worn)"])
	for id in sheet.inventory.ids():
		out.append([id, sheet.inventory.count(id)])
	return out
