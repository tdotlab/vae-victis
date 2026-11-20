class_name Endings
extends RefCounted
## Fallout-style ending slides. A file in data/endings/ lists slides, each
## with optional dialogue conditions; the ones that hold, in order, make the
## pages of the ending. Within a "group", only the first slide that holds is
## shown, so one outcome can have several mutually exclusive versions.
##
## File shape (JSON):
##   {"title": "End of Act One", "button": "Keep playing",
##    "slides": [{"group": "hostages", "if": ["flag epo_out"], "title": "...", "text": "..."}]}


## Pages for an ending: [{"title", "text"}], in file order.
static func pages(gs: GameState, path: String) -> Array:
	var d: Dictionary = DB.load_json(path.trim_prefix("res://data/"))
	var out: Array = []
	var used := {}
	for s in d.get("slides", []):
		var g: String = s.get("group", "")
		if g != "" and used.has(g):
			continue
		if not Dialogue.all_true(gs, s.get("if", [])):
			continue
		if g != "":
			used[g] = true
		out.append({"title": s.get("title", d.get("title", "")), "text": Dialogue.fill(gs, s.get("text", ""))})
	return out


## Problems in an ending file: unknown conditions, empty text. Empty if clean.
static func validate(path: String) -> Array:
	var errs: Array = []
	var d: Dictionary = DB.load_json(path)
	if d.get("slides", []).is_empty():
		errs.append("%s: no slides" % path)
	for s in d.get("slides", []):
		if str(s.get("text", "")).strip_edges() == "":
			errs.append("%s: a slide has no text" % path)
		for c in s.get("if", []):
			var head: String = Dialogue._split_op(String(c).trim_prefix("!").strip_edges().split(" ")[0])[0]
			if not (head in Dialogue.SKILL_IDS or head in Dialogue.ATTR_IDS or head in Dialogue.COND_HEADS):
				errs.append("%s: unknown condition %s" % [path, c])
	return errs
