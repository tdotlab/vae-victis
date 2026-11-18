class_name BarterPanel
extends Control
## Trading: put goods on the table from both sides, then strike the deal.
## Silver settles the difference automatically.

var hud: HUD
var trader: Actor
var _their_goods: ItemList2
var _their_table: ItemList2
var _my_table: ItemList2
var _my_goods: ItemList2
var _summary: Label
var _deal: Button
var _tt := Inventory.new()   # trader's offer
var _mt := Inventory.new()   # player's offer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var r := UITheme.modal(self, "Trading with %s" % trader.display_name(), Vector2(1120, 0))
	var vb: VBoxContainer = r[1]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	var sz := Vector2(260, 360)
	_my_goods = ItemList2.new("Your goods", sz)
	_my_table = ItemList2.new("You offer", sz)
	_their_table = ItemList2.new("They offer", sz)
	_their_goods = ItemList2.new("Their goods", sz)
	for l in [_my_goods, _my_table, _their_table, _their_goods]:
		l.show_value = true
		hb.add_child(l)
	var standing := Game.state.get_standing(trader.faction)
	var p := Game.state.player
	_my_goods.price_factor = Trade.sell_factor(p, trader.sheet, standing)
	_my_table.price_factor = _my_goods.price_factor
	_their_goods.price_factor = Trade.buy_factor(p, trader.sheet, standing)
	_their_table.price_factor = _their_goods.price_factor
	_my_goods.on_pick = func(id):
		if DB.item(id).get("type", "") == "quest":
			return
		p.inventory.remove(id, 1)
		_mt.add(id, 1)
		_refresh()
	_my_table.on_pick = func(id):
		_mt.remove(id, 1)
		p.inventory.add(id, 1)
		_refresh()
	_their_goods.on_pick = func(id):
		trader.sheet.inventory.remove(id, 1)
		_tt.add(id, 1)
		_refresh()
	_their_table.on_pick = func(id):
		_tt.remove(id, 1)
		trader.sheet.inventory.add(id, 1)
		_refresh()
	_summary = UITheme.label("", 15)
	vb.add_child(_summary)
	var row := HBoxContainer.new()
	vb.add_child(row)
	_deal = UITheme.button("Strike the deal", _strike, 200)
	row.add_child(_deal)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UITheme.button("Done", request_close, 120))
	_refresh()


func _entries(inv: Inventory) -> Array:
	var out: Array = []
	for id in inv.ids():
		out.append([id, inv.count(id)])
	return out


func _refresh() -> void:
	var p := Game.state.player
	_my_goods.fill(_entries(p.inventory))
	_my_table.fill(_entries(_mt))
	_their_table.fill(_entries(_tt))
	_their_goods.fill(_entries(trader.sheet.inventory))
	var standing := Game.state.get_standing(trader.faction)
	var diff = Trade.settle(_mt, _tt, p, trader.sheet, standing)
	var txt := "Your silver: %d     Theirs: %d     " % [p.silver, trader.sheet.silver]
	if _mt.is_empty() and _tt.is_empty():
		txt += "Put something on the table."
		_deal.disabled = true
	elif diff == null:
		txt += "You can't cover the difference."
		_deal.disabled = true
	elif diff > 0:
		txt += "You pay %d silver on top." % diff
		_deal.disabled = false
	elif diff < 0:
		txt += "They pay you %d silver." % -diff
		_deal.disabled = false
	else:
		txt += "An even trade."
		_deal.disabled = false
	_summary.text = txt


func _strike() -> void:
	var p := Game.state.player
	var diff = Trade.settle(_mt, _tt, p, trader.sheet, Game.state.get_standing(trader.faction))
	if diff == null:
		return
	p.silver -= diff
	trader.sheet.silver += diff
	p.inventory.merge(_tt)
	trader.sheet.inventory.merge(_mt)
	_tt.clear()
	_mt.clear()
	Game.say("The deal is struck.", "good")
	_refresh()


func request_close() -> void:
	# Anything left on the table goes back where it came from.
	Game.state.player.inventory.merge(_mt)
	trader.sheet.inventory.merge(_tt)
	_mt.clear()
	_tt.clear()
	hud.close_modal(self)
