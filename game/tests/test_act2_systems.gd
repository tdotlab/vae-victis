extends TestCase
## A2.1 systems: companions (cap, opinion, parting), the guest-bond, prices
## that move with the story, and scripted road encounters.


func _gs(pre: int = 6) -> GameState:
	var gs := GameState.new()
	gs.player = CharacterSheet.create("Tester", {"PRE": pre}, ["speech", "blades", "sneak"])
	gs.dice.reseed(3)
	return gs


func _with_theron(gs: GameState) -> void:
	gs.companions.append({"uid": "theron", "template": "theron", "sheet": {"name": "Theron"}})


# --- Companions ----------------------------------------------------------------

func test_presence_sets_how_many_follow() -> void:
	eq(Companions.cap(_gs(2)), 1, "PRE 2")
	eq(Companions.cap(_gs(1)), 1, "never below one")
	eq(Companions.cap(_gs(6)), 3, "PRE 6")
	var gs := _gs(2)
	check(Companions.has_room(gs), "room for the first")
	_with_theron(gs)
	eq(Companions.count(gs), 1)
	check(not Companions.has_room(gs), "PRE 2 leads one person")
	check(Dialogue.check(gs, "!room"), "[room] sees it too")


func test_opinion_starts_from_the_template_and_moves() -> void:
	var gs := _gs()
	_with_theron(gs)
	eq(Companions.opinion(gs, "theron"), 10, "Theron's start")
	Companions.change(gs, "theron", -4)
	eq(Companions.opinion(gs, "theron"), 6)
	check(Dialogue.check(gs, "opinion theron >= 6"))
	check(not Dialogue.check(gs, "opinion theron > 6"))
	Dialogue.apply(gs, ["opinion theron 5"])
	eq(Companions.opinion(gs, "theron"), 11)
	# Survives a save.
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	eq(Companions.opinion(back, "theron"), 11, "opinion after load")


func test_deeds_and_honor_move_opinion() -> void:
	var gs := _gs()
	_with_theron(gs)
	var lines := Companions.react(gs, "joined_house")
	eq(Companions.opinion(gs, "theron"), -15, "joined_house is -25")
	eq(lines.size(), 1)
	eq(lines[0][1], "bad")
	eq(Companions.react(gs, "nothing_he_cares_about").size(), 0)
	# Honor is weighted 0.3: -10 Honor is -3 opinion, and worth a line.
	eq(Dialogue.apply(gs, ["honor -10"])["messages"].size(), 2, "honor line and Theron's")
	eq(Companions.opinion(gs, "theron"), -18)
	# Small changes move him quietly.
	eq(Companions.react_honor(gs, 5).size(), 0)
	eq(Companions.opinion(gs, "theron"), -16)


func test_nobody_reacts_who_isnt_there() -> void:
	var gs := _gs()
	eq(Companions.react(gs, "guest_murder").size(), 0)
	eq(gs.opinion.size(), 0)


func test_parting_comes_once_per_low() -> void:
	var gs := _gs()
	_with_theron(gs)
	eq(Companions.next_to_part(gs), "")
	Companions.change(gs, "theron", -40)
	eq(Companions.next_to_part(gs), "theron", "at leave_at")
	Companions.mark_parting(gs, "theron")
	eq(Companions.next_to_part(gs), "", "talked round, at the same opinion")
	Companions.change(gs, "theron", 20)
	eq(Companions.next_to_part(gs), "")
	Companions.change(gs, "theron", -21)
	eq(Companions.next_to_part(gs), "theron", "lower than the last time")
	gs.companions[0]["dead"] = true
	eq(Companions.next_to_part(gs), "", "the dead don't leave")


func test_opinion_words() -> void:
	var gs := _gs()
	_with_theron(gs)
	eq(Companions.opinion_word(gs, "theron"), "thinks well of you")
	Companions.change(gs, "theron", -100)
	eq(Companions.opinion_word(gs, "theron"), "has had about enough of you")


# --- The guest-bond ------------------------------------------------------------

func test_breaking_the_guest_bond() -> void:
	var gs := _gs()
	_with_theron(gs)
	var lines := Hospitality.violate(gs, "brigodunon")
	eq(gs.honor, -60)
	eq(gs.get_standing("brigodunon"), -40)
	eq(gs.flag("guest_murder_brigodunon"), 1)
	eq(gs.flag("guest_murder"), 1)
	eq(lines.size(), 2, "the bond line and Theron's")
	eq(Companions.opinion(gs, "theron"), -30)
	eq(Companions.next_to_part(gs), "theron", "Theron won't stay for that")
	Dialogue.apply(gs, ["violate"])
	eq(gs.flag("guest_murder"), 2, "a second time, no host named")
	eq(gs.honor, -120)


