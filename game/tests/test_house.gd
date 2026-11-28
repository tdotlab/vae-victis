extends TestCase
## A2.2, "The house arrives": the house's man at Brigodunon, the Line, and
## Cabillonum before the riot (Vettius, the Countinghouse, Theron's Debt),
## played through the real dialogue files.


func _gs(attrs: Dictionary = {}) -> GameState:
	var gs := GameState.new()
	gs.player = CharacterSheet.create("Tester", attrs, ["speech", "blades", "sneak"])
	gs.dice.reseed(5)
	gs.advance(121 * 1440)
	gs.set_flag("house_due")
	return gs


func _with_theron(gs: GameState, opinion: int = 0) -> void:
	gs.companions.append({"uid": "theron", "template": "theron", "sheet": {"name": "Theron"}})
	Companions.change(gs, "theron", opinion - Companions.opinion(gs, "theron"))


## Opens a dialogue: {"dlg", "page"}.
func _open(gs: GameState, id: String) -> Dictionary:
	var d := Dialogue.load_dialogue(id)
	return {"dlg": d, "page": Dialogue.enter(gs, d, d["entry"])}


func _labels(st: Dictionary) -> String:
	return str(st["page"]["choices"].map(func(c): return str(c["text"])))


## Picks the choice whose text contains sub, and moves st on to the next page.
func _pick(gs: GameState, st: Dictionary, sub: String) -> Dictionary:
	for ch in st["page"]["choices"]:
		if str(ch["text"]).find(sub) >= 0:
			st["page"] = Dialogue.choose(gs, st["dlg"], st["page"]["node"], ch["index"])
			return st["page"]
	fail("no choice '%s' in %s" % [sub, _labels(st)])
	return {}


func _q(gs: GameState, cond: String) -> bool:
	return Dialogue.check(gs, cond)


## The house's man in the hall, after Vellaunos's arrival scene.
func _hall(gs: GameState) -> Dictionary:
	var arrive := _open(gs, "brig_house_arrive")
	_pick(gs, arrive, "Go in")
	return _open(gs, "brig_house")


# --- Engine -------------------------------------------------------------------

func test_world_cell_for_a_map() -> void:
	var w := WorldData.load_world()
	eq(w.cell_for_map("cabillonum"), Vector2i(27, 15))
	eq(w.cell_for_map("brigodunon"), Vector2i(8, 34))
	eq(w.cell_for_map("no_such_map"), Vector2i(-1, -1))


func test_cabillonum_is_hidden_until_known() -> void:
	var w := WorldData.load_world()
	var found := false
	for l in w.def["locations"]:
		if l["id"] == "cabillonum":
			found = true
			check(l.get("hidden", false), "hidden")
			eq(String(l["map"]), "cabillonum")
	check(found, "Cabillonum is on the map")
	eq(w.terrain_id(Vector2i(28, 14)), "river", "the Arar runs past it")


func test_brigodunon_roof_covers_the_hall_once_the_guest_is_in() -> void:
	var gs := _gs()
	var m := MapData.load_map("brigodunon")
	var man: Vector2i = m.mark("house_man")
	eq(Hospitality.roof_at(gs, m, man), "", "no roof before he comes")
	gs.set_flag("house_met")
	eq(Hospitality.roof_at(gs, m, man), "brigodunon", "his place by the fire")
	eq(Hospitality.roof_at(gs, m, m.mark("hall")), "brigodunon", "the hall")
	eq(Hospitality.roof_at(gs, m, m.mark("vellaunos")), "brigodunon", "the host")
	eq(Hospitality.roof_at(gs, m, m.mark("start")), "", "your own house isn't the hall")


func test_strongroom_opens_only_through_its_door() -> void:
	var m := MapData.load_map("cabillonum")
	var inside := {}
	for mk in ["strongroom", "lectern"]:
		for c in m.mark_cells(mk):
			inside[c] = true
	check(inside.size() >= 5, "a strongroom")
	var door: Vector2i = m.mark("strong_door")
	for c in inside:
		for n in Hex.neighbors(c):
			if m.has_cell(n) and m.is_walkable(n) and not inside.has(n):
				eq(n, door, "only the door leads out of the strongroom")


# --- The House Collects -------------------------------------------------------

