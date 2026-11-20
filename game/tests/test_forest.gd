extends TestCase
## The Carnute forest and the Judgment, walked through the real dialogue
## files: every way to a verdict, the vigil and the gift, the Dubnacos
## callback, and what each verdict does at the assembly at home.

class FixedDice extends Dice:
	var result := true
	func chance(_percent: float) -> bool:
		return result


var gs: GameState
var dlg: Dictionary
var page: Dictionary
var actions: Array = []


func _new_game() -> void:
	gs = GameState.new()
	gs.player = CharacterSheet.create("Ambiorix", {}, ["speech", "blades", "sneak"])
	gs.dice = FixedDice.new()
	gs.minutes = 85 * 1440 + 10 * 60
	gs.set_quest("judgment", "start")
	actions = []


func _night() -> void:
	gs.minutes = gs.minutes - gs.minutes % 1440 + 22 * 60


func _talk(id: String) -> void:
	dlg = Dialogue.load_dialogue(id)
	check(not dlg.is_empty(), "dialogue %s loads" % id)
	page = Dialogue.enter(gs, dlg, dlg["entry"])
	actions += page["actions"]


func _has(sub: String) -> bool:
	for ch in page["choices"]:
		if str(ch["text"]).find(sub) >= 0:
			return true
	return false


func _pick(sub: String, win := true) -> void:
	(gs.dice as FixedDice).result = win
	for ch in page["choices"]:
		if str(ch["text"]).find(sub) >= 0:
			page = Dialogue.choose(gs, dlg, page["node"], ch["index"])
			actions += page["actions"]
			return
	var texts: Array = page["choices"].map(func(c): return c["text"])
	fail("no choice containing '%s' at %s; have %s" % [sub, page["node"], texts])
	page = {"node": "END", "choices": [], "end": true, "actions": [], "text": ""}


func _ending_text() -> String:
	var out := ""
	for p in Endings.pages(gs, "endings/act1.json"):
		out += p["title"] + ": " + p["text"] + "\n"
	return out


func _hearing() -> void:
	_talk("for_senouindos")
	_pick("About Brigodunon's oath")


func _void() -> void:
	eq(gs.quest_stage("judgment"), "done_void")
	eq(gs.flag("pledge_void"), 1)
	eq(gs.player.inventory.count("druid_token"), 1, "the bronze wheel")


func test_the_druid_can_start_the_judgment_himself() -> void:
	_new_game()
	gs.quests.erase("judgment")
	_talk("for_senouindos")
	_pick("You keep our oath to Rome")
	eq(gs.quest_stage("judgment"), "start")
	_pick("Rome broke faith first")
	eq(page["node"], "case")


func test_the_day_book_is_evidence() -> void:
	_new_game()
	gs.player.inventory.add("vettius_tablets")
	_hearing()
	_pick("Roman merchant's day book")
	_void()
	eq(gs.player.inventory.count("vettius_tablets"), 1, "you keep the tablets")
	check(_ending_text().find("declared Brigodunon's oath to Rome void") >= 0, "void slide")


func test_the_roll_and_the_letter_are_evidence() -> void:
	_new_game()
	gs.player.inventory.add("hostage_roll")
	_hearing()
	_pick("Ateula's roll")
	_void()
	_new_game()
	gs.player.inventory.add("aeduan_letter")
	_hearing()
	_pick("Dannotalos's letter")
	_void()


func test_the_law_with_and_without_the_bard() -> void:
	_new_game()
	gs.player.skill_bonus["lore"] = 40 - gs.player.skill("lore")
	_hearing()
	check(not _has("A pledge is held, not owned"), "lore 50 hidden at 40")
	check(not _has("Bitugenos sang it"), "no song yet")
	_talk("for_bitugenos")
	_pick("Do you know the law on pledges?")
	eq(gs.flag("judg_law_hint"), 1)
	_hearing()
	_pick("Bitugenos sang it")
	_void()