func test_roofs_cover_their_marks() -> void:
	var gs := _gs()
	var m := MapData.load_map("sandbox")
	m.def = m.def.duplicate()
	var cell: Vector2i = m.mark_cells("start")[0]
	eq(Hospitality.roof_at(gs, m, cell), "", "no roofs declared")
	m.def["hospitality"] = [{"host": "villager", "mark": "start", "if_flag": "feast"}]
	eq(Hospitality.roof_at(gs, m, cell), "", "not before the feast")
	gs.set_flag("feast")
	eq(Hospitality.roof_at(gs, m, cell), "villager")
	eq(Hospitality.roof_at(gs, m, cell + Vector2i(40, 40)), "", "outside the mark")
	m.def["hospitality"] = [{"host": "villager"}]
	eq(Hospitality.roof_at(gs, m, cell + Vector2i(40, 40)), "villager", "no mark: the whole map")


# --- Prices -------------------------------------------------------------------

func test_named_price_moves_with_the_story() -> void:
	var gs := _gs()
	var disc := Prices.barter_discount(gs.player.skill("barter"))
	eq(Prices.named(gs, "brig_line"), int(round(80 * disc)), "before Noviodunum")
	gs.set_flag("aedui_defected")
	eq(Prices.named(gs, "brig_line"), int(round(800 * disc)), "ten times after it")
	gs.set_flag("alesia_begun")
	eq(Prices.named(gs, "brig_line"), -1, "gone at Alesia")
	check(not Dialogue.check(gs, "priced brig_line"))


func test_barter_discount_bounds() -> void:
	near(Prices.barter_discount(0), 1.0)
	near(Prices.barter_discount(50), 0.8)
	near(Prices.barter_discount(300), 0.6)


func test_paying_a_named_price() -> void:
	var gs := _gs()
	var p := Prices.named(gs, "brig_line")
	gs.player.silver = p - 1
	check(Dialogue.check(gs, "priced brig_line"), "can be had")
	check(not Dialogue.check(gs, "price brig_line"), "but not afforded")
	gs.player.silver = p + 5
	check(Dialogue.check(gs, "price brig_line"))
	eq(Dialogue.fill(gs, "It costs {price brig_line}."), "It costs %d." % p)
	Dialogue.apply(gs, ["pay brig_line"])
	eq(gs.player.silver, 5)
	gs.set_flag("alesia_begun")
	eq(Dialogue.fill(gs, "{price brig_line}"), "?")


func test_siege_market() -> void:
	var gs := _gs()
	eq(Prices.item_mult(Prices.market(gs, "gergovia_lower"), "bread"), 1.0, "before the siege")
	gs.set_flag("gergovia_besieged")
	var mk := Prices.market(gs, "gergovia_lower")
	near(Prices.item_mult(mk, "bread"), 3.0, 0.001, "bread under siege")
	near(Prices.item_mult(mk, "dagger"), 1.0, 0.001, "iron isn't food")
	near(Prices.item_mult(Prices.market(gs, "brigodunon"), "bread"), 1.0, 0.001, "not at home")
	var trader := CharacterSheet.create("Trader", {}, ["barter"])
	trader.silver = 500
	var want := Inventory.new()
	want.add("bread", 10)
	var none := Inventory.new()
	gs.player.silver = 500
	var normal: int = Trade.settle(none, want, gs.player, trader)
	var sieged: int = Trade.settle(none, want, gs.player, trader, 0, mk)
	check(sieged >= normal * 3 - 1 and sieged <= normal * 3 + 1, "ten loaves cost three times as much: %d vs %d" % [sieged, normal])
	gs.set_flag("gergovia_lifted")
	near(Prices.item_mult(Prices.market(gs, "gergovia_lower"), "bread"), 1.0, 0.001, "after the siege")


# --- Dialogue plumbing -----------------------------------------------------------

func test_new_actions_reach_the_screen() -> void:
	var gs := _gs()
	var out := Dialogue.apply(gs, ["ally", "ally_all aedui", "part"])
	eq(out["actions"], ["ally", "ally_all aedui", "part"])


func test_validate_catches_bad_prices_and_opinions() -> void:
	var d := Dialogue.parse("""
=== start
[price no_such_price] Hm.
It costs {price nor_this}.
* [opinion nobody >= 3] Hi -> END ~ pay not_one; opinion nobody 2
""")
	var errs := Dialogue.validate(d)
	eq(errs.size(), 5, str(errs))


# --- Scripted road encounters -----------------------------------------------------

func test_forced_encounter_fires_once_in_its_window() -> void:
	var gs := _gs()
	var encs := [
		{"id": "random", "actors": ["wolf"]},
		{"id": "runner", "forced": true, "days": [150, 9999], "if": ["!flag home_visited"], "actors": ["test_villager"]},
	]
	gs.minutes = 140 * 1440
	eq(WorldData.forced_encounter(encs, gs), {}, "too early")
	gs.minutes = 151 * 1440
	eq(WorldData.forced_encounter(encs, gs).get("id", ""), "runner")
	gs.set_flag("home_visited")
	eq(WorldData.forced_encounter(encs, gs), {}, "condition no longer holds")
	gs.flags.erase("home_visited")
	gs.set_flag("enc_runner")
	eq(WorldData.forced_encounter(encs, gs), {}, "already happened")