func test_arrival_settles_who_comes_and_what_he_claims() -> void:
	var gs := _gs()
	_open(gs, "brig_house_arrive")
	check(gs.flag("house_epo") and gs.flag("epo_at_brig"), "Epomeduos, alive and unexposed")
	check(gs.flag("house_claim_held") and not gs.flag("house_owed"), "the hostages are still held")

	gs = _gs()
	gs.set_flag("factor_gone")
	gs.set_flag("epo_out")
	_open(gs, "brig_house_arrive")
	check(gs.flag("house_dio") and not gs.flag("house_epo"), "Diodotos if Epomeduos is gone")
	check(gs.flag("house_owed"), "brought home by fraud or by night: the house wants its price")

	gs = _gs()
	gs.set_flag("factor_gone")
	gs.set_flag("epo_out")
	gs.set_flag("orbius_mercy")
	_open(gs, "brig_house_arrive")
	check(gs.flag("house_claim_none") and not gs.flag("house_owed"), "written off: no claim")


func test_arrival_walks_you_into_the_hall() -> void:
	var gs := _gs()
	var st := _open(gs, "brig_house_arrive")
	check(_q(gs, "quest house_collects active"))
	var page := _pick(gs, st, "Go in")
	check(page["actions"].has("travel brigodunon hall"), str(page["actions"]))


func test_runner_changes_the_greeting() -> void:
	var gs := _gs()
	gs.advance(30 * 1440)
	var r := _open(gs, "enc_runner")
	check(_q(gs, "quest house_collects=runner"))
	_pick(gs, r, "Go home")
	var st := _open(gs, "brig_house_arrive")
	check(str(st["page"]["text"]).contains("boy found you"), st["page"]["text"])


func test_pay_the_house() -> void:
	var gs := _gs()
	gs.set_flag("factor_gone")
	gs.set_flag("epo_out")
	var st := _hall(gs)
	check(_q(gs, "quest brig_line active"), "the Line starts with his claim")
	var price := Prices.named(gs, "brig_line")
	eq(price, int(round(80 * 1.5 * Prices.barter_discount(gs.player.skill("barter")))), "owed: half again")
	check(not _labels(st).contains("Strike it"), "can't pay with nothing")
	gs.player.silver = price + 7
	st = _open(gs, "brig_house")
	_pick(gs, st, "Strike it")
	eq(gs.player.silver, 7)
	check(_q(gs, "quest brig_line=done_bought"), "line bought")
	check(_q(gs, "quest house_collects=done_paid"))
	check(gs.flag("house_left") and gs.flag("house_funded"))


func test_show_him_the_door() -> void:
	var gs := _gs()
	gs.set_flag("factor_gone")
	gs.set_flag("epo_out")
	var st := _hall(gs)
	var before := Prices.named(gs, "brig_line")
	_pick(gs, st, "Get out of this hall")
	check(gs.flag("house_refused") and gs.flag("house_left"))
	near(Prices.named(gs, "brig_line"), before * 2.0, 1.0, "the price doubles")
	gs.advance(40 * 1440)
	check(Dialogue.all_true(gs, ["flag house_refused", "day >= 150"]), "the reminder is due")


func test_guest_murder_at_vellaunos_fire() -> void:
	var gs := _gs()
	var st := _hall(gs)
	_pick(gs, st, "Draw your knife")
	var page := _pick(gs, st, "Do it")
	check(page["actions"].has("fight"))
	check(gs.flag("guest_murder_brigodunon"), "the guest-bond is broken")
	check(gs.honor <= -60)
	check(_q(gs, "quest house_collects=done_guest"))
	gs.set_flag("act1_done")
	var v := _open(gs, "brig_vellaunos")
	check(str(v["page"]["text"]).contains("Cintugnatos"), "the vates curses the hall")
	check(gs.flag("hall_cursed"))
	v = _open(gs, "brig_vellaunos")
	check(not _labels(v).contains("our guest"), "and nobody talks about him again")


func test_put_the_knife_away() -> void:
	var gs := _gs()
	var st := _hall(gs)
	_pick(gs, st, "Draw your knife")
	_pick(gs, st, "Put the knife away")
	check(not gs.flag("guest_murder"), "nothing happened")
	check(not _labels(st).contains("Draw your knife"), "you don't get to draw twice")


