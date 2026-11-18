class_name Dialogue
extends RefCounted
## Conversation scripts in a plain-text format meant for writers, plus the
## logic that walks them. Pure: works on a GameState and reports what the
## screen must do (messages, xp, actions like starting a fight or a trade).
##
## Format (data/dialogue/<id>.dlg):
##   === node_id                  start a node; the first node is the entry
##   Plain text line              what the speaker says (blank line = new paragraph)
##   ~ effect; effect             apply effects when this line is reached
##   -> target                    jump to another node (END closes the talk)
##   * Choice text -> target      a reply the player can pick
##   * Choice -> target ~ effect  a reply with effects
##   * [roll speech -10] Lie -> win | lose    a chance-based reply
## Any line may start with [conditions], comma-separated, e.g.
##   [flag met_elder]  [!flag met_elder]  [flag x>=2]  [speech 50]  [STR 7]
##   [item salt]  [item salt 3]  [silver 20]  [honor >= 25]  [standing aedui 10]
##   [quest hostages=find_tally]  [quest hostages active]  [trait once_sold]
##   [perk silver_tongue]  [sex f]  [day >= 30]  [season winter]  [companion theron]
## Skill and attribute conditions show to the player as a tag like [Speech];
## others silently hide the line.
## Effects:
##   set flag [n] | clear flag | add flag n | xp n | quest id stage [active|done|failed]
##   give item [n] | take item [n] | silver n | honor n | renown n | standing faction n
##   time minutes | heal n | say text | fight | barter | join | leave | travel map entry
##   title text | known location

const SKILL_IDS := ["blades", "spears", "missiles", "brawling", "shield", "sneak", "locks", "steal",
	"traps", "healing", "surgery", "speech", "barter", "gambling", "lore", "latin", "survival"]
const ATTR_IDS := ["STR", "END", "AGI", "PER", "WIT", "PRE", "FOR"]

static var _cache: Dictionary = {}


## Parses a dialogue file. Returns {"entry": id, "nodes": {id: [ops]}}.
static func parse(text: String, source: String = "") -> Dictionary:
	var nodes := {}
	var entry := ""
	var cur: Array = []
	var cur_id := ""
	var lineno := 0
	for raw in text.split("\n"):
		lineno += 1
		var line := raw.strip_edges()
		if line.begins_with("//"):
			continue
		if line.begins_with("==="):
			cur_id = line.trim_prefix("===").strip_edges()
			cur = []
			nodes[cur_id] = cur
			if entry == "":
				entry = cur_id
			continue
		if cur_id == "":
			continue
		if line == "":
			if not cur.is_empty() and cur[-1]["t"] == "text":
				cur.append({"t": "para", "cond": []})
			continue
		var conds: Array = []
		if line.begins_with("*"):
			line = line.substr(1).strip_edges()
			var c := _take_conds(line)
			conds = c[0]
			line = c[1]
			cur.append(_parse_choice(line, conds, source, lineno))
			continue
		var c2 := _take_conds(line)
		conds = c2[0]
		line = c2[1]
		if line.begins_with("~"):
			cur.append({"t": "fx", "cond": conds, "fx": _parse_fx(line.substr(1))})
		elif line.begins_with("->"):
			cur.append({"t": "jump", "cond": conds, "to": line.substr(2).strip_edges()})
		else:
			cur.append({"t": "text", "cond": conds, "text": line})
	return {"entry": entry, "nodes": nodes}


static func _take_conds(line: String) -> Array:
	if not line.begins_with("["):
		return [[], line]
	var close := line.find("]")
	if close < 0:
		return [[], line]
	var inner := line.substr(1, close - 1)
	var conds: Array = []
	for part in inner.split(","):
		var p := part.strip_edges()
		if p != "":
			conds.append(p)
	return [conds, line.substr(close + 1).strip_edges()]


static func _parse_choice(line: String, conds: Array, source: String, lineno: int) -> Dictionary:
	var fx: Array = []
	var tilde := line.find(" ~ ")
	if tilde >= 0:
		fx = _parse_fx(line.substr(tilde + 3))
		line = line.substr(0, tilde)
	var arrow := line.rfind("->")
	var to := "END"
	var text := line
	if arrow >= 0:
		to = line.substr(arrow + 2).strip_edges()
		text = line.substr(0, arrow).strip_edges()
	elif source != "":
		push_warning("%s:%d: choice without a target" % [source, lineno])
	var ch := {"t": "choice", "cond": [], "text": text, "to": to, "fx": fx}
	for c in conds:
		if c.begins_with("roll "):
			ch["roll"] = c.substr(5).strip_edges()
		else:
			ch["cond"].append(c)
	if ch.has("roll"):
		var parts := to.split("|")
		ch["to"] = parts[0].strip_edges()
		ch["fail"] = parts[1].strip_edges() if parts.size() > 1 else "END"
	return ch


