extends TestCase
## Content integrity: every dialogue, map, NPC and story reference points at
## something that exists. Catches writing typos before they reach a player.


func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://data/" + dir):
		if f.ends_with(ext):
			out.append(f.get_basename())
	return out


func _dlg_exists(id: String) -> bool:
	return FileAccess.file_exists("res://data/dialogue/%s.dlg" % id)


func test_every_dialogue_is_clean() -> void:
	for id in _files("dialogue", ".dlg"):
		var d := Dialogue.parse(FileAccess.get_file_as_string("res://data/dialogue/%s.dlg" % id))
		for e in Dialogue.validate(d):
			fail("%s.dlg: %s" % [id, e])


func test_every_ending_is_clean() -> void:
	var quests := {}
	for q in DB.load_json("quests.json")["quests"]:
		quests[q["id"]] = q["stages"]
	for f in _files("endings", ".json"):
		for e in Endings.validate("endings/%s.json" % f):
			fail(e)
		for s in DB.load_json("endings/%s.json" % f)["slides"]:
			for c in s.get("if", []):
				var parts := String(c).trim_prefix("!").split(" ")
				if parts[0] == "quest" and parts.size() > 1:
					var qs := parts[1].split("=")
					check(quests.has(qs[0]), "%s: unknown quest in %s" % [f, c])
					if qs.size() > 1 and quests.has(qs[0]):
						check(quests[qs[0]].has(qs[1]), "%s: unknown stage in %s" % [f, c])
		var gs := GameState.new()
		gs.player = CharacterSheet.create("Test", {}, [])
		check(not Endings.pages(gs, "endings/%s.json" % f).is_empty(), "%s has pages for a bare game" % f)


func test_npc_templates_reference_real_things() -> void:
	for t in DB.load_json("npcs.json")["npcs"]:
		for e in t.get("equip", []):
			check(not DB.item(e).is_empty(), "%s equips unknown %s" % [t["id"], e])
		for e in t.get("items", []):
			var iid: String = e[0] if e is Array else str(e)
			check(not DB.item(iid).is_empty(), "%s carries unknown %s" % [t["id"], iid])
		if t.has("dialogue"):
			check(_dlg_exists(t["dialogue"]), "%s has missing dialogue %s" % [t["id"], t["dialogue"]])


func test_readable_items_have_dialogues() -> void:
	for it in DB.load_json("items.json")["items"]:
		if it.has("read"):
			check(_dlg_exists(it["read"]), "%s reads missing dialogue %s" % [it["id"], it["read"]])


func test_maps_reference_real_things() -> void:
	for id in _files("maps", ".json"):
		var def := DB.map_def(id)
		var m := MapData.from_def(def)
		for a in def.get("actors", []):
			check(not DB.npc_template(a["template"]).is_empty(), "%s: unknown template %s" % [id, a["template"]])
			if a.has("mark"):
				check(m.has_mark(a["mark"]), "%s: actor mark %s missing" % [id, a["mark"]])
			if a.has("dialogue"):
				check(_dlg_exists(a["dialogue"]), "%s: missing dialogue %s" % [id, a["dialogue"]])
		for c in def.get("containers", []):
			check(m.has_mark(c["mark"]), "%s: container mark %s missing" % [id, c["mark"]])
			for it in c.get("items", []):
				check(not DB.item(it[0]).is_empty(), "%s: unknown item %s" % [id, it[0]])
		for e in def.get("exits", []):
			check(m.has_mark(e["mark"]), "%s: exit mark %s missing" % [id, e["mark"]])
			var to: String = e.get("to", "world")
			if to.begins_with("map:"):
				var target := DB.map_def(to.substr(4))
				check(not target.is_empty(), "%s: exit to missing map %s" % [id, to])
				if not target.is_empty():
					check(MapData.from_def(target).has_mark(e.get("entry", "start")), "%s: exit entry %s missing in %s" % [id, e.get("entry", "start"), to])
		for t in def.get("triggers", []):
			check(m.has_mark(t["mark"]), "%s: trigger mark %s missing" % [id, t["mark"]])
			if t.has("dialogue"):
				check(_dlg_exists(t["dialogue"]), "%s: trigger dialogue %s missing" % [id, t["dialogue"]])
		if def.has("arrive_dialogue"):
			check(_dlg_exists(def["arrive_dialogue"]), "%s: arrive dialogue missing" % id)
		if def.has("deadline"):
			check(_dlg_exists(def["deadline"]["dialogue"]), "%s: deadline dialogue missing" % id)
		for ad in def.get("arrive_dialogues", []):
			check(_dlg_exists(ad.get("dialogue", "")), "%s: arrival scene %s has no dialogue" % [id, ad.get("id", "")])
			check(ad.has("id"), "%s: arrival scene without an id" % id)
		for h in def.get("hospitality", []):
			check(h.get("host", "") != "", "%s: a roof with no host" % id)
			if h.has("mark"):
				check(m.has_mark(h["mark"]), "%s: hospitality mark %s missing" % [id, h["mark"]])
		if not def.get("encounter", false):
			check(m.has_mark("start"), "%s has a start mark" % id)