func test_follow_him_to_cabillonum() -> void:
	var gs := _gs()
	gs.player.skill_bonus["sneak"] = 80
	var st := _hall(gs)
	var day := gs.day()
	_pick(gs, st, "Follow him")
	eq(gs.day() - day, 12, "twelve days on the road")
	check(gs.known_locations.has("cabillonum"))
	check(gs.flag("pens_heard"), "he stopped at the pens on the way")
	check(not gs.flag("house_warned"))
	var page := _pick(gs, st, "Go into the town")
	check(page["actions"].has("travel cabillonum start"), str(page["actions"]))

	var gs2 := _gs()
	gs2.player.skill_bonus["sneak"] = -100
	var st2 := _hall(gs2)
	check(not _labels(st2).contains("Follow him when"), "Sneak hides the quiet follow")
	_pick(gs2, st2, "Watch him leave")
	check(gs2.flag("house_warned"), "followed clumsily: they know your face")


func test_wait_on_the_road() -> void:
	var gs := _gs()
	gs.set_flag("factor_gone")
	var st := _hall(gs)
	_pick(gs, st, "Go back to your master")
	check(gs.flag("house_waylay"))
	var due := WorldData.forced_encounter(WorldData.load_world().def["encounters"], gs)
	eq(String(due.get("id", "")), "house_road_dio", "the freedman's party on the road")
	var road := _open(gs, "enc_house_road")
	var page := _pick(gs, road, "Kill him")
	check(page["actions"].has("fight"))
	check(not gs.flag("guest_murder"), "on the road it's only murder")
	check(gs.flag("house_grudge") and _q(gs, "quest house_collects=done_road"))
	var again := _open(gs, "enc_house_road")
	eq(again["page"]["choices"].size(), 0, "nothing more to say")
	check(WorldData.forced_encounter(WorldData.load_world().def["encounters"], gs).is_empty(), "and the road is quiet")


func test_read_his_paper() -> void:
	var gs := _gs()
	gs.player.skill_bonus["latin"] = 50
	var st := _hall(gs)
	_pick(gs, st, "Let me see your paper")
	check(gs.known_locations.has("cabillonum"), "the seal points to Cabillonum")
	check(_q(gs, "quest brig_line=seat"))
	check(not _labels(st).contains("Let me see your paper"), "once")


# --- Cabillonum: the Countinghouse ---------------------------------------------

func test_strike_the_line_in_the_book() -> void:
	var gs := _gs()
	gs.player.skill_bonus["latin"] = 80
	gs.player.inventory.add("vettius_seal", 1)
	var st := _open(gs, "cab_book")
	check(_q(gs, "quest countinghouse=found"), "seen")
	check(gs.flag("pens_known"))
	_pick(gs, st, "Strike Brigodunon's line")
	check(_q(gs, "quest brig_line=done_forged"))
	check(not _labels(st).contains("Strike"), "it's struck")
	_pick(gs, st, "Take the book")
	eq(gs.player.inventory.count("master_book"), 1)
	check(_q(gs, "quest brig_line=done_forged"), "taking it afterward doesn't rewrite the Line")
	check(_q(gs, "quest countinghouse=done_taken"))
	check(gs.flag("book_gone"))


func test_burn_the_book() -> void:
	var gs := _gs()
	var st := _open(gs, "cab_book")
	_pick(gs, st, "Burn it")
	check(gs.flag("book_burned") and gs.flag("book_gone"))
	check(_q(gs, "quest brig_line=done_burned"))
	check(_q(gs, "quest house_vettius=paper_burned"))


func test_copy_it_in_place() -> void:
	var gs := _gs({"WIT": 8})
	gs.player.skill_bonus["latin"] = 60
	var st := _open(gs, "cab_book")
	var t := gs.minutes
	_pick(gs, st, "Copy the pages")
	eq(gs.minutes - t, 180)
	eq(gs.player.inventory.count("book_pages"), 1)
	check(_q(gs, "quest countinghouse=done_copied"))
	check(not gs.flag("book_gone"), "the house never knows")
	check(not _q(gs, "quest brig_line done"), "copying doesn't strike the line")