func test_the_case_by_speech_or_presence() -> void:
	_new_game()
	gs.player.skill_bonus["speech"] = 100
	_hearing()
	_pick("Ask the children")
	_void()
	_new_game()
	gs.player.attrs["PRE"] = 7
	_hearing()
	_pick("Say nothing; stand there")
	_void()


func test_the_vigil_then_the_answer() -> void:
	_new_game()
	_talk("for_vigil")
	eq(page["node"], "day", "not by day")
	_night()
	_talk("for_vigil")
	_pick("plain stubbornness", false)
	eq(gs.flag("judg_vigil"), 0)
	check(gs.hour() == 6, "the night is gone either way")
	_night()
	_talk("for_vigil")
	_pick("wait for whatever comes")
	eq(gs.flag("judg_vigil"), 1)
	_hearing()
	_pick("I sat the night in the grove")
	_void()


func test_a_gift_buys_one_plea() -> void:
	_new_game()
	gs.player.silver = 50
	_hearing()
	check(not _has("I gave to the gods first"), "no plea before the gift")
	_talk("for_pit")
	_pick("fifty silver")
	eq(gs.flag("judg_gift"), 1)
	eq(gs.player.silver, 0)
	_hearing()
	_pick("I gave to the gods first", false)
	eq(gs.quest_stage("judgment"), "start", "a failed plea decides nothing")
	eq(page["node"], "hub", "back to him")
	_pick("About Brigodunon's oath")
	check(not _has("I gave to the gods first"), "only one plea")


func test_a_straight_answer_binds_and_the_assembly_keeps_faith() -> void:
	_new_game()
	_hearing()
	_pick("Judge it straight")
	eq(gs.quest_stage("judgment"), "done_bound")
	eq(gs.flag("pledge_bound"), 1)
	eq(gs.player.inventory.count("druid_token"), 1)
	_talk("for_senouindos")
	eq(page["node"], "after")
	# Home, with the hostages left behind, and the verdict in hand.
	gs.set_quest("hostages", "left")
	gs.set_flag("hostages_left")
	_talk("brig_vellaunos")
	_pick("Call the assembly")
	_pick("We're bound.")
	eq(gs.flag("brig_faith"), 1)
	eq(gs.flag("act1_done"), 1)
	var t := _ending_text()
	check(t.find("Brigodunon kept faith.") >= 0, "faith slide")
	check(t.find("still bound it") >= 0, "bound slide")


func test_the_void_verdict_carries_the_assembly() -> void:
	_new_game()
	gs.set_flag("pledge_void")
	gs.set_quest("hostages", "left")
	gs.set_flag("hostages_left")
	_talk("brig_vellaunos")
	_pick("Call the assembly")
	_pick("Our oath is void")
	eq(gs.flag("brig_rising"), 1)


func test_dubnacos_and_the_idol() -> void:
	_new_game()
	gs.set_flag("dubnacos_pardoned")
	gs.set_flag("idol_returned")
	_talk("for_senouindos")
	eq(page["node"], "dub", "he raises it first")
	_pick("The idol went back to the gods")
	eq(gs.flag("sen_d_dub"), 1)
	check(_has("About Brigodunon's oath"), "then the hearing")
	_new_game()
	gs.player.inventory.add("grotto_idol")
	_talk("for_senouindos")
	_pick("Show him the idol")
	eq(gs.player.inventory.count("grotto_idol"), 0)
	eq(gs.flag("idol_returned"), 1)


func test_the_vates_marks_the_idol_returned() -> void:
	_new_game()
	gs.player.inventory.add("grotto_idol")
	dlg = Dialogue.load_dialogue("brig_vates")
	page = Dialogue.enter(gs, dlg, "idol2")
	_pick("Give him the idol")
	eq(gs.flag("idol_returned"), 1)


func test_the_novice_heals() -> void:
	_new_game()
	gs.player.hp = 1
	_talk("for_toutillos")
	_pick("see to my wounds")
	eq(gs.player.hp, gs.player.max_hp())
