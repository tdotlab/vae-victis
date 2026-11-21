class_name Companions
extends RefCounted
## The people (and animals) who travel with the player: how many will follow,
## what each thinks of the player, and when one has had enough. Pure rules on
## a GameState; the map does the joining and parting.
##
## A companion's NPC template carries a "companion" block:
##   "companion": {"start": 0, "honor": 0.5, "leave_at": -30,
##                 "part_dialogue": "com_theron_part", "pet": false,
##                 "deeds": {"guest_murder": -40, "joined_house": -25}}
## "honor" scales every change to the player's Honor into opinion (negative
## for someone who likes a scoundrel). "deeds" are what content reports with
## `~ deed tag`: each companion traveling with the player reacts by their own
## table. At or below "leave_at" the companion parts at the next quiet moment,
## through "part_dialogue" if they have one. A "pet" doesn't count against the
## number of followers Presence allows.


static func def(template: String) -> Dictionary:
	return DB.npc_template(template).get("companion", {})


static func text(key: String, fallback: String) -> String:
	return String(DB.story().get("companion_text", {}).get(key, fallback))


## How many people will follow the player: half their Presence, at least one.
static func cap(gs: GameState) -> int:
	var div := int(DB.rules().get("companion_presence_div", 2))
	return maxi(1, gs.player.attr("PRE") / maxi(1, div))


static func is_pet(template: String) -> bool:
	return def(template).get("pet", false)


## Followers who count against the cap.
static func count(gs: GameState) -> int:
	var n := 0
	for cd in gs.companions:
		if not is_pet(String(cd.get("template", ""))):
			n += 1
	return n


static func has_room(gs: GameState, template: String = "") -> bool:
	return (template != "" and is_pet(template)) or count(gs) < cap(gs)


static func with_player(gs: GameState, who: String) -> bool:
	for cd in gs.companions:
		if cd.get("uid", "") == who or cd.get("template", "") == who:
			return true
	return false


static func _template_of(gs: GameState, uid: String) -> String:
	for cd in gs.companions:
		if cd.get("uid", "") == uid:
			return String(cd.get("template", uid))
	return uid


static func opinion(gs: GameState, uid: String) -> int:
	if gs.opinion.has(uid):
		return int(gs.opinion[uid])
	return int(def(_template_of(gs, uid)).get("start", 0))


static func change(gs: GameState, uid: String, amount: int) -> void:
	gs.opinion[uid] = opinion(gs, uid) + amount


## Everyone traveling with the player reacts to a deed. Returns log lines
## [[text, kind]] for the ones whose opinion moved.
static func react(gs: GameState, deed: String) -> Array:
	var out: Array = []
	for cd in gs.companions:
		var uid: String = cd.get("uid", "")
		var d := def(String(cd.get("template", uid)))
		var n := int(d.get("deeds", {}).get(deed, 0))
		if n != 0:
			change(gs, uid, n)
			out.append(_line(String(cd.get("sheet", {}).get("name", uid)), n))
	return out


## Everyone traveling with the player reacts to a change in Honor.
static func react_honor(gs: GameState, amount: int) -> Array:
	var out: Array = []
	for cd in gs.companions:
		var uid: String = cd.get("uid", "")
		var w := float(def(String(cd.get("template", uid))).get("honor", 0.0))
		var n := int(round(amount * w))
		if n != 0:
			change(gs, uid, n)
			if absi(n) >= 3:
				out.append(_line(String(cd.get("sheet", {}).get("name", uid)), n))
	return out


static func _line(who: String, n: int) -> Array:
	if n > 0:
		return [text("approves", "%s approves.") % who, "good"]
	return [text("disapproves", "%s doesn't like that.") % who, "bad"]


## The companion who has had enough, or "" if nobody. Someone who has been
## through their parting once (and was talked round, say) only goes again if
## their opinion sinks lower than it was then.
static func next_to_part(gs: GameState) -> String:
	for cd in gs.companions:
		var uid: String = cd.get("uid", "")
		var d := def(String(cd.get("template", uid)))
		if not d.has("leave_at") or cd.get("dead", false):
			continue
		var op := opinion(gs, uid)
		if op > int(d["leave_at"]):
			continue
		var key := "part_at_" + uid
		if gs.flags.has(key) and op >= int(gs.flags[key]):
			continue
		return uid
	return ""


## Records that a parting started at today's opinion (see next_to_part).
static func mark_parting(gs: GameState, uid: String) -> void:
	gs.flags["part_at_" + uid] = opinion(gs, uid)


## A word for the character sheet: "trusts you", "is wary of you".
static func opinion_word(gs: GameState, uid: String) -> String:
	var op := opinion(gs, uid)
	var words: Array = DB.story().get("opinion_words", [])
	for w in words:
		if op >= int(w[0]):
			return String(w[1])
	return "" if words.is_empty() else String(words[-1][1])