static func _parse_fx(s: String) -> Array:
	var out: Array = []
	for part in s.split(";"):
		var p := part.strip_edges()
		if p != "":
			out.append(p)
	return out


static func load_dialogue(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var path := "res://data/dialogue/%s.dlg" % id
	if not FileAccess.file_exists(path):
		push_error("Missing dialogue " + path)
		return {"entry": "", "nodes": {}}
	var d := parse(FileAccess.get_file_as_string(path), path)
	_cache[id] = d
	return d


# --- Conditions -------------------------------------------------------------------

## Label shown before a choice for visible checks, e.g. "[Speech]".
static func check_label(conds: Array) -> String:
	var labels: Array = []
	for c in conds:
		var w: String = c.split(" ")[0]
		if w in SKILL_IDS:
			labels.append(w.capitalize())
		elif w in ATTR_IDS:
			labels.append(_attr_name(w))
	if labels.is_empty():
		return ""
	return "[" + ", ".join(labels) + "] "


static func _attr_name(id: String) -> String:
	for a in DB.rules()["attributes"]:
		if a["id"] == id:
			return a["name"]
	return id


static func _cmp(a: int, op: String, b: int) -> bool:
	match op:
		">=":
			return a >= b
		"<=":
			return a <= b
		">":
			return a > b
		"<":
			return a < b
		"=", "==":
			return a == b
		"!=":
			return a != b
	return a >= b


## Splits "x>=2" or "honor >= 25" style into [name, op, value]; value "" if none.
static func _split_op(s: String) -> Array:
	for op in [">=", "<=", "!=", "==", ">", "<", "="]:
		var i := s.find(op)
		if i >= 0:
			return [s.substr(0, i).strip_edges(), op, s.substr(i + op.length()).strip_edges()]
	return [s.strip_edges(), "", ""]


static func check(gs: GameState, cond: String, ctx: Dictionary = {}) -> bool:
	var neg := cond.begins_with("!")
	var c := cond.substr(1) if neg else cond
	var r := _check(gs, c.strip_edges(), ctx)
	return not r if neg else r


static func _check(gs: GameState, c: String, ctx: Dictionary) -> bool:
	var sp := c.find(" ")
	var head := c if sp < 0 else c.substr(0, sp)
	var rest := "" if sp < 0 else c.substr(sp + 1).strip_edges()
	var p := gs.player
	if head in SKILL_IDS:
		return p.skill(head) >= int(rest)
	if head in ATTR_IDS:
		return p.attr(head) >= int(rest)
	match head:
		"flag":
			var o := _split_op(rest)
			if o[1] == "":
				return gs.flag(o[0]) != 0
			return _cmp(gs.flag(o[0]), o[1], int(o[2]))
		"item":
			var parts := rest.split(" ")
			var n := int(parts[1]) if parts.size() > 1 else 1
			return p.inventory.count(parts[0]) + (1 if p.equipment.values().has(parts[0]) else 0) >= n
		"silver":
			return p.silver >= int(rest)
		"honor", "renown", "day", "level":
			var o2 := _split_op(c)
			var v := 0
			match head:
				"honor": v = gs.honor
				"renown": v = gs.renown
				"day": v = gs.day()
				"level": v = p.level
			return _cmp(v, o2[1] if o2[1] != "" else ">=", int(o2[2] if o2[2] != "" else rest))
		"standing":
			var parts2 := rest.split(" ")
			return gs.get_standing(parts2[0]) >= int(parts2[1])
		"quest":
			# quest id=stage | quest id active|done|failed|none
			if rest.find("=") >= 0:
				var o3 := _split_op(rest)
				return gs.quest_stage(o3[0]) == o3[2]
			var parts3 := rest.split(" ")
			var st := gs.quest_status(parts3[0])
			var want := parts3[1] if parts3.size() > 1 else "active"
			return st == ("" if want == "none" else want)
		"trait":
			return rest in p.traits
		"perk":
			return rest in p.perks
		"sex":
			return p.sex == rest
		"season":
			return gs.season() == rest
		"companion":
			for cd in gs.companions:
				if cd.get("uid", "") == rest or cd.get("template", "") == rest:
					return true
			return false
		"has":  # ctx flags supplied by the screen, e.g. "has speaker_hurt"
			return ctx.get(rest, false)
	push_warning("Unknown dialogue condition: " + c)
	return false


static func all_true(gs: GameState, conds: Array, ctx: Dictionary = {}) -> bool:
	for c in conds:
		if not check(gs, c, ctx):
			return false
	return true


## Chance for a roll condition such as "speech -10" or "STR 0".
static func roll_chance(gs: GameState, roll: String) -> int:
	var parts := roll.split(" ")
	var mod := int(parts[1]) if parts.size() > 1 else 0
	var base := 0
	if parts[0] in SKILL_IDS:
		base = gs.player.skill(parts[0])
	elif parts[0] in ATTR_IDS:
		base = gs.player.attr(parts[0]) * 10
	return clampi(base + mod, 5, 95)


# --- Effects ----------------------------------------------------------------------

## Applies effects to the game state. Returns {"messages": [[text, kind]], "xp": n, "actions": [..]}.
## Actions are things the screen must do: "fight", "barter", "join", "leave", "travel map entry".
static func apply(gs: GameState, fx: Array) -> Dictionary:
	var out := {"messages": [], "xp": 0, "actions": []}
	for e in fx:
		_apply_one(gs, str(e), out)
	return out


static func _apply_one(gs: GameState, e: String, out: Dictionary) -> void:
	var sp := e.find(" ")
	var head := e if sp < 0 else e.substr(0, sp)
	var rest := "" if sp < 0 else e.substr(sp + 1).strip_edges()
	var args := rest.split(" ", false)
	var p := gs.player
	match head:
		"set":
			gs.set_flag(args[0], int(args[1]) if args.size() > 1 else 1)
		"clear":
			gs.flags.erase(args[0])
		"add":
			gs.set_flag(args[0], gs.flag(args[0]) + int(args[1]))
		"xp":
			out["xp"] += int(args[0])
		"quest":
			var status := args[2] if args.size() > 2 else "active"
			var was := gs.quest_status(args[0])
			gs.set_quest(args[0], args[1], status)
			var q := DB.quest(args[0])
			var stage_text: String = q.get("stages", {}).get(args[1], "")
			if stage_text != "":
				gs.quest_log.append({"day": gs.day(), "quest": args[0], "text": stage_text})
			var qname: String = q.get("name", args[0])
			if was == "" and status == "active":
				out["messages"].append(["New quest: %s." % qname, "good"])
			elif status == "done" and was != "done":
				out["messages"].append(["Quest complete: %s." % qname, "good"])
				out["xp"] += int(q.get("xp", 0))
			elif status == "failed" and was != "failed":
				out["messages"].append(["Quest failed: %s." % qname, "bad"])
			elif stage_text != "":
				out["messages"].append(["Journal updated: %s." % qname, "info"])
		"give":
			var n := int(args[1]) if args.size() > 1 else 1
			p.inventory.add(args[0], n)
			out["messages"].append(["You receive %s%s." % [DB.item(args[0]).get("name", args[0]).to_lower(), (" x%d" % n) if n > 1 else ""], "good"])
		"take":
			var n2 := int(args[1]) if args.size() > 1 else 1
			var have := p.inventory.count(args[0])
			if have < n2:
				for slot in p.equipment:
					if p.equipment[slot] == args[0]:
						p.unequip(slot)
			p.inventory.remove(args[0], n2)
			out["messages"].append(["You hand over %s%s." % [DB.item(args[0]).get("name", args[0]).to_lower(), (" x%d" % n2) if n2 > 1 else ""], "info"])
		"silver":
			var n3 := int(args[0])
			p.silver = maxi(0, p.silver + n3)
			out["messages"].append([("You receive %d silver." % n3) if n3 > 0 else ("You pay %d silver." % -n3), "good" if n3 > 0 else "info"])
		"honor":
			gs.honor += int(args[0])
			out["messages"].append(["Your honor grows." if int(args[0]) > 0 else "Your honor suffers.", "good" if int(args[0]) > 0 else "bad"])
		"renown":
			var r := int(args[0])
			if r > 0 and p.has_flag("bards_friend"):
				r = int(ceil(r * 1.5))
			gs.renown += r
			if r > 0:
				out["messages"].append(["Word of this will spread.", "good"])
		"standing":
			gs.add_standing(args[0], int(args[1]))
		"time":
			gs.advance(int(args[0]))
		"heal":
			p.hp = mini(p.max_hp(), p.hp + int(args[0]))
			out["messages"].append(["You feel better.", "good"])
		"say":
			out["messages"].append([rest, "story"])
		"title":
			if not gs.titles.has(rest):
				gs.titles.append(rest)
		"known":
			if not gs.known_locations.has(rest):
				gs.known_locations.append(rest)
				out["messages"].append(["A new place is marked on your map.", "good"])
		"fight", "barter", "join", "leave", "travel", "end", "heal_all", "rest":
			out["actions"].append(e)
		_:
			push_warning("Unknown dialogue effect: " + e)


## Replaces {name} and {sibling} tokens in text.
static func fill(gs: GameState, text: String) -> String:
	var t := text.replace("{name}", gs.player.name)
	if t.find("{sibling}") >= 0:
		t = t.replace("{sibling}", DB.story().get("sibling", "your sibling"))
	return t


# --- Walking a conversation ---------------------------------------------------------

## Walks the ops of a node. Returns a "page":
## {"text": String, "choices": [{"text", "index", "label", "chance"}], "end": bool,
##  "messages": [...], "xp": n, "actions": [...]}
static func enter(gs: GameState, dlg: Dictionary, node_id: String, ctx: Dictionary = {}) -> Dictionary:
	var page := {"node": node_id, "text": "", "choices": [], "end": false, "messages": [], "xp": 0, "actions": []}
	var seen := 0
	var nid := node_id
	var paras: Array = [""]
	while true:
		seen += 1
		if seen > 50 or nid == "END" or not dlg["nodes"].has(nid):
			page["end"] = true
			if nid != "END" and not dlg["nodes"].has(nid):
				push_error("Dialogue: missing node " + nid)
			break
		page["node"] = nid
		var jumped := false
		var ops: Array = dlg["nodes"][nid]
		for i in range(ops.size()):
			var op: Dictionary = ops[i]
			match op["t"]:
				"text":
					if all_true(gs, op["cond"], ctx):
						paras[-1] = (paras[-1] + " " + fill(gs, op["text"])).strip_edges()
				"para":
					if paras[-1] != "":
						paras.append("")
				"fx":
					if all_true(gs, op["cond"], ctx):
						_merge(page, apply(gs, op["fx"]))
				"jump":
					if all_true(gs, op["cond"], ctx):
						nid = op["to"]
						jumped = true
						if paras[-1] != "":
							paras.append("")
						break
				"choice":
					if all_true(gs, op["cond"], ctx):
						var ch := {"text": fill(gs, op["text"]), "index": i, "label": check_label(op["cond"])}
						if op.has("roll"):
							ch["chance"] = roll_chance(gs, op["roll"])
							ch["label"] = check_label([op["roll"]])
						page["choices"].append(ch)
		if not jumped:
			break
	page["text"] = "\n\n".join(paras.filter(func(x): return x != ""))
	if page["choices"].is_empty() and not page["end"]:
		page["end"] = true
	return page


## Picks a choice. Returns the next page (with the choice's effects merged in).
static func choose(gs: GameState, dlg: Dictionary, node_id: String, op_index: int, ctx: Dictionary = {}) -> Dictionary:
	var op: Dictionary = dlg["nodes"][node_id][op_index]
	var fx_out := apply(gs, op.get("fx", []))
	var to: String = op["to"]
	var rolled := ""
	if op.has("roll"):
		var ok := gs.dice.chance(roll_chance(gs, op["roll"]))
		rolled = "success" if ok else "failure"
		if not ok:
			to = op["fail"]
	var page := enter(gs, dlg, to, ctx)
	_merge(page, fx_out, true)
	page["rolled"] = rolled
	return page


static func _merge(page: Dictionary, r: Dictionary, front: bool = false) -> void:
	if front:
		page["messages"] = r["messages"] + page["messages"]
		page["actions"] = r["actions"] + page["actions"]
	else:
		page["messages"] += r["messages"]
		page["actions"] += r["actions"]
	page["xp"] += r["xp"]
