class_name Prices
extends RefCounted
## Prices that move with the calendar and the story (data/prices.json).
##
## Named prices are what dialogue charges for one particular thing, such as
## getting Brigodunon's line struck from the house's book:
##   "named": {"brig_line": {"base": 60, "barter": true,
##       "steps": [{"if": ["flag aedui_defected"], "x": 10}, {"if": ["flag alesia_begun"], "x": 0}]}}
## Every step whose conditions hold multiplies the price; x 0 means it can't be
## bought at all any more. With "barter", the player's Barter skill brings the
## price down (see barter_discount). Dialogue uses [price id] (available and
## affordable), [priced id] (available), ~ pay id, and {price id} in text.
##
## Markets scale what traders ask and pay for some goods while the story says so:
##   "markets": [{"if": ["flag gergovia_besieged"], "maps": ["gergovia"], "types": ["consumable"], "x": 3.0}]
## "maps" are map id prefixes (none: everywhere); "items" and "types" pick the
## goods (neither: all goods). Multipliers from several markets stack.


static func data() -> Dictionary:
	var d = DB.load_json("prices.json")
	return d if d is Dictionary else {}


static func named_def(id: String) -> Dictionary:
	return data().get("named", {}).get(id, {})


## The price in silver right now, or -1 if it can't be had.
static func named(gs: GameState, id: String) -> int:
	var d := named_def(id)
	if d.is_empty():
		push_warning("Unknown price " + id)
		return -1
	var p := float(d.get("base", 0))
	for s in d.get("steps", []):
		if Dialogue.all_true(gs, s.get("if", [])):
			p *= float(s.get("x", 1.0))
	if p <= 0.0 and float(d.get("base", 0)) > 0.0:
		return -1
	if d.get("barter", false):
		p *= barter_discount(gs.player.skill("barter"))
	return int(round(p))


## A haggler pays less: 100% of the price at Barter 0, down to 60% at 100+.
static func barter_discount(barter: int) -> float:
	return clampf(1.0 - barter / 250.0, 0.6, 1.0)


static func can_pay(gs: GameState, id: String) -> bool:
	var p := named(gs, id)
	return p >= 0 and gs.player.silver >= p


## Market multipliers in force on a map: {"items": {id: x}, "types": {type: x}, "all": x}.
static func market(gs: GameState, map_id: String) -> Dictionary:
	var out := {"items": {}, "types": {}, "all": 1.0}
	for m in data().get("markets", []):
		var maps: Array = m.get("maps", [])
		if not maps.is_empty():
			var here := false
			for prefix in maps:
				if map_id.begins_with(String(prefix)):
					here = true
			if not here:
				continue
		if not Dialogue.all_true(gs, m.get("if", [])):
			continue
		var x := float(m.get("x", 1.0))
		var items: Array = m.get("items", [])
		var types: Array = m.get("types", [])
		if items.is_empty() and types.is_empty():
			out["all"] = float(out["all"]) * x
		for id in items:
			out["items"][id] = float(out["items"].get(id, 1.0)) * x
		for t in types:
			out["types"][t] = float(out["types"].get(t, 1.0)) * x
	return out


## How much the market scales one item's value.
static func item_mult(mk: Dictionary, id: String) -> float:
	if mk.is_empty():
		return 1.0
	var d := DB.item(id)
	return float(mk.get("all", 1.0)) * float(mk.get("items", {}).get(id, 1.0)) \
		* float(mk.get("types", {}).get(d.get("type", ""), 1.0))
