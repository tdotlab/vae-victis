class_name Hospitality
extends RefCounted
## The guest-bond. Under a host's roof, guest and host are sacred to each
## other: raising a hand against either is the worst thing a Gaul can do, far
## worse than murder on the road. A map declares its roofs:
##   "hospitality": [{"host": "brigodunon", "mark": "hall", "if_flag": "..."}]
## (no mark: the whole map). Attacking someone there who wasn't already
## fighting you breaks it; so does a dialogue `~ violate <host faction>`.
## The price is in rules.json "guest_bond".


## The host faction whose roof covers this cell, or "" if none does.
static func roof_at(gs: GameState, map: MapData, c: Vector2i) -> String:
	for h in map.def.get("hospitality", []):
		if h.has("if_flag") and gs.flag(String(h["if_flag"])) == 0:
			continue
		if h.has("mark") and not map.mark_cells(String(h["mark"])).has(c):
			continue
		return String(h.get("host", ""))
	return ""


## Applies the penalty for breaking the guest-bond. Returns log lines.
static func violate(gs: GameState, host: String) -> Array:
	var r: Dictionary = DB.rules().get("guest_bond", {})
	gs.honor += int(r.get("honor", -60))
	if host != "":
		gs.add_standing(host, int(r.get("standing", -40)))
		gs.set_flag("guest_murder_" + host)
	gs.set_flag("guest_murder", gs.flag("guest_murder") + 1)
	var out: Array = [[Companions.text("guest_bond", "You have broken the guest-bond. Nobody who hears of it will forget."), "bad"]]
	out.append_array(Companions.react(gs, "guest_murder"))
	return out