func test_forced_encounters_never_come_at_random() -> void:
	var w := WorldData.from_def({"rows": ["."], "legend": {".": "grass"},
		"encounters": [{"id": "runner", "forced": true, "actors": ["test_villager"]}]})
	var dice := Dice.new()
	dice.reseed(1)
	eq(w.pick_encounter(Vector2i(0, 0), 160, dice), {})


# --- Content ---------------------------------------------------------------------

func test_companion_blocks_are_complete() -> void:
	for t in DB.load_json("npcs.json")["npcs"]:
		var c: Dictionary = t.get("companion", {})
		if c.is_empty():
			continue
		if c.has("part_dialogue"):
			check(FileAccess.file_exists("res://data/dialogue/%s.dlg" % c["part_dialogue"]), "%s: part dialogue missing" % t["id"])
		check(c.has("leave_at") or c.get("pet", false), "%s: a companion who never leaves" % t["id"])


func test_price_and_calendar_conditions_are_real() -> void:
	var prices := Prices.data()
	var conds: Array = []
	for id in prices.get("named", {}):
		for s in prices["named"][id].get("steps", []):
			conds.append_array(s.get("if", []))
	for m in prices.get("markets", []):
		conds.append_array(m.get("if", []))
		for id in m.get("items", []):
			check(not DB.item(id).is_empty(), "market item %s" % id)
	for e in DB.calendar():
		conds.append_array(e.get("if", []))
	for c in conds:
		var head: String = Dialogue._split_op(String(c).trim_prefix("!").strip_edges().split(" ")[0])[0]
		check(head in Dialogue.COND_HEADS or head in Dialogue.SKILL_IDS or head in Dialogue.ATTR_IDS, "unknown condition %s" % c)


func test_act2_clock_is_in_order() -> void:
	var days := {}
	for e in DB.calendar():
		days[e["id"]] = int(e["day"])
	for id in ["caesar_gergovia", "litaviccus", "cabillonum_riot", "gergovia_victory", "gergovia_lifted", "noviodunum", "volcae_raid", "council", "alesia"]:
		check(days.has(id), "calendar has %s" % id)
	check(days["caesar_gergovia"] < days["litaviccus"] and days["litaviccus"] < days["cabillonum_riot"]
		and days["cabillonum_riot"] < days["gergovia_victory"] and days["gergovia_victory"] < days["noviodunum"]
		and days["noviodunum"] < days["council"] and days["council"] < days["alesia"], "Act II events in historical order")


# --- Theron's parting, through the real dialogue ------------------------------------

func _parting(gs: GameState) -> Dictionary:
	_with_theron(gs)
	Companions.change(gs, "theron", -45)
	var d := Dialogue.load_dialogue("com_theron_part")
	return {"dlg": d, "page": Dialogue.enter(gs, d, d["entry"])}


func _choose(gs: GameState, st: Dictionary, sub: String) -> Dictionary:
	for ch in st["page"]["choices"]:
		if str(ch["text"]).find(sub) >= 0:
			return Dialogue.choose(gs, st["dlg"], st["page"]["node"], ch["index"])
	fail("no choice '%s'" % sub)
	return {}


func test_theron_talked_round_stays() -> void:
	var gs := _gs()
	var low := _parting(gs)
	var labels: Array = low["page"]["choices"].map(func(c): return str(c["text"]))
	if gs.player.skill("speech") < 55:
		check(not str(labels).contains("same sums"), "Speech route hidden without the skill")
	gs = _gs()
	gs.player.skill_bonus["speech"] = 80
	var st := _parting(gs)
	var page := _choose(gs, st, "same sums")
	eq(Companions.opinion(gs, "theron"), -15)
	check(not page["actions"].has("part"), "he stays")
	eq(Companions.next_to_part(gs), "", "and doesn't ask again at once")


func test_theron_let_go_or_robbed() -> void:
	var gs := _gs()
	var st := _parting(gs)
	var page := _choose(gs, st, "Then go")
	check(page["actions"].has("part") or Dialogue.choose(gs, st["dlg"], page["node"], 0).get("actions", []).has("part"), "he goes")
	var gs2 := _gs()
	var st2 := _parting(gs2)
	var p2 := _choose(gs2, st2, "Leave the purse")
	eq(gs2.player.silver, 40, "his purse")
	eq(gs2.honor, -10)
	check(p2["actions"].has("part"), "and he goes")


func test_theron_wont_share_a_roof_with_a_guest_murderer() -> void:
	var gs := _gs()
	gs.set_flag("guest_murder")
	var st := _parting(gs)
	check(str(st["page"]["text"]).contains("spear's length"), "the guest-murder opening, not the usual one")