func test_book_needs_latin_or_theron() -> void:
	var gs := _gs({"WIT": 3})
	gs.player.skill_bonus["latin"] = -100
	var st := _open(gs, "cab_book")
	check(not _labels(st).contains("Read it"), "can't read")
	check(not _labels(st).contains("Copy"), "can't copy")
	var gs2 := _gs({"WIT": 3})
	gs2.player.skill_bonus["latin"] = -100
	_with_theron(gs2, 10)
	var st2 := _open(gs2, "cab_book")
	check(_labels(st2).contains("Theron. Read it"))
	check(_labels(st2).contains("Theron, copy"))


func test_strongroom_by_night_is_harder_once_warned() -> void:
	var gs := _gs()
	Dialogue.apply(gs, ["wait_until 23"])
	gs.player.skill_bonus["sneak"] = 60 - gs.player.skill("sneak")
	gs.player.silver = 100
	var st := _open(gs, "cab_strongroom")
	check(_labels(st).contains("piss"), "Sneak 60 is enough unwarned")
	check(_labels(st).contains("silver"), "bribe")
	gs.set_flag("house_warned")
	st = _open(gs, "cab_strongroom")
	check(not _labels(st).contains("piss"), "not with the dog")
	check(not _labels(st).contains("silver"), "and he won't take it")
	var page := _pick(gs, st, "Step back")
	check(page["actions"].has("travel cabillonum vhall"), "put back in the hall")


func test_strongroom_by_day() -> void:
	var gs := _gs()
	Dialogue.apply(gs, ["wait_until 10"])
	var st := _open(gs, "cab_strongroom")
	check(not _labels(st).contains("ring"), "no ring, no way in")
	gs.set_flag("house_factor")
	_open(gs, "cab_strongroom")
	check(gs.flag("strongroom_open"), "the house's factor goes in")


func test_felix_opens_it_for_his_freedom() -> void:
	var gs := _gs()
	gs.player.skill_bonus["speech"] = 80
	var st := _open(gs, "cab_felix")
	_pick(gs, st, "buy yourself")
	check(gs.flag("felix_turned"))
	Dialogue.apply(gs, ["wait_until 23"])
	var door := _open(gs, "cab_strongroom")
	_pick(gs, door, "Felix said")
	check(gs.flag("strongroom_open"))
	gs.set_flag("book_gone")
	var after := _open(gs, "cab_felix")
	var page := _pick(gs, after, "Come with me")
	check(page["actions"].has("leave") and gs.flag("felix_freed"))


func test_paconius_walks_you_in_and_pays_for_it() -> void:
	var gs := _gs()
	gs.set_flag("clerk_saved")
	var st := _open(gs, "cab_paconius")
	_pick(gs, st, "master book")
	_pick(gs, st, "Just a look")
	check(gs.flag("paconius_inside") and gs.flag("strongroom_open"))
	var book := _open(gs, "cab_book")
	_pick(gs, book, "Paconius. Strike")
	check(_q(gs, "quest brig_line=done_forged"))
	_pick(gs, book, "Take the book")
	check(gs.flag("paconius_blamed"), "he let you in; he takes the blame")


# --- Cabillonum: Vettius -------------------------------------------------------

func test_vettius_buys_and_sells() -> void:
	var gs := _gs()
	var st := _open(gs, "cab_vettius")
	_pick(gs, st, "Take the cup")
	check(gs.flag("vettius_guest"), "his guest now")
	gs.player.silver = 500
	st = _open(gs, "cab_vettius")
	_pick(gs, st, "Strike Brigodunon off")
	check(_q(gs, "quest brig_line=done_bought"))
	check(not _labels(st).contains("Strike Brigodunon off"))


func test_vettius_makes_you_a_factor() -> void:
	var gs := _gs()
	_with_theron(gs, 10)
	var st := _open(gs, "cab_vettius")
	_pick(gs, st, "stand")
	_pick(gs, st, "another way")
	_pick(gs, st, "Show me where to sign")
	check(gs.flag("house_factor"))
	check(_q(gs, "quest brig_line=done_factor"), "Brigodunon struck as the wage")
	check(_q(gs, "quest house_vettius=factor"))
	eq(gs.honor, -10)
	check(Companions.opinion(gs, "theron") < 0, "Theron thinks less of you")


