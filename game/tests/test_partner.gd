extends TestCase
## A2.3, "The partner": Bibracte's upper-town gate, Dannotalos and the routes
## of The Partner, played through the real dialogue files.


func _gs(attrs: Dictionary = {}) -> GameState:
	var gs := GameState.new()
	gs.player = CharacterSheet.create("Tester", attrs, ["speech", "blades", "sneak"])
	gs.dice.reseed(5)
	gs.advance(121 * 1440 + 10 * 60)
	return gs


func _open(gs: GameState, id: String) -> Dictionary:
	var d := Dialogue.load_dialogue(id)
	return {"dlg": d, "page": Dialogue.enter(gs, d, d["entry"])}


func _labels(st: Dictionary) -> String:
	return str(st["page"]["choices"].map(func(c): return str(c["text"])))


func _pick(gs: GameState, st: Dictionary, sub: String) -> Dictionary:
	for ch in st["page"]["choices"]:
		if str(ch["text"]).find(sub) >= 0:
			st["page"] = Dialogue.choose(gs, st["dlg"], st["page"]["node"], ch["index"])
			return st["page"]
	fail("no choice '%s' in %s" % [sub, _labels(st)])
	return {}


func _q(gs: GameState, cond: String) -> bool:
	return Dialogue.check(gs, cond)


## Meets Dannotalos and sits down to eat.
## Moves the clock on to the dead of night.
func _to_night(gs: GameState) -> void:
	gs.advance(60)
	while not _q(gs, "night"):
		gs.advance(60)
	gs.advance(180)


func _guest(gs: GameState) -> Dictionary:
	var st := _open(gs, "bib_dannotalos")
	_pick(gs, st, "Sit down and eat")
	return st


# --- Map and gate ---------------------------------------------------------------

func test_bibracte_has_a_map() -> void:
	var w := WorldData.load_world()
	check(w.cell_for_map("bibracte_lower") != Vector2i(-1, -1), "bibracte opens on its lower town")


func test_gate_steward_escorts() -> void:
	var gs := _gs()
	var st := _open(gs, "bib_upper_gate")
	_pick(gs, st, "come to see Dannotalos")
	check(_q(gs, "flag bib_upper") and _q(gs, "flag bib_escorted"), "steward walks you up")


func test_gate_bribe_and_talk() -> void:
	var gs := _gs()
	gs.player.silver = 20
	var st := _open(gs, "bib_upper_gate")
	_pick(gs, st, "fifteen in silver")
	eq(gs.player.silver, 5)
	check(_q(gs, "flag bib_upper"), "bribed")
	check(not _q(gs, "flag bib_escorted"), "nobody watching")


func test_gate_at_night_has_no_steward() -> void:
	var gs := _gs()
	_to_night(gs)
	var st := _open(gs, "bib_upper_gate")
	check(not _labels(st).contains("come to see Dannotalos"), "no steward at night")
	check(_labels(st).contains("over the bank"), "the bank in the dark")


# --- Dannotalos -------------------------------------------------------------------

func test_meeting_starts_the_quests() -> void:
	var gs := _gs()
	_guest(gs)
	check(_q(gs, "flag dan_met") and _q(gs, "flag dan_guest"), "met and fed")
	check(_q(gs, "quest partner active"), "partner")
	check(_q(gs, "quest brig_line active"), "brig_line")


func test_claim_needs_the_feast() -> void:
	var gs := _gs()
	var st := _open(gs, "bib_dannotalos")
	_pick(gs, st, "stand")
	check(not _labels(st).contains("I claim it"), "no claim standing up")
	_pick(gs, st, "eat with you after all")
	check(_labels(st).contains("I claim it"), "claim once a guest: %s" % _labels(st))


func test_forfeit_after_the_duel() -> void:
	var gs := _gs()
	_guest(gs)
	gs.set_flag("dan_duel")
	gs.set_flag("champion_beaten")
	_open(gs, "bib_dannotalos")
	check(_q(gs, "quest partner=done_shamed"), "shamed")
	check(_q(gs, "quest brig_line=done_released"), "Brigodunon released")
	check(_q(gs, "flag house_left"), "the house leaves")
	check(not _q(gs, "flag dan_forfeit_silver"), "no silver while the line was owed")


func test_lost_duel() -> void:
	var gs := _gs()
	_guest(gs)
	gs.set_flag("dan_duel")
	_open(gs, "bib_dannotalos")
	check(_q(gs, "flag dan_duel_done"), "lost")
	check(_q(gs, "quest partner active"), "still open")


func test_roll_sold() -> void:
	var gs := _gs()
	gs.player.inventory.add("hostage_roll", 1)
	gs.set_flag("roll_read")
	var st := _guest(gs)
	_pick(gs, st, "hostage roll")
	_pick(gs, st, "the roll is yours")
	eq(gs.player.inventory.count("hostage_roll"), 0)
	check(_q(gs, "quest brig_line=done_released"), "released")
	check(_q(gs, "quest partner=struck"), "struck")


func test_iron_stub() -> void:
	var gs := _gs()
	gs.set_flag("iron_tally")
	var st := _guest(gs)
	_pick(gs, st, "Bone Field")
	check(_q(gs, "flag dan_enemy"), "enemy")
	check(_q(gs, "quest brig_line=done_released"), "released")


func test_join_with_the_master_book() -> void:
	var gs := _gs()
	gs.player.inventory.add("master_book", 1)
	var st := _guest(gs)
	_pick(gs, st, "master book")
	_pick(gs, st, "Make me your partner")
	check(_q(gs, "quest partner=done_partner"), "partner")
	check(_q(gs, "quest brig_line=done_partner"), "line")
	eq(gs.player.inventory.count("master_book"), 0)


# --- Chamber, druid, Vettius ------------------------------------------------------

func test_chamber_murder() -> void:
	var gs := _gs()
	_guest(gs)
	_to_night(gs)
	var page: Dictionary = {}
	var st := _open(gs, "bib_chamber")
	# Seeded dice: retry the sneak roll on fresh games until it lands.
	for i in 40:
		gs.dice.reseed(i)
		st = _open(gs, "bib_chamber")
		page = _pick(gs, st, "Step over the sleepers")
		if str(page.get("node", "")) == "inside" or _labels(st).contains("in his sleep"):
			break
	if not _labels(st).contains("in his sleep"):
		fail("never got inside: %s" % _labels(st))
		return
	_pick(gs, st, "in his sleep")
	check(_q(gs, "flag dannotalos_dead"), "dead")
	check(_q(gs, "quest partner=done_dead"), "done_dead")


func test_druid_interdiction() -> void:
	var gs := _gs()
	_guest(gs)
	gs.set_flag("iron_tally")
	var st := _open(gs, "bib_druid")
	_pick(gs, st, "iron out of the Bone Field")
	check(_q(gs, "flag dannotalos_interdicted"), "barred")
	check(_q(gs, "quest partner=done_interdicted"), "partner")
	check(_q(gs, "quest brig_line=done_barred"), "line")


func test_vettius_cut_by_the_tally() -> void:
	var gs := _gs()
	_guest(gs)
	gs.player.inventory.add("dannotalos_tally", 1)
	var st := _open(gs, "cab_vettius")
	_pick(gs, st, "stand")
	_pick(gs, st, "About your partner")
	_pick(gs, st, "tally")
	check(_q(gs, "flag partners_split"), "split")
	check(_q(gs, "quest partner=done_split"), "partner")
	check(_q(gs, "quest brig_line=done_void"), "line void")
