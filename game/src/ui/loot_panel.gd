class_name LootPanel
extends Control
## Taking things from a container or a body, and putting things back.

var hud: HUD
var title := ""
var cstate: Dictionary      # container state {"items": [[id, n]...], "silver": n}
var body: Actor             # or a body to search
var _theirs: ItemList2
var _mine: ItemList2
var _silver: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var r := UITheme.modal(self, title, Vector2(700, 0))
	var vb: VBoxContainer = r[1]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	_theirs = ItemList2.new("Here", Vector2(320, 340))
	_theirs.on_pick = _take
	hb.add_child(_theirs)
	_mine = ItemList2.new("Yours", Vector2(320, 340))
	_mine.on_pick = _put
	hb.add_child(_mine)
	var row := HBoxContainer.new()
	vb.add_child(row)
	_silver = UITheme.button("", _take_silver, 200)
	row.add_child(_silver)
	row.add_child(UITheme.button("Take all", _take_all, 140))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UITheme.button("Done", func(): hud.close_modal(self), 120))
	_refresh()


func _container_inv() -> Inventory:
	return Inventory.from_array(cstate.get("items", []))


func _save_container(inv: Inventory) -> void:
	cstate["items"] = inv.to_array()


func _refresh() -> void:
	var p := Game.state.player
	if body:
		_theirs.fill(ItemList2.sheet_entries(body.sheet, true))
		_silver.text = "Silver: %d" % body.sheet.silver
		_silver.disabled = body.sheet.silver == 0
	else:
		var inv := _container_inv()
		var entries: Array = []
		for id in inv.ids():
			entries.append([id, inv.count(id)])
		_theirs.fill(entries)
		_silver.text = "Silver: %d" % int(cstate.get("silver", 0))
		_silver.disabled = int(cstate.get("silver", 0)) == 0
	_mine.fill(ItemList2.sheet_entries(p, false))
	_mine.set_title("Yours  (carrying %s / %d)" % [str(snappedf(p.carry_weight(), 0.1)), p.derived("carry")])


func _take(id: String) -> void:
	var p := Game.state.player
	if body:
		if body.sheet.inventory.count(id) > 0:
			body.sheet.inventory.remove(id, 1)
		else:
			for slot in body.sheet.equipment:
				if body.sheet.equipment[slot] == id:
					body.sheet.equipment[slot] = ""
					break
	else:
		var inv := _container_inv()
		inv.remove(id, 1)
		_save_container(inv)
	p.inventory.add(id, 1)
	if p.is_overloaded():
		Game.say("You are carrying too much.", "warn")
	_refresh()


func _put(id: String) -> void:
	var p := Game.state.player
	if DB.item(id).get("type", "") == "quest":
		Game.say("You'd better keep that.")
		return
	p.inventory.remove(id, 1)
	if body:
		body.sheet.inventory.add(id, 1)
	else:
		var inv := _container_inv()
		inv.add(id, 1)
		_save_container(inv)
	_refresh()


func _take_silver() -> void:
	var p := Game.state.player
	if body:
		p.silver += body.sheet.silver
		body.sheet.silver = 0
	else:
		p.silver += int(cstate.get("silver", 0))
		cstate["silver"] = 0
	_refresh()


func _take_all() -> void:
	_take_silver()
	var guard := 0
	while guard < 500:
		guard += 1
		var entries: Array = ItemList2.sheet_entries(body.sheet, true) if body else _container_inv().to_array()
		if entries.is_empty():
			break
		_take(entries[0][0])