func test_killing_vettius_under_his_roof() -> void:
	var gs := _gs()
	var st := _open(gs, "cab_vettius")
	_pick(gs, st, "Take the cup")
	_pick(gs, st, "Draw your knife")
	var page := _pick(gs, st, "Do it anyway")
	check(page["actions"].has("fight"))
	check(gs.flag("guest_murder_vettius"))
	check(not _q(gs, "quest house_vettius=vettius_dead"), "not dead until the fight kills him")
	Dialogue.apply(gs, DB.npc_template("vettius")["kill_fx"])
	check(_q(gs, "quest house_vettius=vettius_dead"))
	check(not _q(gs, "quest brig_line done"), "killing him doesn't strike the line")


# --- Theron's Debt -------------------------------------------------------------

func test_demarchos_calls_the_loan_before_the_aedui_go_over() -> void:
	var gs := _gs()
	_with_theron(gs, 10)
	_open(gs, "cab_theron_arrive")
	check(_q(gs, "quest theron_debt active"))
	var st := _open(gs, "cab_demarchos")
	check(_q(gs, "quest theron_debt=met"))
	check(not _labels(st).contains("Call in"), "no warning to give yet")
	gs.set_flag("aedui_wavering")
	st = _open(gs, "cab_demarchos")
	_pick(gs, st, "going over")
	check(gs.flag("credit_called") and gs.flag("forward_sale_stopped"))
	check(_q(gs, "quest brig_line=done_never"), "the line is never written")
	check(_q(gs, "quest theron_debt=done_called"))
	eq(Companions.opinion(gs, "theron"), 20)


func test_called_too_late() -> void:
	var gs := _gs()
	gs.set_flag("cabillonum_riot")
	gs.set_flag("aedui_defected")
	var st := _open(gs, "cab_demarchos")
	_pick(gs, st, "what the Aedui did")
	check(gs.flag("credit_called"))
	check(not gs.flag("forward_sale_stopped"), "after day 196 it only squeezes the house")
	check(not _q(gs, "quest brig_line done"))


func test_settle_theron_and_buy_the_debt() -> void:
	var gs := _gs()
	_with_theron(gs, 25)
	_open(gs, "cab_theron_arrive")
	gs.player.silver = 2000
	var st := _open(gs, "cab_demarchos")
	var debt := Prices.named(gs, "house_debt")
	check(debt < 800, "Theron puts his purse in")
	_pick(gs, st, "What does Theron owe")
	_pick(gs, st, "It's paid")
	check(_q(gs, "quest theron_debt=done_settled"))
	eq(Companions.opinion(gs, "theron"), 45)
	var st2 := _open(gs, "cab_demarchos")
	var before := gs.player.silver
	_pick(gs, st2, "buy Vettius's debt")
	_pick(gs, st2, "Pay him")
	eq(before - gs.player.silver, debt)
	check(gs.flag("house_creditor") and _q(gs, "quest house_vettius=credit_bought"))


func test_theron_sells_you_out() -> void:
	var gs := _gs()
	_with_theron(gs, -5)
	var st := _open(gs, "cab_theron_arrive")
	check(gs.flag("theron_sold") and gs.flag("house_warned"))
	check(_q(gs, "quest theron_debt failed"))
	var page := _pick(gs, st, "Let him go")
	check(page["actions"].has("part") and page["actions"].has("leave"))
	var d := _open(gs, "cab_demarchos")
	eq(d["page"]["choices"].size(), 1, "his brother has nothing for you")

	var gs2 := _gs()
	_with_theron(gs2, 30)
	gs2.set_flag("house_factor")
	_open(gs2, "cab_theron_arrive")
	check(gs2.flag("theron_sold"), "nor if you've joined the house")


func test_vettius_knows_who_warned_him() -> void:
	var gs := _gs()
	gs.set_flag("house_warned")
	gs.set_flag("theron_sold")
	var t := str(_open(gs, "cab_vettius")["page"]["text"])
	check(t.contains("Demarchos") and not t.contains("Diodotos"), t)
	gs = _gs()
	gs.set_flag("house_epo")
	gs.set_flag("house_followed")
	gs.set_flag("house_warned")
	t = str(_open(gs, "cab_vettius")["page"]["text"])
	check(t.contains("Epomeduos said") and not t.contains("Demarchos"), t)
