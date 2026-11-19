class_name InventoryPanel
extends Control
## Your gear: what you carry, what you wear, and using or dropping things.
## In a fight, equipping or using something costs 2 action points.

var hud: HUD
var _list: ItemList2
var _slots: VBoxContainer
var _info: Label
var _actions: HBoxContainer
var _weight: Label
var _selected := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var r := UITheme.modal(self, "Gear", Vector2(820, 0))
	var vb: VBoxContainer = r[1]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	_list = ItemList2.new("Carried", Vector2(330, 380))
	_list.on_pick = _select
	hb.add_child(_list)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 430
	right.add_theme_constant_override("separation", 8)
	hb.add_child(right)
	right.add_child(UITheme.label("Worn and wielded", 16, UITheme.BRONZE))
	_slots = VBoxContainer.new()
	right.add_child(_slots)
	_info = UITheme.label("", 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(430, 150)
	right.add_child(_info)
	_actions = HBoxContainer.new()
	right.add_child(_actions)
	_weight = UITheme.label("", 14, UITheme.DIM)
	right.add_child(_weight)
	var row := HBoxContainer.new()
	vb.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UITheme.button("Close", func(): hud.close_modal(self), 120))
	_refresh()


func _sheet() -> CharacterSheet:
	return Game.state.player


func _refresh() -> void:
	var p := _sheet()
	_list.fill(ItemList2.sheet_entries(p, false))
	for c in _slots.get_children():
		c.queue_free()
	for slot in ["weapon", "shield", "armor", "helmet"]:
		var id := p.equipped(slot)
		var row := HBoxContainer.new()
		var name_ := UITheme.label("%s:" % slot.capitalize(), 14, UITheme.DIM)
		name_.custom_minimum_size.x = 80
		row.add_child(name_)
		var b := UITheme.button(DB.item(id).get("name", "(none)") if id != "" else "(none)", func(): _select_worn(slot), 260)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = id == ""
		row.add_child(b)
		_slots.add_child(row)
	var av := p.armor_values()
	_weight.text = "Carrying %s of %d.   Silver: %d.   Armor: threshold %d, resistance %d%%." % [
		str(snappedf(p.carry_weight(), 0.1)), p.derived("carry"), p.silver, av["dt"], av["dr"]]
	if _selected != "" and p.inventory.count(_selected) == 0:
		_selected = ""
		_info.text = ""
		_clear_actions()


func _clear_actions() -> void:
	for c in _actions.get_children():
		c.queue_free()


func _select(id: String) -> void:
	_selected = id
	var d := DB.item(id)
	_info.text = ItemList2._tooltip(d)
	_clear_actions()
	var p := _sheet()
	if p.slot_for(id) != "":
		var b := UITheme.button("Equip", func(): _do(func(): p.equip(id)), 110)
		b.disabled = not p.can_equip(id)
		_actions.add_child(b)
	if d.has("read") and hud.map != null:
		_actions.add_child(UITheme.button("Read", func(): _read(d["read"]), 110))
	if d.get("type", "") == "consumable":
		_actions.add_child(UITheme.button("Use", func(): _do(func(): use_item(id)), 110))
	if d.get("type", "") != "quest":
		_actions.add_child(UITheme.button("Drop", func(): _drop(id), 110))


func _select_worn(slot: String) -> void:
	var p := _sheet()
	var id := p.equipped(slot)
	_info.text = ItemList2._tooltip(DB.item(id))
	_clear_actions()
	_actions.add_child(UITheme.button("Take off", func(): _do(func(): p.unequip(slot)), 110))


## Runs an action, charging action points in a fight.
func _do(action: Callable) -> void:
	var m := hud.map
	if m and m.combat.active:
		if m.combat.current != m.player:
			Game.say("Wait for your turn.")
			return
		if m.player.ap < 2:
			Game.say("Not enough action points.")
			return
		m.player.ap -= 2
	action.call()
	_refresh()
	hud.refresh()
	if _selected != "" and _sheet().inventory.count(_selected) > 0:
		_select(_selected)


## Closes the inventory and opens the item's own talk (a letter, a tablet).
func _read(dlg_id: String) -> void:
	if hud.map.combat.active:
		Game.say("Not in the middle of a fight.")
		return
	hud.close_modal(self)
	hud.open_dialogue(dlg_id, null)


func _drop(id: String) -> void:
	var p := _sheet()
	p.inventory.remove(id, 1)
	Game.say("You leave the %s behind." % DB.item_name_lc(id))
	_refresh()


## Eats, drinks or applies an item. Healing items work better with skill.
static func use_item(id: String) -> void:
	var p := Game.state.player
	var d := DB.item(id)
	if p.inventory.count(id) <= 0:
		return
	p.inventory.remove(id, 1)
	var heal: Array = d.get("heal", [0, 0])
	var amount := Game.state.dice.range_i(int(heal[0]), int(heal[1]))
	if d.has("skill"):
		amount += p.skill(d["skill"]) / 20
	var before := p.hp
	p.hp = mini(p.max_hp(), p.hp + amount)
	Game.state.advance(2)
	Game.say("You use the %s. (+%d health)" % [DB.lc_first(str(d.get("name", id))), p.hp - before], "good")
	Game.stats_changed.emit()