func test_road_encounters_are_well_formed() -> void:
	var world: Dictionary = DB.load_json("world.json")
	var skills := Dialogue.SKILL_IDS
	for e in world["encounters"]:
		var id: String = e["id"]
		check(not e["actors"].is_empty(), "%s has no actors" % id)
		var hostile := false
		for a in e["actors"]:
			check(not DB.npc_template(a).is_empty(), "%s uses unknown NPC %s" % [id, a])
			hostile = hostile or DB.npc_template(a).get("hostile", false)
		# Anyone who'd rather talk than fight must offer a way to.
		var humans := false
		for a in e["actors"]:
			if DB.npc_template(a).get("faction", "") in ["bandit", "rome"]:
				humans = true
		if hostile and humans:
			check(not e.get("parley", []).is_empty(), "%s is a human fight with no way out" % id)
		if e.has("dialogue"):
			check(_dlg_exists(e["dialogue"]), "%s: encounter dialogue %s missing" % [id, e["dialogue"]])
		if e.get("forced", false):
			check(e.has("days") or e.has("if"), "%s: a forced encounter with no window" % id)
		for p in e.get("parley", []):
			check(p.get("label", "") != "", "%s: parley option without a label" % id)
			if p.get("kind", "") == "pay":
				check(int(p.get("cost", 0)) > 0 and p.get("text", "") != "", "%s: bad pay option" % id)
			elif p.get("kind", "") == "skill":
				check(p.get("skill", "") in skills, "%s: unknown skill %s" % [id, p.get("skill", "")])
				check(p.get("win", "") != "" and p.get("lose", "") != "", "%s: skill option needs win and lose text" % id)
			else:
				fail("%s: unknown parley kind %s" % [id, p.get("kind", "")])


func test_world_locations_enter_at_real_marks() -> void:
	for l in DB.world()["locations"]:
		if l.has("map"):
			var m := MapData.from_def(DB.map_def(l["map"]))
			check(m.has_mark(l.get("entry", "start")), "%s: entry %s missing" % [l["id"], l.get("entry", "start")])
		for v in l.get("map_by_flag", []):
			var vm: String = v.get("map", l.get("map", ""))
			check(not DB.map_def(vm).is_empty(), "%s: map %s for flag %s exists" % [l["id"], vm, v["flag"]])
			var m2 := MapData.from_def(DB.map_def(vm))
			check(m2.has_mark(v.get("entry", l.get("entry", "start"))), "%s: %s entry for flag %s missing" % [l["id"], vm, v["flag"]])


func test_story_start_is_complete() -> void:
	var st := DB.story()
	var m := MapData.from_def(DB.map_def(st["start_map"]))
	check(m.has_mark(st.get("start_entry", "start")), "start entry exists")
	for it in st.get("start_items", []):
		check(not DB.item(it[0]).is_empty(), "start item %s exists" % it[0])
	var hero := CharacterSheet.create("Test", {}, ["blades", "sneak", "speech"])
	for it in st.get("start_items", []):
		hero.inventory.add(it[0], int(it[1]))
	for id in st.get("start_equip", []):
		check(hero.equip(id), "start gear %s can be equipped" % id)
	if st.has("intro"):
		check(FileAccess.file_exists("res://data/" + st["intro"]), "intro text exists")


func _reachable(m: MapData, from: Vector2i, blocked: Array = []) -> Dictionary:
	var seen := {from: true}
	var todo: Array = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for n in Hex.neighbors(c):
			if not seen.has(n) and m.is_walkable(n) and not n in blocked:
				seen[n] = true
				todo.append(n)
	return seen


func _near(seen: Dictionary, c: Vector2i) -> bool:
	if seen.has(c):
		return true
	for n in Hex.neighbors(c):
		if seen.has(n):
			return true
	return false


func test_everything_on_a_map_can_be_reached_from_its_start() -> void:
	for id in _files("maps", ".json"):
		var def := DB.map_def(id)
		if def.get("encounter", false):
			continue
		var m := MapData.from_def(def)
		var seen := _reachable(m, m.mark("start"))
		for a in def.get("actors", []):
			if a.has("mark"):
				check(_near(seen, m.mark(a["mark"])), "%s: %s can be reached" % [id, a["uid"]])
		for c in def.get("containers", []):
			check(_near(seen, m.mark(c["mark"])), "%s: container %s can be reached" % [id, c["mark"]])
		for e in def.get("exits", []):
			check(_near(seen, m.mark(e["mark"])), "%s: exit %s can be reached" % [id, e["mark"]])
		for t in def.get("triggers", []):
			check(_near(seen, m.mark(t["mark"])), "%s: trigger %s can be reached" % [id, t["mark"]])


func test_the_ford_barrier_cannot_be_walked_around() -> void:
	var m := MapData.from_def(DB.map_def("oltis_ford"))
	var seen := _reachable(m, m.mark("start"), m.mark_cells("barrier"))
	check(not _near(seen, m.mark("exit")), "the far bank is only reached through the barrier")
